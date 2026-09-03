import path from 'node:path';
import { playwright } from '@vitest/browser-playwright';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: {
    alias: {
      '@utils': path.resolve(__dirname, 'app/javascript/shared/utils.ts')
    }
  },
  test: {
    globals: true,
    browser: {
      enabled: true,
      provider: playwright(),
      headless: true,
      // Les fichiers de test partagent la même page (une iframe chacun) alors
      // que la souris et le clavier Playwright sont globaux à la page : deux
      // tests interactifs simultanés se volent le focus et ferment mutuellement
      // leurs popovers (SelectSections / ComboBoxSections).
      fileParallelism: false,
      instances: [
        { browser: 'chromium' },
        { browser: 'firefox' },
        { browser: 'webkit' }
      ]
    }
  }
});
