import { fileURLToPath } from 'node:url';
import { lingui, linguiTransformerBabelPreset } from '@lingui/vite-plugin';
import optimizeLocales from '@react-aria/optimize-locales-plugin';
import babel from '@rolldown/plugin-babel';
import react, { reactCompilerPreset } from '@vitejs/plugin-react';
import { createLogger, defineConfig, lazyPlugins } from 'vite-plus';
import { playwright } from 'vite-plus/test/browser-playwright';
import fullReload from 'vite-plugin-full-reload';
import ruby from 'vite-plugin-ruby';

const logger = createLogger();
const originalWarn = logger.warn.bind(logger);
logger.warn = (msg, options) => {
  if (msg.includes('Invalid media query')) return;
  originalWarn(msg, options);
};

// Vitest shares this config and its plugins, minus the Rails integration:
// vite-plugin-ruby would move the root, the port and the base to the values of
// config/vite.json.
const vitest = Boolean(process.env.VITEST);

export default defineConfig({
  resolve: {
    alias: {
      '@utils': fileURLToPath(
        new URL('./app/javascript/shared/utils.ts', import.meta.url)
      )
    }
  },
  build: { sourcemap: true, assetsInlineLimit: 0 },
  customLogger: logger,
  css: {
    transformer: 'lightningcss',
    lightningcss: { errorRecovery: true }
  },
  plugins: lazyPlugins(() => [
    ...(vitest
      ? []
      : [
          ruby(),
          fullReload(
            [
              'config/routes.rb',
              'app/views/**/*',
              'app/components/**/*.{haml,erb}'
            ],
            { delay: 200 }
          )
        ]),
    react(),
    babel({
      presets: [reactCompilerPreset(), linguiTransformerBabelPreset()]
    }),
    optimizeLocales.vite({ locales: ['en-US', 'fr-FR'] }),
    lingui()
  ]),
  test: {
    globals: true,
    setupFiles: ['./app/javascript/test/setup.ts'],
    // Les fichiers de test partagent la même page (une iframe chacun) alors
    // que la souris et le clavier Playwright sont globaux à la page : deux
    // tests interactifs simultanés se volent le focus et ferment mutuellement
    // leurs popovers (SelectSections / ComboBoxSections).
    fileParallelism: false,
    browser: {
      enabled: true,
      provider: playwright(),
      headless: true,
      instances: [
        { browser: 'chromium' },
        { browser: 'firefox' },
        { browser: 'webkit' }
      ]
    }
  },
  lint: {
    options: { typeAware: true, typeCheck: true },
    categories: { correctness: 'error' },
    // Sprockets directives, not JavaScript.
    ignorePatterns: ['app/assets/config/**'],
    rules: {
      'no-unused-vars': ['error', { ignoreRestSiblings: true }],
      'typescript/no-explicit-any': 'error',
      // Stimulus helpers (`this.on`, `this.debounce`) bind the methods they receive.
      'typescript/unbound-method': 'off'
    },
    overrides: [
      {
        // Scoped to the React code: elsewhere `Chartkick.use(...)` reads as a hook call.
        files: ['app/javascript/components/**/*.{ts,tsx}'],
        plugins: ['react'],
        rules: { 'react/rules-of-hooks': 'error' }
      }
    ]
  },
  fmt: {
    printWidth: 80,
    singleQuote: true,
    trailingComma: 'none',
    sortPackageJson: false,
    // Prettier only ever covered the front-end sources.
    ignorePatterns: [
      '**/*.{yml,yaml,json,md,html,toml,graphql,mjs}',
      'public/**',
      'vendor/**'
    ]
  }
});
