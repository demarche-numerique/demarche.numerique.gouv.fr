import { defineConfig } from '@lingui/cli';

export default defineConfig({
  sourceLocale: 'fr',
  locales: ['fr', 'en'],
  catalogs: [
    {
      path: '<rootDir>/app/javascript/locales/{locale}/messages',
      include: ['app/javascript']
    }
  ],
  compileNamespace: 'ts'
});
