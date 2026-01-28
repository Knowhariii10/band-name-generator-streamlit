#!/bin/bash
# GCP Load Balancer Lab - Fixed Version
# IMPORTANT: Update REGION_1, ZONE_1, REGION_2, ZONE_2 before running!

# Configuration - UPDATE THESE VALUES
REGION_1="us-east1"
ZONE_1="us-east1-b"
REGION_2="europe-west1"
ZONE_2="europe-west1-b"

echo "Starting GCP Load Balancer Setup..."
echo "Region 1: $REGION_1 (Zone: $ZONE_1)"
echo "Region 2: $REGION_2 (Zone: $ZONE_2)"
echo ""

# Task 1: Create health check firewall rule
echo "Task 1: Creating health check firewall rule..."
gcloud compute firewall-rules create fw-allow-health-checks \
    --network=default \
    --action=allow \
    --direction=ingress \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=allow-health-checks \
    --rules=tcp:80

# Task 2: Create Cloud Router and NAT
echo "Task 2: Creating Cloud Router and NAT..."
gcloud compute routers create nat-router-us1 \
    --network=default \
    --region=$REGION_1

gcloud compute routers nats create nat-config \
    --router=nat-router-us1 \
    --region=$REGION_1 \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges

# Task 3: Create custom web server image
echo "Task 3: Creating custom web server image..."
gcloud compute instances create webserver \
    --zone=$ZONE_1 \
    --machine-type=e2-micro \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default,no-address \
    --tags=allow-health-checks \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-standard \
    --boot-disk-device-name=webserver

echo "Waiting 30 seconds for VM to boot..."
sleep 30

echo "Installing Apache on webserver..."
gcloud compute ssh webserver --zone=$ZONE_1 --command="sudo apt-get update && sudo apt-get install -y apache2 && sudo service apache2 start && sudo update-rc.d apache2 enable" --tunnel-through-iap

echo "Stopping webserver..."
gcloud compute instances stop webserver --zone=$ZONE_1

echo "Creating custom image..."
gcloud compute images create mywebserver \
    --source-disk=webserver \
    --source-disk-zone=$ZONE_1 \
    --family=mywebserver-family

echo "Deleting webserver instance..."
gcloud compute instances delete webserver --zone=$ZONE_1 --quiet

# Task 4: Create instance template and managed instance groups
echo "Task 4: Creating instance template and managed instance groups..."
gcloud compute instance-templates create mywebserver-template \
    --machine-type=e2-micro \
    --network-interface=network-tier=PREMIUM,subnet=default,no-address \
    --tags=allow-health-checks \
    --image=mywebserver \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-standard

echo "Creating health check..."
gcloud compute health-checks create tcp http-health-check \
    --port=80 \
    --check-interval=5s \
    --timeout=5s \
    --unhealthy-threshold=2 \
    --healthy-threshold=2

echo "Creating managed instance group in $REGION_1..."
gcloud compute instance-groups managed create us-1-mig \
    --base-instance-name=us-1-mig \
    --template=mywebserver-template \
    --size=1 \
    --zones=$ZONE_1 \
    --health-check=http-health-check \
    --initial-delay=60

echo "Configuring autoscaling for us-1-mig..."
gcloud compute instance-groups managed set-autoscaling us-1-mig \
    --region=$REGION_1 \
    --min-num-replicas=1 \
    --max-num-replicas=2 \
    --target-load-balancing-utilization=0.8 \
    --cool-down-period=60

echo "Setting named ports for us-1-mig..."
gcloud compute instance-groups managed set-named-ports us-1-mig \
    --region=$REGION_1 \
    --named-ports=http:80

echo "Creating managed instance group in $REGION_2..."
gcloud compute instance-groups managed create notus-1-mig \
    --base-instance-name=notus-1-mig \
    --template=mywebserver-template \
    --size=1 \
    --zones=$ZONE_2 \
    --health-check=http-health-check \
    --initial-delay=60

echo "Configuring autoscaling for notus-1-mig..."
gcloud compute instance-groups managed set-autoscaling notus-1-mig \
    --region=$REGION_2 \
    --min-num-replicas=1 \
    --max-num-replicas=2 \
    --target-load-balancing-utilization=0.8 \
    --cool-down-period=60

echo "Setting named ports for notus-1-mig..."
gcloud compute instance-groups managed set-named-ports notus-1-mig \
    --region=$REGION_2 \
    --named-ports=http:80

echo "Waiting for instance groups to stabilize..."
sleep 30

# Task 5: Configure Application Load Balancer (FIXED)
echo "Task 5: Configuring Application Load Balancer..."

echo "Creating backend service..."
gcloud compute backend-services create http-backend \
    --protocol=HTTP \
    --port-name=http \
    --health-checks=http-health-check \
    --global \
    --enable-logging \
    --logging-sample-rate=1.0 \
    --load-balancing-scheme=EXTERNAL_MANAGED

echo "Adding us-1-mig as backend..."
gcloud compute backend-services add-backend http-backend \
    --instance-group=us-1-mig \
    --instance-group-region=$REGION_1 \
    --balancing-mode=RATE \
    --max-rate-per-instance=50 \
    --capacity-scaler=1.0 \
    --global

echo "Adding notus-1-mig as backend..."
gcloud compute backend-services add-backend http-backend \
    --instance-group=notus-1-mig \
    --instance-group-region=$REGION_2 \
    --balancing-mode=UTILIZATION \
    --max-utilization=0.8 \
    --capacity-scaler=1.0 \
    --global

echo "Creating URL map..."
gcloud compute url-maps create http-lb \
    --default-service=http-backend

echo "Creating target HTTP proxy..."
gcloud compute target-http-proxies create http-lb-proxy \
    --url-map=http-lb

echo "Creating IPv4 forwarding rule..."
gcloud compute forwarding-rules create http-lb-forwarding-rule-ipv4 \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --network-tier=PREMIUM \
    --global \
    --target-http-proxy=http-lb-proxy \
    --ports=80

echo "Creating IPv6 forwarding rule..."
gcloud compute forwarding-rules create http-lb-forwarding-rule-ipv6 \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --network-tier=PREMIUM \
    --global \
    --target-http-proxy=http-lb-proxy \
    --ports=80 \
    --ip-version=IPV6

echo "Retrieving load balancer IP addresses..."
sleep 10

LB_IP_V4=$(gcloud compute forwarding-rules describe http-lb-forwarding-rule-ipv4 --global --format="get(IPAddress)")
LB_IP_V6=$(gcloud compute forwarding-rules describe http-lb-forwarding-rule-ipv6 --global --format="get(IPAddress)")

echo "Load Balancer IPv4: $LB_IP_V4"
echo "Load Balancer IPv6: $LB_IP_V6"

# Wait for load balancer to be ready
echo "Waiting for load balancer to be ready (this may take 3-5 minutes)..."
COUNTER=0
MAX_ATTEMPTS=60
while [ -z "$RESULT" ] && [ $COUNTER -lt $MAX_ATTEMPTS ]; do
    echo -n "."
    sleep 5
    RESULT=$(curl -m1 -s $LB_IP_V4 2>/dev/null | grep Apache || true)
    COUNTER=$((COUNTER+1))
done
echo ""

if [ -n "$RESULT" ]; then
    echo "Load balancer is ready!"
else
    echo "Load balancer is still initializing. You can test manually with: curl http://$LB_IP_V4"
fi

# Task 6: Stress test
echo "Task 6: Setting up stress test..."
gcloud compute instances create stress-test \
    --zone=us-central1-a \
    --machine-type=e2-micro \
    --image=mywebserver \
    --boot-disk-size=10GB

echo "Waiting for stress-test VM to be ready..."
sleep 30

echo "Running stress test (this will take a few minutes)..."
gcloud compute ssh stress-test --zone=us-central1-a --command="export LB_IP=$LB_IP_V4 && ab -n 500000 -c 1000 http://\$LB_IP/" || echo "Stress test completed or interrupted"

echo ""
echo "============================================"
echo "LAB COMPLETE!"
echo "============================================"
echo "Load Balancer IPv4: $LB_IP_V4"
echo "Load Balancer IPv6: $LB_IP_V6"
echo "Test URL: http://$LB_IP_V4"
echo ""
echo "Next Steps:"
echo "1. Visit: Navigation Menu > Network Services > Load Balancing > http-lb"
echo "2. Click 'Monitoring' to view traffic distribution"
echo "3. Check Instance Groups for autoscaling activity"
echo "============================================"
