// A session can die between two Turbo requests: it expired, it was revoked, or
// a new sign in closed it. The server answers those with a bare 401 rather than
// a redirect, because a redirect rendered inside a frame would inject the sign
// in page into a corner of the layout.
//
// Where to go next comes from the server too, in a header: each Warden scope has
// its own sign in page, and an usager and a super admin must not land on the
// same one.

const REDIRECT_HEADER = 'X-Sign-In-Path';

addEventListener('turbo:before-fetch-response', (event) => {
  const { fetchResponse } = (event as CustomEvent).detail;
  const response = fetchResponse?.response;

  if (response?.status !== 401) return;

  const target = response.headers?.get(REDIRECT_HEADER);

  if (target) {
    // Otherwise Turbo keeps processing the empty 401 in parallel: a frame
    // request would raise turbo:frame-missing, and a visit could race ours.
    (event as CustomEvent).preventDefault();
    window.location.href = target;
  }
});
