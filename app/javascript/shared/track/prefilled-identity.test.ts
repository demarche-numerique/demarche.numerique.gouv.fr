import { expect, suite, test } from 'vite-plus/test';

import {
  matomoAddressOverrides,
  withoutPrefilledIdentity,
  withoutPrefilledIdentityInReport
} from './prefilled-identity';

const PAGE = 'https://demarche.numerique.gouv.fr/commencer/integration-eae';
const NAMED_PAGE = `${PAGE}?identite_nom=Martin`;

suite('withoutPrefilledIdentity', () => {
  test('removes the identity a prefill link carries, and nothing else', () => {
    expect(
      withoutPrefilledIdentity(
        `${PAGE}?champ_Q2hhbXAtMQ=Externe&identite_nom=Martin&identite_prenom=Zo%C3%A9&identite_genre=Mme#contenu`
      )
    ).toEqual(`${PAGE}?champ_Q2hhbXAtMQ=Externe#contenu`);
  });

  test('removes a name whose parameter is percent-encoded', () => {
    expect(withoutPrefilledIdentity(`${PAGE}?identite%5Fnom=Martin`)).toEqual(
      PAGE
    );
  });

  test('works in a browser without URL.canParse', () => {
    const canParse = URL.canParse;
    // Chrome < 120, Firefox < 115 and Safari < 17 lack it
    Reflect.deleteProperty(URL, 'canParse');
    try {
      expect(withoutPrefilledIdentity(NAMED_PAGE)).toEqual(PAGE);
    } finally {
      URL.canParse = canParse;
    }
  });

  test('leaves an address without identity as it is', () => {
    const address = `${PAGE}?champ_Q2hhbXAtMQ=Base+%28BASE%29`;

    expect(withoutPrefilledIdentity(address)).toEqual(address);
    expect(withoutPrefilledIdentity('')).toEqual('');
  });

  test('leaves what is not an address as it is', () => {
    expect(withoutPrefilledIdentity('identite_nom=Martin')).toEqual(
      'identite_nom=Martin'
    );
  });
});

suite('matomoAddressOverrides', () => {
  test('reports the page a prefill link opens without the identity', () => {
    expect(matomoAddressOverrides(NAMED_PAGE, '')).toEqual([
      ['setCustomUrl', PAGE]
    ]);
  });

  test('reports the referrer of the next page without the identity', () => {
    expect(matomoAddressOverrides(PAGE, NAMED_PAGE)).toEqual([
      ['setReferrerUrl', PAGE]
    ]);
  });

  test('overrides nothing on any other page', () => {
    expect(matomoAddressOverrides(PAGE, '')).toEqual([]);
  });
});

suite('withoutPrefilledIdentityInReport', () => {
  test('removes the identity from the page and from its referrer', () => {
    const report = {
      message: 'boom',
      request: { url: NAMED_PAGE, headers: { Referer: NAMED_PAGE } }
    };

    expect(withoutPrefilledIdentityInReport(report)).toEqual({
      message: 'boom',
      request: { url: PAGE, headers: { Referer: PAGE } }
    });
  });

  test('removes the identity from the frames of code written in the page', () => {
    const bundle = 'https://demarche.numerique.gouv.fr/vite/assets/a.js';
    const report = {
      exception: {
        values: [
          {
            stacktrace: {
              frames: [{ filename: NAMED_PAGE }, { filename: bundle }, {}]
            }
          }
        ]
      }
    };

    expect(
      withoutPrefilledIdentityInReport(report).exception.values[0].stacktrace
        .frames
    ).toEqual([{ filename: PAGE }, { filename: bundle }, {}]);
  });

  test('removes the identity from the breadcrumbs of a navigation inside the page', () => {
    const path = '/commencer/integration-eae';
    const report = {
      breadcrumbs: [
        { category: 'ui.click', message: 'a.fr-link' },
        {
          category: 'navigation',
          data: {
            from: `${path}?identite_nom=Martin`,
            to: `${path}?champ_Q2hhbXAtMQ=Externe&identite_nom=Martin#contenu`
          }
        },
        { category: 'fetch', data: { url: NAMED_PAGE, status_code: 200 } },
        { category: 'fetch', data: { url: '/dossiers/12/brouillon?x=a%20b' } }
      ]
    };

    expect(withoutPrefilledIdentityInReport(report).breadcrumbs).toEqual([
      { category: 'ui.click', message: 'a.fr-link' },
      {
        category: 'navigation',
        data: { from: path, to: `${path}?champ_Q2hhbXAtMQ=Externe#contenu` }
      },
      { category: 'fetch', data: { url: PAGE, status_code: 200 } },
      { category: 'fetch', data: { url: '/dossiers/12/brouillon?x=a%20b' } }
    ]);
  });

  test('leaves a report without address as it is', () => {
    const report = { request: { headers: { 'User-Agent': 'Firefox' } } };

    expect(withoutPrefilledIdentityInReport(report)).toEqual({
      request: { headers: { 'User-Agent': 'Firefox' } }
    });
    expect(withoutPrefilledIdentityInReport({})).toEqual({});
  });
});
