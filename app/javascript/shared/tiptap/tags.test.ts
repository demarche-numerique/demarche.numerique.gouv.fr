import { describe, expect, it } from 'vite-plus/test';

import { tagDisplay } from './tags';

describe('tagDisplay', () => {
  it('renders a mandatory tag with a * suffix and default color', () => {
    expect(
      tagDisplay({ label: 'Nom', mandatory: true, conditional: false })
    ).toEqual({
      text: 'Nom *',
      classes: ['fr-tag', 'fr-tag--sm']
    });
  });

  it('renders an optional tag without suffix and default color', () => {
    expect(
      tagDisplay({ label: 'Nom', mandatory: false, conditional: false })
    ).toEqual({
      text: 'Nom',
      classes: ['fr-tag', 'fr-tag--sm']
    });
  });

  it('renders a conditional tag with the [conditionné] suffix and glycine color', () => {
    expect(
      tagDisplay({ label: 'Nom', mandatory: false, conditional: true })
    ).toEqual({
      text: 'Nom [conditionné]',
      classes: ['fr-tag', 'fr-tag--sm', 'fr-tag--purple-glycine']
    });
  });

  it('renders a mandatory conditional tag with both suffixes', () => {
    expect(
      tagDisplay({ label: 'Nom', mandatory: true, conditional: true })
    ).toEqual({
      text: 'Nom * [conditionné]',
      classes: ['fr-tag', 'fr-tag--sm', 'fr-tag--purple-glycine']
    });
  });

  it('handles tags without flags (dossier, identité…)', () => {
    expect(tagDisplay({ label: 'numéro du dossier' })).toEqual({
      text: 'numéro du dossier',
      classes: ['fr-tag', 'fr-tag--sm']
    });
  });
});
