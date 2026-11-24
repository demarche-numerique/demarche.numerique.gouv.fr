// A prefill link can carry the name of the person it was sent to, in the
// identite_nom, identite_prenom and identite_genre parameters of its address.
// The server keeps them out of its request log (filter_parameter_logging.rb);
// this does the same for the addresses the browser reports.
const IDENTITY_PREFIX = 'identite_';

export function withoutPrefilledIdentity(address: string): string {
  if (!address.includes(IDENTITY_PREFIX) || !URL.canParse(address)) {
    return address;
  }

  const url = new URL(address);
  // collected first: deleting while iterating over the live list skips names
  const identity = Array.from(url.searchParams.keys()).filter((name) =>
    name.startsWith(IDENTITY_PREFIX)
  );
  for (const name of identity) {
    url.searchParams.delete(name);
  }
  return url.toString();
}
