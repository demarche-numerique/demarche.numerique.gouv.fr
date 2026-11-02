import { getConfig } from '@utils';
const {
  crisp: { websiteId, enabled, user },
  locale
} = getConfig();

declare const window: Window &
  typeof globalThis & {
    CRISP_WEBSITE_ID?: string | null;
    CRISP_RUNTIME_CONFIG?: {
      locale: string;
    };
    $crisp: (
      | [cmd: string, key: string, value: unknown]
      | [key: string, value: unknown]
    )[];
  };

if (enabled) {
  window.$crisp = [];
  window.CRISP_WEBSITE_ID = websiteId;
  window.CRISP_RUNTIME_CONFIG = {
    locale: locale
  };

  const script = document.createElement('script');
  const firstScript = document.getElementsByTagName('script')[0];
  script.type = 'text/javascript';
  script.id = 'crisp-js';
  script.async = true;
  script.src = 'https://client.crisp.chat/l.js';
  firstScript.parentNode?.insertBefore(script, firstScript);

  window.$crisp.push([
    'on',
    'chat:initiated',
    () => {
      window.$crisp.push([
        'set',
        'user:email',
        [user.email, user.emailSignature].filter(Boolean)
      ]);
      window.$crisp.push(['set', 'session:segments', [user.segments]]);
    }
  ]);

  // Prevent Crisp to log warnings about Sentry overriding document.addEventListener
  window.$crisp.push(['safe', true]);
}
