import { I18nProvider } from 'react-aria-components';
import { UNSAFE_PortalProvider } from 'react-aria';
import { StrictMode, type ReactNode } from 'react';
import { findOrCreateContainerElement } from 'coldwired/react';
import { I18nProvider as LinguiI18nProvider } from '@lingui/react';
import { i18n } from '@lingui/core';

const getContainer = () =>
  findOrCreateContainerElement('rac-portal') as HTMLElement;

export function Layout({ children }: { children: ReactNode }) {
  return (
    <LinguiI18nProvider i18n={i18n}>
      <I18nProvider locale={i18n.locale}>
        <UNSAFE_PortalProvider getContainer={getContainer}>
          <StrictMode>{children}</StrictMode>
        </UNSAFE_PortalProvider>
      </I18nProvider>
    </LinguiI18nProvider>
  );
}
