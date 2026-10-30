import * as Turbo from '@hotwired/turbo';
import { Application } from '@hotwired/stimulus';

import '../manager/fields/features';
import { registerControllers } from '../shared/stimulus-loader';
import { setupLocale } from '../shared/i18n';

const application = Application.start();
registerControllers(application);

Turbo.session.drive = false;

addEventListener('DOMContentLoaded', () => {
  document.body.setAttribute('data-controller', 'turbo');
});

await setupLocale();
