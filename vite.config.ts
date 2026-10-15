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

// Vitest shares this config without the plugins: the tests mock the Lingui
// macro, and vite-plugin-ruby would move the root, the port and the base to the
// values of config/vite.json.
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
  plugins: lazyPlugins(() =>
    vitest
      ? []
      : [
          ruby(),
          react(),
          babel({
            presets: [reactCompilerPreset(), linguiTransformerBabelPreset()]
          }),
          fullReload(
            [
              'config/routes.rb',
              'app/views/**/*',
              'app/components/**/*.{haml,erb}'
            ],
            { delay: 200 }
          ),
          optimizeLocales.vite({ locales: ['en-US', 'fr-FR'] }),
          lingui()
        ]
  ),
  test: {
    // Vitest v4 compatibility: preserve mock call history.
    // Remove after tests no longer rely on calls from setup or earlier tests.
    // https://viteplus.dev/guide/vitest-v5#remove-unneeded-compatibility-settings
    // https://vitest.dev/guide/migration/#clearmocks-is-enabled-by-default
    clearMocks: false,
    globals: true,
    // Les fichiers de test partagent la même page (une iframe chacun) alors
    // que la souris et le clavier Playwright sont globaux à la page : deux
    // tests interactifs simultanés se volent le focus et ferment mutuellement
    // leurs popovers (SelectSections / ComboBoxSections).
    fileParallelism: false,
    browser: {
      locators: {
        // Vitest v4 compatibility: keep partial, case-insensitive locator matching.
        // Remove after updating locators for full, case-sensitive matches.
        // https://viteplus.dev/guide/vitest-v5#remove-unneeded-compatibility-settings
        // https://vitest.dev/guide/migration/#locators-are-strict-by-default
        exact: false
      },
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
    plugins: ['oxc', 'typescript', 'unicorn'],
    jsPlugins: [{ name: 'vite-plus', specifier: 'vite-plus/oxlint-plugin' }],
    categories: { correctness: 'warn' },
    env: { builtin: true },
    options: { typeAware: true, typeCheck: true },
    rules: {
      'constructor-super': 'error',
      'for-direction': 'error',
      'getter-return': 'error',
      'no-async-promise-executor': 'error',
      'no-case-declarations': 'error',
      'no-class-assign': 'error',
      'no-compare-neg-zero': 'error',
      'no-cond-assign': 'error',
      'no-const-assign': 'error',
      'no-constant-binary-expression': 'error',
      'no-constant-condition': 'error',
      'no-control-regex': 'error',
      'no-debugger': 'error',
      'no-delete-var': 'error',
      'no-dupe-class-members': 'error',
      'no-dupe-else-if': 'error',
      'no-dupe-keys': 'error',
      'no-duplicate-case': 'error',
      'no-empty': 'error',
      'no-empty-character-class': 'error',
      'no-empty-pattern': 'error',
      'no-empty-static-block': 'error',
      'no-ex-assign': 'error',
      'no-extra-boolean-cast': 'error',
      'no-fallthrough': 'error',
      'no-func-assign': 'error',
      'no-global-assign': 'error',
      'no-import-assign': 'error',
      'no-invalid-regexp': 'error',
      'no-irregular-whitespace': 'error',
      'no-loss-of-precision': 'error',
      'no-misleading-character-class': 'error',
      'no-new-native-nonconstructor': 'error',
      'no-nonoctal-decimal-escape': 'error',
      'no-obj-calls': 'error',
      'no-prototype-builtins': 'error',
      'no-redeclare': 'error',
      'no-regex-spaces': 'error',
      'no-self-assign': 'error',
      'no-setter-return': 'error',
      'no-shadow-restricted-names': 'error',
      'no-sparse-arrays': 'error',
      'no-this-before-super': 'error',
      'no-unassigned-vars': 'error',
      'no-undef': 'error',
      'no-unexpected-multiline': 'error',
      'no-unreachable': 'error',
      'no-unsafe-finally': 'error',
      'no-unsafe-negation': 'error',
      'no-unsafe-optional-chaining': 'error',
      'no-unused-labels': 'error',
      'no-unused-private-class-members': 'error',
      'no-unused-vars': 'error',
      'no-useless-assignment': 'error',
      'no-useless-backreference': 'error',
      'no-useless-catch': 'error',
      'no-useless-escape': 'error',
      'no-with': 'error',
      'preserve-caught-error': 'error',
      'require-yield': 'error',
      'use-isnan': 'error',
      'valid-typeof': 'error',
      'no-array-constructor': 'error',
      'no-unused-expressions': 'error',
      'typescript/ban-ts-comment': 'error',
      'typescript/no-duplicate-enum-values': 'error',
      'typescript/no-empty-object-type': 'error',
      'typescript/no-explicit-any': 'error',
      'typescript/no-extra-non-null-assertion': 'error',
      'typescript/no-misused-new': 'error',
      'typescript/no-namespace': 'error',
      'typescript/no-non-null-asserted-optional-chain': 'error',
      'typescript/no-require-imports': 'error',
      'typescript/no-this-alias': 'error',
      'typescript/no-unnecessary-type-constraint': 'error',
      'typescript/no-unsafe-declaration-merging': 'error',
      'typescript/no-unsafe-function-type': 'error',
      'typescript/no-wrapper-object-types': 'error',
      'typescript/prefer-as-const': 'error',
      'typescript/prefer-namespace-keyword': 'error',
      'typescript/triple-slash-reference': 'error',
      // Stimulus helpers (`this.on`, `this.debounce`) bind the methods they receive.
      'typescript/unbound-method': 'off',
      'vite-plus/prefer-vite-plus-imports': 'error'
    },
    overrides: [
      {
        files: ['**/*.ts', '**/*.tsx', '**/*.mts', '**/*.cts'],
        rules: {
          'constructor-super': 'off',
          'getter-return': 'off',
          'no-class-assign': 'off',
          'no-const-assign': 'off',
          'no-dupe-class-members': 'off',
          'no-dupe-keys': 'off',
          'no-func-assign': 'off',
          'no-import-assign': 'off',
          'no-new-native-nonconstructor': 'off',
          'no-obj-calls': 'off',
          'no-redeclare': 'off',
          'no-setter-return': 'off',
          'no-this-before-super': 'off',
          'no-undef': 'off',
          'no-unreachable': 'off',
          'no-unsafe-negation': 'off',
          'no-var': 'error',
          'no-with': 'off',
          'prefer-const': 'error',
          'prefer-rest-params': 'error',
          'prefer-spread': 'error'
        }
      },
      {
        files: ['app/javascript/components/**/*.{ts,tsx,js,jsx}'],
        plugins: ['react'],
        rules: {
          'react/react-in-jsx-scope': 'off',
          'react/rules-of-hooks': 'error',
          'react/exhaustive-deps': 'error',
          'react/static-components': 'error',
          'react/use-memo': 'error',
          'react/preserve-manual-memoization': 'error',
          'react/incompatible-library': 'warn',
          'react/immutability': 'error',
          'react/globals': 'error',
          'react/refs': 'error',
          'react/set-state-in-effect': 'error',
          'react/error-boundaries': 'error',
          'react/purity': 'error',
          'react/set-state-in-render': 'error',
          'react/unsupported-syntax': 'warn'
        }
      },
      {
        files: ['app/javascript/**/*.{ts,tsx,js,jsx}'],
        env: { browser: true }
      },
      {
        // Administrate injects its own copy of jQuery.
        files: ['app/javascript/manager/**/*.js'],
        globals: { $: 'readonly' }
      },
      {
        files: ['*.config.{ts,js}'],
        env: { node: true }
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
