async function updateCounter() {
  const counter = document.querySelector(".counter-number");
  try {
    const response = await fetch(CONFIG.LAMBDA_URL);  // ← Uses dynamic config
    const data = await response.json();
    counter.innerHTML = `Views: ${data.views}`;
  } catch (error) {
    console.error(error);
    counter.innerHTML = "Couldn't read views";
  }
}
updateCounter();