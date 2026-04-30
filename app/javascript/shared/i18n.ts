import { i18n } from '@lingui/core';

function getLocale() {
  const locale = document.documentElement.lang;
  if (['fr', 'en'].includes(locale)) {
    return locale;
  }
  return 'fr';
}

export async function setupLocale() {
  const locale = getLocale();
  const { messages } = await import(`../locales/${locale}/messages.po`);
  i18n.load(locale, messages);
  i18n.activate(locale);
  console.debug(`locale: ${locale}`);
}
