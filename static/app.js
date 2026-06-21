const button = document.getElementById("ping");
const message = document.getElementById("message");

button.addEventListener("click", () => {
  message.textContent = "👋 Hello again!";
});
