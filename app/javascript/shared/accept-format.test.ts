import { suite, test, expect } from 'vite-plus/test';

import { parseAcceptForDisplay } from './accept-format';

suite('@accept-format', () => {
  suite('parseAcceptForDisplay', () => {
    test('returns lowercase dotted extensions for a .ext-only accept', () => {
      expect(parseAcceptForDisplay('.pdf, .docx')).toBe('.pdf, .docx');
    });

    test('returns a family label for a wildcard MIME category', () => {
      expect(parseAcceptForDisplay('image/*')).toBe('.jpg, .jpeg, .png');
    });

    test('falls back to a generic label when nothing is recognised', () => {
      expect(parseAcceptForDisplay('')).toBe('certains formats spécifiques');
    });

    test('does not emit an extension twice when accept mixes MIME types and their .ext', () => {
      const accept = 'application/pdf, image/jpeg, .pdf, .jpeg';

      const result = parseAcceptForDisplay(accept);

      // Chaque extension ne doit apparaître qu'une fois (peu importe la casse,
      // peu importe la présence d'un point initial). On extrait toutes les
      // extensions du résultat et on vérifie l'absence de doublons.
      const extensions = result
        .split(',')
        .map((token) => token.trim().replace(/^\./, '').toLowerCase());
      const duplicates = extensions.filter(
        (ext, index) => extensions.indexOf(ext) !== index
      );

      expect(duplicates).toEqual([]);
    });

    test('keeps an extension that is not covered by any family label', () => {
      // .acidcsa est ajouté côté Ruby à côté de application/octet-stream :
      // aucun mapping family ne le couvre, il doit donc rester dans le rendu.
      const accept = 'application/pdf, .pdf, .acidcsa';

      expect(parseAcceptForDisplay(accept)).toContain('.acidcsa');
    });
  });
});
