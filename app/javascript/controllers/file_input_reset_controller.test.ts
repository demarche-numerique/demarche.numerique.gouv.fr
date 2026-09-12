import { Application } from '@hotwired/stimulus';
import { afterEach, beforeEach, expect, suite, test } from 'vitest';

import { FileInputResetController } from './file_input_reset_controller';

const nextFrame = () => new Promise(requestAnimationFrame);

const MAX_FILE_SIZE = 1024 * 1024;

suite('FileInputResetController', () => {
  let application: Application;
  let element: HTMLElement;

  const input = () =>
    element.querySelector('input[type="file"]') as HTMLInputElement;

  const rows = () => Array.from(element.querySelectorAll('li'));

  const select = async (files: File[]) => {
    const dataTransfer = new DataTransfer();
    files.forEach((file) => dataTransfer.items.add(file));
    input().files = dataTransfer.files;
    input().dispatchEvent(new Event('change', { bubbles: true }));
    await nextFrame();
  };

  const file = (name: string, size: number) =>
    new File(['x'.repeat(size)], name, { type: 'application/pdf' });

  beforeEach(async () => {
    application = Application.start();
    application.register('file-input-reset', FileInputResetController);
    element = document.createElement('div');
    element.setAttribute('data-controller', 'file-input-reset');
    element.setAttribute('data-delete-label', 'Supprimer le fichier');
    element.innerHTML = `
      <input type="file" multiple data-max-file-size="${MAX_FILE_SIZE}">
      <ul data-file-input-reset-target="fileList"></ul>
    `;
    document.body.appendChild(element);
    await nextFrame();
  });

  afterEach(() => {
    element.remove();
    application.stop();
  });

  test('lists selected files without error when they fit', async () => {
    await select([file('ok.pdf', 512)]);

    expect(rows().length).toEqual(1);
    expect(rows()[0].textContent).toContain('ok.pdf');
    expect(element.querySelector('.fr-error-text')).toBeNull();
  });

  test('shows the size error inside the row of an oversized file', async () => {
    await select([file('trop-lourd.pdf', MAX_FILE_SIZE + 1)]);

    const error = rows()[0].querySelector('.fr-error-text');
    expect(error).not.toBeNull();
    expect(error?.textContent).toEqual(
      'La taille maximale du fichier autorisée est de\u00a01 Mo.'
    );
    expect(error?.querySelector('strong')?.textContent).toEqual('1 Mo');
    expect(error?.getAttribute('role')).toEqual('alert');
  });

  test('attaches the error to the oversized file only', async () => {
    await select([
      file('ok-1.pdf', 512),
      file('trop-lourd.pdf', MAX_FILE_SIZE + 1),
      file('ok-2.pdf', 512)
    ]);

    expect(rows().map((row) => !!row.querySelector('.fr-error-text'))).toEqual([
      false,
      true,
      false
    ]);
  });

  test('drops the error along with the file it belongs to', async () => {
    await select([
      file('ok.pdf', 512),
      file('trop-lourd.pdf', MAX_FILE_SIZE + 1)
    ]);

    (element.querySelector('#delete-button-1') as HTMLButtonElement).click();
    await nextFrame();

    expect(rows().length).toEqual(1);
    expect(element.querySelector('.fr-error-text')).toBeNull();
  });

  test('does not flag anything when no max size is declared', async () => {
    input().removeAttribute('data-max-file-size');

    await select([file('gros.pdf', MAX_FILE_SIZE + 1)]);

    expect(element.querySelector('.fr-error-text')).toBeNull();
  });
});
