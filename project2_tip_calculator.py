import streamlit as st

st.set_page_config(page_title="Tip Calculator")

st.title("💰 Welcome to the Tip Calculator!")

bill = st.number_input("💵 What was the total bill? ($)", min_value=0.0, step=1.0)
tip = st.selectbox(
    "💡 What percentage tip would you like to give?",
    [10, 12, 15]
)
people = st.number_input(
    "👥 How many people to split the bill?",
    min_value=1,
    step=1
)

if st.button("🧮 Calculate"):
    tip_as_percent = tip / 100
    total_tip_amount = tip_as_percent * bill
    total_bill = bill + total_tip_amount
    bill_per_person = total_bill / people

    st.success(f"Each person should pay **${bill_per_person:.2f}**")
