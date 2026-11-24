// A prefill link can carry the name of the person it was sent to, in the
// identite_nom, identite_prenom and identite_genre parameters of its address.
// The server keeps them out of its request log (filter_parameter_logging.rb);
// this does the same for the addresses the browser reports.
const IDENTITY_PREFIX = 'identite_';

export function withoutPrefilledIdentity(address: string): string {
  let url: URL;
  try {
    // not URL.canParse: Chrome < 120, Firefox < 115 and Safari < 17 lack it
    url = new URL(address);
  } catch {
    return address;
  }

  // collected first: deleting while iterating over the live list skips names
  const identity = Array.from(url.searchParams.keys()).filter((name) =>
    name.startsWith(IDENTITY_PREFIX)
  );
  if (identity.length == 0) {
    return address;
  }
  for (const name of identity) {
    url.searchParams.delete(name);
  }
  return url.toString();
}

// What Matomo must be told before a page view: the address of the page a
// prefill link opens and, on the next page, the referrer, which is that same
// address.
export function matomoAddressOverrides(
  page: string,
  referrer: string
): [setter: string, address: string][] {
  const overrides: [string, string][] = [];
  if (withoutPrefilledIdentity(page) != page) {
    overrides.push(['setCustomUrl', withoutPrefilledIdentity(page)]);
  }
  if (withoutPrefilledIdentity(referrer) != referrer) {
    overrides.push(['setReferrerUrl', withoutPrefilledIdentity(referrer)]);
  }
  return overrides;
}

// An error report carries the same two addresses, and names the page again as
// the file of each frame of the stack that runs code written in the page.
type ErrorReport = {
  request?: { url?: string; headers?: Record<string, string> };
  exception?: {
    values?: { stacktrace?: { frames?: { filename?: string }[] } }[];
  };
};

export function withoutPrefilledIdentityInReport<Report extends ErrorReport>(
  report: Report
): Report {
  const request = report.request;
  if (request?.url) {
    request.url = withoutPrefilledIdentity(request.url);
  }
  if (request?.headers?.Referer) {
    request.headers.Referer = withoutPrefilledIdentity(request.headers.Referer);
  }
  for (const exception of report.exception?.values ?? []) {
    for (const frame of exception.stacktrace?.frames ?? []) {
      if (frame.filename) {
        frame.filename = withoutPrefilledIdentity(frame.filename);
      }
    }
  }
  return report;
}
