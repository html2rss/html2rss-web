document.addEventListener('DOMContentLoaded', function () {
  var readerLink = document.querySelector('[data-feed-reader-link]');
  if (readerLink) {
    var currentHref = readerLink.getAttribute('href');
    if (!currentHref || currentHref === '#') {
      var pageHref = window.location.href;
      var feedHref = pageHref.indexOf('feed:') === 0 ? pageHref : 'feed:' + pageHref;
      readerLink.setAttribute('href', feedHref);
    }
  }

  var jsonLink = document.querySelector('[data-json-feed-link]');
  if (jsonLink) {
    jsonLink.setAttribute('href', deriveJsonFeedUrl());
  }

  var copyButton = document.querySelector('[data-copy-feed-url]');
  if (copyButton) {
    if (!navigator.clipboard || !navigator.clipboard.writeText) {
      copyButton.hidden = true;
    } else {
      var copyStatus = document.querySelector('[data-copy-feed-url-status]');
      var copyLabel = copyButton.textContent;
      copyButton.addEventListener('click', function () {
        navigator.clipboard.writeText(window.location.href).then(function () {
          copyButton.textContent = 'Copied!';
          if (copyStatus) {
            copyStatus.textContent = 'Copied!';
          }
          globalThis.setTimeout(function () {
            copyButton.textContent = copyLabel;
            if (copyStatus) {
              copyStatus.textContent = '';
            }
          }, 2500);
        }).catch(function () {});
      });
    }
  }

  function deriveJsonFeedUrl() {
    var url = new URL(window.location.href);
    var pathname = url.pathname;
    var extensions = ['.xml', '.rss', '.json'];

    for (var index = 0; index < extensions.length; index += 1) {
      var suffix = extensions[index];
      if (pathname.endsWith(suffix)) {
        pathname = pathname.slice(0, -suffix.length);
        break;
      }
    }

    url.pathname = pathname + '.json';
    return url.toString();
  }
});
