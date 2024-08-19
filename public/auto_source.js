// TODO: when a ?url=%s param is available, set the value of the url input field to %s
const $form = document.querySelector("form");
const $url = document.querySelector("#url");
const $iframe = document.querySelector("iframe");
const $rssUrl = document.querySelector("#rss_url");

$url?.addEventListener("change", (event) => {
  delete $iframe.src;
  delete $rssUrl.value;
});

$form?.addEventListener("submit", async (event) => {
  event.preventDefault();

  if ($url && $rssUrl) {
    const url = $url?.value;

    if (!url || `${url}`.trim() === "" || !url.startsWith("http")) {
      return;
    }

    const encodedUrl = btoa(url).replace(/=/g, "");
    const baseUrl = new URL(window.location.origin);
    const autoSourceUrl = `${baseUrl}auto_source/${encodedUrl}`;

    $rssUrl.value = autoSourceUrl;
    $rssUrl.select();
  }
});

$rssUrl?.addEventListener("focus", () => {
  $iframe.src = `${$rssUrl.value}#items`;
});
