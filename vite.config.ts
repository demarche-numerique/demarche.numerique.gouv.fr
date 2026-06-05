import { lingui, linguiTransformerBabelPreset } from '@lingui/vite-plugin';
import optimizeLocales from '@react-aria/optimize-locales-plugin';
import babel from '@rolldown/plugin-babel';
import react, { reactCompilerPreset } from '@vitejs/plugin-react';
import { createLogger, defineConfig } from 'vite';
import fullReload from 'vite-plugin-full-reload';
import ruby from 'vite-plugin-ruby';

const logger = createLogger();
const originalWarn = logger.warn.bind(logger);
logger.warn = (msg, options) => {
  if (msg.includes('Invalid media query')) return;
  originalWarn(msg, options);
};

export default defineConfig({
  resolve: {
    alias: { '@utils': '/shared/utils.ts' },
    dedupe: [
      'prosemirror-model',
      'prosemirror-state',
      'prosemirror-view',
      'prosemirror-transform',
      'prosemirror-keymap',
      'prosemirror-commands'
    ]
  },
  build: { sourcemap: true, assetsInlineLimit: 0 },
  customLogger: logger,
  css: {
    transformer: 'lightningcss',
    lightningcss: { errorRecovery: true }
  },
  plugins: [
    ruby(),
    react(),
    babel({
      presets: [reactCompilerPreset(), linguiTransformerBabelPreset()]
    }),
    fullReload(
      ['config/routes.rb', 'app/views/**/*', 'app/components/**/*.haml'],
      { delay: 200 }
    ),
    optimizeLocales.vite({ locales: ['en-US', 'fr-FR'] }),
    lingui()
  ]
});
