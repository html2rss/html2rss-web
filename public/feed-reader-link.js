document.addEventListener('DOMContentLoaded', function () {
  var readerLink = document.querySelector('[data-feed-reader-link]');
  if (!readerLink) return;
  var currentHref = readerLink.getAttribute('href');
  if (currentHref && currentHref !== '#') return;

  var pageHref = window.location.href;
  var feedHref = pageHref.indexOf('feed:') === 0 ? pageHref : 'feed:' + pageHref;
  readerLink.setAttribute('href', feedHref);
});
