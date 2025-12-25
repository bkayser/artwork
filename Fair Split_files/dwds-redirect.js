// Redirect Dart Web Developer Service (DWDS) requests to port 5173.
// 
// https://github.com/dart-lang/webdev/issues/2709
(function () {
  'use strict';

  if (window.location.port !== '5173') {
    return;
  }

  const TARGET_PORT = 5173;
  const SSE_HANDLER_PATH = '/$dwdsSseHandler';

  // Intercept fetch requests.
  const originalFetch = window.fetch;
  window.fetch = function (input, init) {
    let url = typeof input === 'string' ? input : input.url;

    if (url && url.includes(SSE_HANDLER_PATH)) {
      try {
        const urlObj = new URL(url, window.location.origin);
        if (urlObj.pathname === SSE_HANDLER_PATH || urlObj.pathname.endsWith(SSE_HANDLER_PATH)) {
          urlObj.port = TARGET_PORT;
          urlObj.protocol = window.location.protocol;
          url = urlObj.toString();

          if (typeof input === 'string') {
            input = url;
          } else {
            input = new Request(url, input);
          }
        }
      } catch (e) {
        console.warn('Failed to redirect SSE handler URL:', e);
      }
    }

    return originalFetch.call(this, input, init);
  };

  // Intercept XMLHttpRequest.
  const originalOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url, async, user, password) {
    if (url && url.includes(SSE_HANDLER_PATH)) {
      try {
        const urlObj = new URL(url, window.location.origin);
        if (urlObj.pathname === SSE_HANDLER_PATH || urlObj.pathname.endsWith(SSE_HANDLER_PATH)) {
          urlObj.port = TARGET_PORT;
          urlObj.protocol = window.location.protocol;
          url = urlObj.toString();
        }
      } catch (e) {
        console.warn('Failed to redirect SSE handler URL:', e);
      }
    }

    return originalOpen.call(this, method, url, async, user, password);
  };

  // Intercept EventSource (for SSE connections).
  const originalEventSource = window.EventSource;
  window.EventSource = function (url, eventSourceInitDict) {
    if (url && url.includes(SSE_HANDLER_PATH)) {
      try {
        const urlObj = new URL(url, window.location.origin);
        if (urlObj.pathname === SSE_HANDLER_PATH || urlObj.pathname.endsWith(SSE_HANDLER_PATH)) {
          urlObj.port = TARGET_PORT;
          urlObj.protocol = window.location.protocol;
          url = urlObj.toString();
        }
      } catch (e) {
        console.warn('Failed to redirect SSE handler URL:', e);
      }
    }

    return new originalEventSource(url, eventSourceInitDict);
  };

  console.log('DWDS SSE handler redirect configured to port ' + TARGET_PORT + '.');
})();

