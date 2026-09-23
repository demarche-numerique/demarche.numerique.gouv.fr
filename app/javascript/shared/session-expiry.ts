// A session can die between two Turbo requests. The server answers those with a
// bare 401 and an X-Sign-In-Path header, because a redirect rendered inside a
// frame would inject the sign in page into a corner of the layout -- and each
// Warden scope has its own sign in page.

const REDIRECT_HEADER = 'X-Sign-In-Path';

// One navigation, whatever happens next: a page holding several frames gets a
// 401 on each of them, and they arrive while the first is already leaving.
let leaving = false;

addEventListener('turbo:before-fetch-response', (event) => {
  const { fetchResponse } = (event as CustomEvent).detail;
  const response = fetchResponse?.response;

  if (response?.status !== 401) return;

  const target = response.headers?.get(REDIRECT_HEADER);

  if (!target) return;

  // Decided before Turbo is told anything: taking the event and then declining
  // to navigate would leave the frame with no handler and no fallback.
  const destination = sameOriginUrl(target);

  if (!destination) return;

  // Otherwise Turbo keeps processing the empty 401 in parallel: a frame
  // request would raise turbo:frame-missing, and a visit could race ours.
  (event as CustomEvent).preventDefault();

  if (leaving) return;

  leaving = true;
  window.location.href = destination;
});

// The header is ours, but it is still a redirect read off the network: the
// server validates its own referers, and this must not be the one place that
// sends a browser wherever it is told.
function sameOriginUrl(target: string): string | null {
  try {
    const url = new URL(target, window.location.origin);

    return url.origin === window.location.origin ? url.toString() : null;
  } catch {
    return null;
  }
}
