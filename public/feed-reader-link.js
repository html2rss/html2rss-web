document.addEventListener('DOMContentLoaded', function () {
  var readerLink = document.querySelector('[data-feed-reader-link]');
  if (!readerLink) return;

  readerLink.setAttribute('href', 'feed:' + window.location.href);
});
