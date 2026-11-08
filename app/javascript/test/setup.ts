import { setupLocale } from '../shared/i18n';

// Rails sets the page language; the test page says `en`.
document.documentElement.lang = 'fr';
await setupLocale();
