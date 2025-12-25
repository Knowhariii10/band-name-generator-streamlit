import streamlit as st

st.set_page_config(page_title="Calculator 🧮", layout="centered")

# ---------------- HEADER ----------------
st.title("🧮 Python Calculator")
st.caption("Simple calculator using integers only")
st.divider()

# ---------------- FUNCTIONS ----------------
def add(n1, n2):
    return n1 + n2

def subtract(n1, n2):
    return n1 - n2

def multiply(n1, n2):
    return n1 * n2

def divide(n1, n2):
    if n2 == 0:
        return "Cannot divide by zero"
    return n1 // n2   # integer division

operations = {
    "+": add,
    "-": subtract,
    "*": multiply,
    "/": divide
}

# ---------------- INPUTS (INT ONLY) ----------------
num1 = st.number_input(
    "Enter first number",
    min_value=0,
    step=1,
    format="%d"
)

num2 = st.number_input(
    "Enter second number",
    min_value=0,
    step=1,
    format="%d"
)

operation = st.selectbox(
    "Choose operation",
    list(operations.keys())
)

# ---------------- CALCULATION ----------------
if st.button("🟰 Calculate"):
    result = operations[operation](num1, num2)
    st.success(f"Result: {num1} {operation} {num2} = {result}")

# ---------------- CLEAR ----------------
if st.button("🔁 Clear"):
    st.experimental_rerun()

st.caption("Built with Python & Streamlit | Day 11 of #100DaysOfCode")
