import ProgressBar from './progress-bar';
import {
  errorFromDirectUploadMessage,
  ERROR_CODE_READ,
  FAILURE_CLIENT
} from './file-upload-error';
import { fire } from '@utils';

const INITIALIZE_EVENT = 'direct-upload:initialize';
const START_EVENT = 'direct-upload:start';
const PROGRESS_EVENT = 'direct-upload:progress';
const ERROR_EVENT = 'direct-upload:error';
const END_EVENT = 'direct-upload:end';

function addUploadEventListener(type, handler) {
  addEventListener(type, (event) => {
    // Internet Explorer and Edge will sometime replay Javascript events
    // that were dispatched just before a page navigation (!), but without
    // the event payload.
    //
    // Ignore these replayed events.
    const isEventValid = event && event.detail && event.detail.id != undefined;
    if (!isEventValid) return;

    handler(event);
  });
}

addUploadEventListener(INITIALIZE_EVENT, ({ target, detail: { id, file } }) => {
  ProgressBar.init(target, id, file);
});

addUploadEventListener(START_EVENT, ({ detail: { id } }) => {
  ProgressBar.start(id);
});

addUploadEventListener(PROGRESS_EVENT, ({ detail: { id, progress } }) => {
  ProgressBar.progress(id, progress);
});

addUploadEventListener(ERROR_EVENT, (event) => {
  let id = event.detail.id;
  let errorMsg = event.detail.error;

  // Display an error message
  alert(
    `Nous sommes désolés, une erreur s’est produite lors de l’envoi du fichier.

    (${errorMsg})`
  );
  // Prevent ActiveStorage from displaying its own error message
  event.preventDefault();

  ProgressBar.error(id, errorMsg);

  // Report unexpected client errors to Sentry.
  // (But ignore usual client errors, or errors we can monitor better on the server side.)
  let error = errorFromDirectUploadMessage(errorMsg);
  if (error.failureReason == FAILURE_CLIENT && error.code != ERROR_CODE_READ) {
    fire(document, 'sentry:capture-exception', error);
  }
});

addUploadEventListener(END_EVENT, ({ detail: { id } }) => {
  ProgressBar.end(id);
});
