import { lingui } from '@lingui/vite-plugin';
import optimizeLocales from '@react-aria/optimize-locales-plugin';
import react from '@vitejs/plugin-react-swc';
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
  resolve: { alias: { '@utils': '/shared/utils.ts' } },
  build: { sourcemap: true, assetsInlineLimit: 0 },
  customLogger: logger,
  css: {
    transformer: 'lightningcss',
    lightningcss: { errorRecovery: true }
  },
  plugins: [
    ruby(),
    react({
      plugins: [['@lingui/swc-plugin', {}]]
    }),
    fullReload(
      ['config/routes.rb', 'app/views/**/*', 'app/components/**/*.haml'],
      { delay: 200 }
    ),
    {
      ...optimizeLocales.vite({
        locales: ['en-US', 'fr-FR']
      }),
      enforce: 'pre' as const
    },
    lingui()
  ]
});
