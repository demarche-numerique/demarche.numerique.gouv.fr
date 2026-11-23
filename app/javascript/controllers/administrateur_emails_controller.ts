import { ApplicationController } from './application_controller';

// Same as AdministrateurCreationRequest::EMAIL_REGEXP, which has the last word.
const EMAIL_REGEXP = /[^\s<>,;:"'()[\]]+@[^\s<>,;:"'()[\]]+/g;
const MIN_ROWS = 10;

function parseEmails(text: string): string[] {
  const emails = (text.match(EMAIL_REGEXP) ?? []).map((email) =>
    email.toLowerCase().replace(/\.$/, '')
  );
  return [...new Set(emails)];
}

function domainsSummary(emails: string[]): string {
  const counts = new Map<string, number>();
  for (const email of emails) {
    const domain = email.split('@')[1];
    counts.set(domain, (counts.get(domain) ?? 0) + 1);
  }
  return [...counts]
    .sort((a, b) => b[1] - a[1])
    .map(([domain, count]) => `${domain} · ${count}`)
    .join(', ');
}

export class AdministrateurEmailsController extends ApplicationController {
  static targets = [
    'input',
    'summary',
    'count',
    'domains',
    'list',
    'validationNotice',
    'tooMany',
    'otp',
    'submit'
  ];
  static values = {
    max: Number,
    maxWithoutValidation: Number,
    labels: Object
  };

  declare readonly inputTarget: HTMLTextAreaElement;
  declare readonly summaryTarget: HTMLElement;
  declare readonly countTarget: HTMLElement;
  declare readonly domainsTarget: HTMLElement;
  declare readonly listTarget: HTMLElement;
  declare readonly validationNoticeTarget: HTMLElement;
  declare readonly tooManyTarget: HTMLElement;
  declare readonly otpTarget: HTMLElement;
  declare readonly submitTarget: HTMLButtonElement;
  declare readonly maxValue: number;
  declare readonly maxWithoutValidationValue: number;
  declare readonly labelsValue: Record<'one' | 'many' | 'validation', string>;

  connect() {
    this.update();
  }

  update(event?: Event) {
    const emails = parseEmails(this.inputTarget.value);
    if (event instanceof InputEvent && event.inputType == 'insertFromPaste') {
      this.inputTarget.value = emails.join('\n');
    }

    const count = emails.length;
    const multiple = count > 1;
    const tooMany = count > this.maxValue;
    const needsValidation = count > this.maxWithoutValidationValue;

    this.inputTarget.rows = Math.max(
      MIN_ROWS,
      this.inputTarget.value.split('\n').length + 1
    );

    this.summaryTarget.hidden = !multiple;
    this.countTarget.textContent = String(count);
    this.domainsTarget.textContent = domainsSummary(emails);
    this.listTarget.replaceChildren(
      ...emails.map((email) => {
        const item = document.createElement('li');
        item.textContent = email;
        return item;
      })
    );

    this.validationNoticeTarget.hidden = !needsValidation || tooMany;
    this.tooManyTarget.hidden = !tooMany;

    this.otpTarget.hidden = !multiple;
    this.otpTarget
      .querySelectorAll('input')
      .forEach((input) => (input.disabled = !multiple));

    const label = needsValidation
      ? this.labelsValue.validation
      : multiple
        ? this.labelsValue.many
        : this.labelsValue.one;
    this.submitTarget.textContent = label.replace('%{count}', String(count));
    this.submitTarget.disabled = tooMany;
  }
}
