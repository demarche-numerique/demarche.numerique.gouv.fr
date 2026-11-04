import { Application } from '@hotwired/stimulus';
import { afterEach, beforeEach, expect, suite, test } from 'vitest';

import { ExportTemplateKindController } from './export_template_kind_controller';

const nextFrame = () => new Promise(requestAnimationFrame);

suite('ExportTemplateKindController', () => {
  let application: Application;

  const notice = () => document.querySelector<HTMLElement>('#notice')!;

  const choose = async (kind: string) => {
    const input = document.querySelector<HTMLInputElement>(`#${kind}`)!;
    input.checked = true;
    input.dispatchEvent(new Event('change', { bubbles: true }));
    await nextFrame();
  };

  beforeEach(async () => {
    document.body.innerHTML = `
      <form data-controller="export-template-kind">
        <input type="radio" name="kind" id="xlsx" value="xlsx" checked data-export-template-kind-target="kind">
        <input type="radio" name="kind" id="csv" value="csv" data-export-template-kind-target="kind">
        <div id="notice" class="hidden" data-export-template-kind-target="csvOnly"></div>
      </form>
    `;
    application = Application.start();
    application.register('export-template-kind', ExportTemplateKindController);
    await nextFrame();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  test('shows the csv only elements when csv is chosen', async () => {
    await choose('csv');
    expect(notice().classList.contains('hidden')).toBe(false);
  });

  test('hides the csv only elements when another kind is chosen', async () => {
    await choose('csv');
    await choose('xlsx');
    expect(notice().classList.contains('hidden')).toBe(true);
  });

  test('shows the csv only elements when csv is already chosen on connect', async () => {
    const form = document.querySelector('form')!;
    form.removeAttribute('data-controller');
    await nextFrame();
    document.querySelector<HTMLInputElement>('#csv')!.checked = true;
    form.setAttribute('data-controller', 'export-template-kind');
    await nextFrame();

    expect(notice().classList.contains('hidden')).toBe(false);
  });
});
