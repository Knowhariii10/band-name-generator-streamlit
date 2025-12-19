import streamlit as st

st.set_page_config(page_title="Band Name Generator")

st.title("🎸 Welcome to Band Generator!")
st.write("Enter the details below to generate your band name.")

city = st.text_input("🌆 What is your dream city?")
pet = st.text_input("🐶 What is your pet name?")

if st.button("🎵 Generate Band Name"):
    if city and pet:
        st.success(f"🎶 The Generated Band Name is {city} {pet}")
    else:
        st.warning("⚠️ Please fill in both fields.")
