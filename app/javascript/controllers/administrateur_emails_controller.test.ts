import { Application } from '@hotwired/stimulus';
import { afterEach, beforeEach, expect, suite, test } from 'vitest';

import { AdministrateurEmailsController } from './administrateur_emails_controller';

const nextFrame = () => new Promise(requestAnimationFrame);

suite('AdministrateurEmailsController', () => {
  let application: Application;

  const textarea = () => document.querySelector('textarea')!;
  const paste = async (text: string) => {
    textarea().value = text;
    textarea().dispatchEvent(
      new InputEvent('input', { bubbles: true, inputType: 'insertFromPaste' })
    );
    await nextFrame();
  };

  beforeEach(async () => {
    application = Application.start();
    application.register(
      'administrateur-emails',
      AdministrateurEmailsController
    );

    document.body.innerHTML = `
      <form
        data-controller="administrateur-emails"
        data-administrateur-emails-max-value="3"
        data-administrateur-emails-max-without-validation-value="2"
        data-administrateur-emails-labels-value='{"one":"Create","many":"Create %{count}","validation":"Request %{count}"}'
      >
        <textarea data-administrateur-emails-target="input" data-action="administrateur-emails#update"></textarea>
        <div data-administrateur-emails-target="summary">
          <span data-administrateur-emails-target="count"></span>
          <span data-administrateur-emails-target="domains"></span>
          <ul data-administrateur-emails-target="list"></ul>
        </div>
        <p data-administrateur-emails-target="validationNotice"></p>
        <p data-administrateur-emails-target="tooMany"></p>
        <div data-administrateur-emails-target="otp"><input required></div>
        <button data-administrateur-emails-target="submit"></button>
      </form>
    `;
    await nextFrame();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  test('extracts lowercase unique addresses from any pasted format', async () => {
    await paste(
      'Camille <Camille@Numerique.gouv.fr>, louis@culture.gouv.fr;\tmailto:sarah@ars.sante.fr\ncamille@numerique.gouv.fr'
    );

    expect(textarea().value).toBe(
      'camille@numerique.gouv.fr\nlouis@culture.gouv.fr\nsarah@ars.sante.fr'
    );
  });

  test('cleans up a paste and never renders its markup', async () => {
    await paste(
      '<img src=x onerror="window.pwned=1"><script>window.pwned=1</script><b>A@x.fr</b> b@y.fr'
    );

    expect(textarea().value).toBe('a@x.fr\nb@y.fr');
    expect(document.querySelector('ul')!.innerHTML).toBe(
      '<li>a@x.fr</li><li>b@y.fr</li>'
    );
    expect(document.querySelector('form img, form script, form b')).toBeNull();
    expect('pwned' in window).toBe(false);
    expect(document.querySelector('button')!.textContent).toBe('Create 2');
  });

  test('requires the OTP from 2 addresses', async () => {
    await paste('a@x.fr');
    expect(document.querySelector<HTMLInputElement>('input')!.disabled).toBe(
      true
    );

    await paste('a@x.fr b@x.fr');
    expect(document.querySelector<HTMLInputElement>('input')!.disabled).toBe(
      false
    );
  });

  test('asks for approval above the threshold and refuses above the maximum', async () => {
    await paste('a@x.fr b@x.fr c@x.fr');
    expect(document.querySelector('button')!.textContent).toBe('Request 3');
    expect(
      document.querySelector<HTMLElement>(
        '[data-administrateur-emails-target="validationNotice"]'
      )!.hidden
    ).toBe(false);

    await paste('a@x.fr b@x.fr c@x.fr d@x.fr');
    expect(document.querySelector('button')!.disabled).toBe(true);
    expect(
      document.querySelector<HTMLElement>(
        '[data-administrateur-emails-target="tooMany"]'
      )!.hidden
    ).toBe(false);
  });
});
