import { afterEach, beforeEach, expect, suite, test, vi } from 'vitest';

vi.mock('./progress-bar', () => ({
  default: class {
    start = vi.fn();
    error = vi.fn();
  }
}));

vi.mock('@rails/activestorage', () => ({
  DirectUpload: class {
    id = 1;
    delegate: {
      directUploadWillCreateBlobWithXHR(xhr: EventTarget): void;
      directUploadWillStoreFileWithXHR(xhr: { upload: EventTarget }): void;
    };

    constructor(_file: File, _url: string, delegate: typeof this.delegate) {
      this.delegate = delegate;
    }

    create(callback: (error: string) => void) {
      const blobXhr = Object.assign(new EventTarget(), {
        readyState: XMLHttpRequest.DONE,
        response: {
          direct_upload: { url: 'https://storage.example/bucket/key' }
        }
      });
      this.delegate.directUploadWillCreateBlobWithXHR(blobXhr);
      blobXhr.dispatchEvent(new Event('readystatechange'));
      this.delegate.directUploadWillStoreFileWithXHR({
        upload: new EventTarget()
      });

      callback('Error storing "attestation.pdf". Status: 0');
    }
  }
}));

const { default: Uploader } = await import('./uploader');

suite('Uploader, when storing the file fails with status 0', () => {
  let reported: { message: string }[];
  const collect = (event: Event) =>
    reported.push((event as CustomEvent).detail);

  beforeEach(() => {
    reported = [];
    document.addEventListener('sentry:capture-message', collect);
  });

  afterEach(() => {
    document.removeEventListener('sentry:capture-message', collect);
    vi.restoreAllMocks();
  });

  function failUpload() {
    const uploader = new Uploader(
      document.createElement('input'),
      new File(['x'], 'attestation.pdf'),
      '/rails/active_storage/direct_uploads'
    );
    return expect(uploader.start()).rejects.toThrowError('Error storing file.');
  }

  test('reports a storage the browser reaches but cannot read', async () => {
    const probe = vi.spyOn(window, 'fetch').mockResolvedValue(new Response());

    await failUpload();

    await vi.waitFor(() =>
      expect(reported).toEqual([{ message: 'Direct upload blocked by CORS' }])
    );
    expect(probe).toHaveBeenCalledWith('https://storage.example', {
      mode: 'no-cors',
      cache: 'no-store'
    });
  });

  test('does not report a storage the browser cannot reach', async () => {
    const probe = vi
      .spyOn(window, 'fetch')
      .mockRejectedValue(new TypeError('Failed to fetch'));

    await failUpload();

    await vi.waitFor(() => expect(probe).toHaveBeenCalled());
    await new Promise((resolve) => setTimeout(resolve));
    expect(reported).toEqual([]);
  });
});
