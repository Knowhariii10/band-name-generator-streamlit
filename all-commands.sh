#!/bin/bash
# GCP Load Balancer Lab - All Commands in One Script
# IMPORTANT: Update REGION_1, ZONE_1, REGION_2, ZONE_2 before running!

# Configuration - UPDATE THESE VALUES
REGION_1="us-east1"
ZONE_1="us-east1-b"
REGION_2="europe-west1"
ZONE_2="europe-west1-b"

# Task 1: Create health check firewall rule
gcloud compute firewall-rules create fw-allow-health-checks \
    --network=default \
    --action=allow \
    --direction=ingress \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=allow-health-checks \
    --rules=tcp:80

# Task 2: Create Cloud Router and NAT
gcloud compute routers create nat-router-us1 \
    --network=default \
    --region=$REGION_1

gcloud compute routers nats create nat-config \
    --router=nat-router-us1 \
    --region=$REGION_1 \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges

# Task 3: Create custom web server image
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

sleep 30

gcloud compute ssh webserver --zone=$ZONE_1 --command="sudo apt-get update && sudo apt-get install -y apache2 && sudo service apache2 start && sudo update-rc.d apache2 enable" --tunnel-through-iap

gcloud compute instances stop webserver --zone=$ZONE_1

gcloud compute images create mywebserver \
    --source-disk=webserver \
    --source-disk-zone=$ZONE_1 \
    --family=mywebserver-family

gcloud compute instances delete webserver --zone=$ZONE_1 --quiet

# Task 4: Create instance template and managed instance groups
gcloud compute instance-templates create mywebserver-template \
    --machine-type=e2-micro \
    --network-interface=network-tier=PREMIUM,subnet=default,no-address \
    --tags=allow-health-checks \
    --image=mywebserver \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-standard

gcloud compute health-checks create tcp http-health-check \
    --port=80 \
    --check-interval=5s \
    --timeout=5s \
    --unhealthy-threshold=2 \
    --healthy-threshold=2

gcloud compute instance-groups managed create us-1-mig \
    --base-instance-name=us-1-mig \
    --template=mywebserver-template \
    --size=1 \
    --zones=$ZONE_1 \
    --health-check=http-health-check \
    --initial-delay=60

gcloud compute instance-groups managed set-autoscaling us-1-mig \
    --region=$REGION_1 \
    --min-num-replicas=1 \
    --max-num-replicas=2 \
    --target-load-balancing-utilization=0.8 \
    --cool-down-period=60

gcloud compute instance-groups managed set-named-ports us-1-mig \
    --region=$REGION_1 \
    --named-ports=http:80

gcloud compute instance-groups managed create notus-1-mig \
    --base-instance-name=notus-1-mig \
    --template=mywebserver-template \
    --size=1 \
    --zones=$ZONE_2 \
    --health-check=http-health-check \
    --initial-delay=60

gcloud compute instance-groups managed set-autoscaling notus-1-mig \
    --region=$REGION_2 \
    --min-num-replicas=1 \
    --max-num-replicas=2 \
    --target-load-balancing-utilization=0.8 \
    --cool-down-period=60

gcloud compute instance-groups managed set-named-ports notus-1-mig \
    --region=$REGION_2 \
    --named-ports=http:80

# Task 5: Configure Application Load Balancer
gcloud compute backend-services create http-backend \
    --protocol=HTTP \
    --port-name=http \
    --health-checks=http-health-check \
    --global \
    --enable-logging \
    --logging-sample-rate=1.0

gcloud compute backend-services add-backend http-backend \
    --instance-group=us-1-mig \
    --instance-group-region=$REGION_1 \
    --balancing-mode=RATE \
    --max-rate-per-instance=50 \
    --capacity-scaler=1.0 \
    --global

gcloud compute backend-services add-backend http-backend \
    --instance-group=notus-1-mig \
    --instance-group-region=$REGION_2 \
    --balancing-mode=UTILIZATION \
    --max-utilization=0.8 \
    --capacity-scaler=1.0 \
    --global

gcloud compute url-maps create http-lb \
    --default-service=http-backend

gcloud compute target-http-proxies create http-lb-proxy \
    --url-map=http-lb

gcloud compute forwarding-rules create http-lb-forwarding-rule-ipv4 \
    --global \
    --target-http-proxy=http-lb-proxy \
    --ports=80 \
    --load-balancing-scheme=EXTERNAL_MANAGED

gcloud compute forwarding-rules create http-lb-forwarding-rule-ipv6 \
    --global \
    --target-http-proxy=http-lb-proxy \
    --ports=80 \
    --ip-version=IPV6 \
    --load-balancing-scheme=EXTERNAL_MANAGED

# Get Load Balancer IP
LB_IP_V4=$(gcloud compute forwarding-rules describe http-lb-forwarding-rule-ipv4 --global --format="get(IPAddress)")
echo "Load Balancer IPv4: $LB_IP_V4"

# Wait for load balancer to be ready
echo "Waiting for load balancer to be ready..."
while [ -z "$RESULT" ]; do
    echo -n "."
    sleep 5
    RESULT=$(curl -m1 -s $LB_IP_V4 2>/dev/null | grep Apache || true)
done
echo ""
echo "Load balancer is ready!"

# Task 6: Stress test
gcloud compute instances create stress-test \
    --zone=us-central1-a \
    --machine-type=e2-micro \
    --image=mywebserver \
    --boot-disk-size=10GB

sleep 30

gcloud compute ssh stress-test --zone=us-central1-a --command="export LB_IP=$LB_IP_V4 && ab -n 500000 -c 1000 http://\$LB_IP/"

echo ""
echo "============================================"
echo "LAB COMPLETE!"
echo "Load Balancer IP: $LB_IP_V4"
echo "Test URL: http://$LB_IP_V4"
echo "============================================"
