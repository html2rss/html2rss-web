document.addEventListener("DOMContentLoaded", (_) => {
  const $url = document.getElementById("url");
  $url.value = window.location.href;
  $url.addEventListener("click", ({ target }) => target.select());
});
