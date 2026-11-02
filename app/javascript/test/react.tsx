import type { ReactNode } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { I18nProvider as LinguiI18nProvider } from '@lingui/react';
import { i18n } from '@lingui/core';
import { I18nProvider } from 'react-aria-components';

// Mounts a component inside the providers of Layout, minus two of its parts:
// the portal container, in which the popovers stay hidden from the tests on
// WebKit, and StrictMode, whose double-invoked effects make the change event
// bookkeeping of the comboboxes fire once too often on Firefox.
export function createAppRoot(container: Element): Root {
  const root = createRoot(container);
  return {
    render: (children: ReactNode) =>
      root.render(
        <LinguiI18nProvider i18n={i18n}>
          <I18nProvider locale={i18n.locale}>{children}</I18nProvider>
        </LinguiI18nProvider>
      ),
    unmount: () => root.unmount()
  };
}
