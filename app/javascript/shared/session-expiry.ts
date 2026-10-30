// A session can die between two Turbo requests, and a redirect rendered inside a
// frame would put the sign in page in a corner of the layout. The server answers
// a bare 401 instead, recovered here with a reload -- the way `utils.ts` recovers
// an XHR 401, and idempotent, so a page full of frames needs no guarding.
addEventListener('turbo:before-fetch-response', (event) => {
  const { fetchResponse } = (event as CustomEvent).detail;

  if (fetchResponse?.response?.status !== 401) return;

  // Otherwise Turbo processes the empty 401 in parallel and a visit races ours.
  (event as CustomEvent).preventDefault();

  window.location.reload();
});
