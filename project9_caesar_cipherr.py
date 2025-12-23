import streamlit as st

st.set_page_config(page_title="Caesar Cipher 🔐", layout="centered")

# ---------------- HEADER ----------------
st.title("🔐 Caesar Cipher")
st.caption("Encode or decode messages using Caesar Cipher")
st.divider()

alphabet = list("abcdefghijklmnopqrstuvwxyz")

# ---------------- USER INPUTS ----------------
mode = st.radio(
    "Choose an option:",
    ["Encode", "Decode"],
    horizontal=True
)

text = st.text_input("Enter your message:")

shift = st.number_input(
    "Enter shift number:",
    min_value=0,
    max_value=25,
    step=1
)

# ---------------- CIPHER LOGIC ----------------
def caesar(original_text, shift_amount, mode):
    output_text = ""

    for letter in original_text.lower():
        if letter in alphabet:
            index = alphabet.index(letter)
            if mode == "Decode":
                new_index = index - shift_amount
            else:
                new_index = index + shift_amount

            output_text += alphabet[new_index % 26]
        else:
            output_text += letter  # keep symbols, spaces, numbers

    return output_text

# ---------------- ACTION ----------------
if st.button("🚀 Run Cipher"):
    if text.strip() == "":
        st.warning("Please enter some text.")
    else:
        result = caesar(text, shift, mode)
        st.success(f"Result ({mode}):")
        st.code(result)

st.divider()
st.caption("Built with Python & Streamlit | Day 9 of #100DaysOfCode")
