import { StrictMode, type ReactNode } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { I18nProvider as LinguiI18nProvider } from '@lingui/react';
import { i18n } from '@lingui/core';
import { I18nProvider } from 'react-aria-components';

// Mounts a component inside the providers of Layout, minus its portal
// container: on WebKit the popovers rendered into it stay hidden from the tests.
export function createAppRoot(container: Element): Root {
  const root = createRoot(container);
  return {
    render: (children: ReactNode) =>
      root.render(
        <LinguiI18nProvider i18n={i18n}>
          <I18nProvider locale={i18n.locale}>
            <StrictMode>{children}</StrictMode>
          </I18nProvider>
        </LinguiI18nProvider>
      ),
    unmount: () => root.unmount()
  };
}
