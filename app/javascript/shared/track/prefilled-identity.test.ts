import { expect, suite, test } from 'vite-plus/test';

import { withoutPrefilledIdentity } from './prefilled-identity';

const PAGE = 'https://demarche.numerique.gouv.fr/commencer/integration-eae';

suite('withoutPrefilledIdentity', () => {
  test('removes the identity a prefill link carries, and nothing else', () => {
    expect(
      withoutPrefilledIdentity(
        `${PAGE}?champ_Q2hhbXAtMQ=Externe&identite_nom=Martin&identite_prenom=Zo%C3%A9&identite_genre=Mme#contenu`
      )
    ).toEqual(`${PAGE}?champ_Q2hhbXAtMQ=Externe#contenu`);
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
