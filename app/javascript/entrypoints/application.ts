import 'core-js/actual/object/has-own';
import 'core-js/proposals/relative-indexing-method';
import Rails from '@rails/ujs';
import * as ActiveStorage from '@rails/activestorage';
import * as Turbo from '@hotwired/turbo';
import { Application } from '@hotwired/stimulus';

import '../shared/dsfr';
import '../shared/activestorage/ujs';
import '../shared/safari-11-empty-file-workaround';
import '../shared/toggle-target';
import '../shared/intl-listformat';
import '../shared/session-expiry';

import { registerControllers } from '../shared/stimulus-loader';

import '../new_design/form-validation';

import { setupLocale } from '../shared/i18n';

declare global {
  interface Window {
    _rails_loaded?: boolean;
  }
}

await setupLocale();

const application = Application.start();
registerControllers(application);

// Start Rails helpers
ActiveStorage.start();
if (!window._rails_loaded) {
  Rails.start();
}
Turbo.session.drive = false;

import('../shared/track/matomo');
import('../shared/track/sentry');
