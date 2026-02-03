async function updateCounter() {
  const counter = document.querySelector(".counter-number");

  try {
    const response = await fetch(
      "https://rmyu4najdt5mk64rbopguj2sku0pjpso.lambda-url.ap-south-1.on.aws/"
    );

    const data = await response.json();
    counter.innerHTML = `Views: ${data.views}`;
  } catch (error) {
    console.error(error);
    counter.innerHTML = "Couldn't read views";
  }
}

updateCounter();
