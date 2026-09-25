import { afterEach, beforeEach, expect, suite, test, vi } from 'vitest';

import { errorFromDirectUploadMessage } from './file-upload-error';

const { uploaderStart } = vi.hoisted(() => ({ uploaderStart: vi.fn() }));

vi.mock('./uploader', () => ({
  default: class {
    directUpload = { id: 'test-id' };
    progressBar = {
      start: vi.fn(),
      end: vi.fn(),
      error: vi.fn(),
      destroy: vi.fn()
    };
    start() {
      return uploaderStart();
    }
  }
}));

// Imported after the mock so it picks up the fake Uploader.
const { AutoUpload } = await import('./auto-upload');

function setupDom() {
  document.body.innerHTML = `
    <div class="attachment-field">
      <input type="file" data-direct-upload-url="/rails/active_storage/direct_uploads" />
      <div id="direct-upload-test-id" class="direct-upload direct-upload--error">
        <button type="button" class="direct-upload__retry hidden"></button>
        <div class="direct-upload__error"></div>
      </div>
    </div>
  `;
  return document.querySelector<HTMLInputElement>('input')!;
}

// A connectivity failure: the kind that offers a retry button.
function storeError() {
  return errorFromDirectUploadMessage(
    'Error storing "attestation.pdf". Status: 0'
  );
}

suite('AutoUpload retry', () => {
  let input: HTMLInputElement;
  let rejections: PromiseRejectionEvent[];

  const collectRejection = (event: PromiseRejectionEvent) => {
    event.preventDefault();
    rejections.push(event);
  };

  beforeEach(() => {
    input = setupDom();
    rejections = [];
    uploaderStart.mockReset();
    window.addEventListener('unhandledrejection', collectRejection);
  });

  afterEach(() => {
    window.removeEventListener('unhandledrejection', collectRejection);
    document.body.innerHTML = '';
  });

  test('does not leak an unhandled rejection when the retried upload fails again', async () => {
    uploaderStart.mockRejectedValue(storeError());

    const autoUpload = new AutoUpload(
      input,
      new File(['x'], 'attestation.pdf')
    );
    await expect(autoUpload.start()).rejects.toThrowError(
      'Error storing file.'
    );

    const retryButton = document.querySelector<HTMLButtonElement>(
      '.direct-upload__retry'
    )!;
    expect(retryButton.classList.contains('hidden')).toBe(false);

    retryButton.click();

    await vi.waitFor(() => expect(uploaderStart).toHaveBeenCalledTimes(2));
    // Let the microtask checkpoint run: that is when the browser decides a
    // rejection is unhandled.
    await new Promise((resolve) => setTimeout(resolve, 100));

    expect(rejections).toEqual([]);
  });

  test('runs the given continuation again on retry', async () => {
    uploaderStart
      .mockRejectedValueOnce(storeError())
      .mockResolvedValueOnce('signed-id');
    const outcomes: (string | null)[] = [];

    const upload = (): Promise<unknown> =>
      autoUpload.start().then(
        (blobSignedId) => outcomes.push(blobSignedId),
        () => outcomes.push(null)
      );
    const autoUpload: InstanceType<typeof AutoUpload> = new AutoUpload(
      input,
      new File(['x'], 'attestation.pdf'),
      { retry: upload }
    );
    await upload();
    expect(outcomes).toEqual([null]);

    document.querySelector<HTMLButtonElement>('.direct-upload__retry')!.click();

    await vi.waitFor(() => expect(outcomes).toEqual([null, 'signed-id']));
  });
});
