import { toggle } from '@utils';
import { ApplicationController } from './application_controller';

export class AttestationController extends ApplicationController {
  static targets = [
    'layoutToggle',
    'logoMarianneLabelFieldset',
    'logoAttachmentFieldset',
    'preview',
    'previewLink'
  ];
  static values = {
    logoAttachmentOfficialLabel: String,
    logoAttachmentFreeLabel: String
  };

  declare readonly layoutToggleTarget: HTMLInputElement;
  declare readonly logoMarianneLabelFieldsetTarget: HTMLElement;
  declare readonly logoAttachmentFieldsetTarget: HTMLElement;
  declare readonly previewTarget: HTMLIFrameElement;
  declare readonly previewLinkTarget: HTMLAnchorElement;

  declare readonly logoAttachmentOfficialLabelValue: string;
  declare readonly logoAttachmentFreeLabelValue: string;

  connect() {
    this.layoutToggleTarget.addEventListener('change', () => {
      this.update();
    });

    this.on('turbo:submit-end', () => {
      // oxlint-disable-next-line no-self-assign
      this.previewTarget.src = this.previewTarget.src; // reload the iframe
    });
  }

  previewDossier(event: Event) {
    const { value } = event.target as HTMLInputElement;
    this.previewTarget.src = withDossier(this.previewTarget.src, value);
    this.previewLinkTarget.href = withDossier(
      this.previewLinkTarget.href,
      value
    );
  }

  private get isStateLayout() {
    return this.layoutToggleTarget.checked;
  }

  private update() {
    toggle(this.logoMarianneLabelFieldsetTarget, this.isStateLayout);

    const logoAttachmentLabel =
      this.logoAttachmentFieldsetTarget.querySelector('label');

    if (logoAttachmentLabel) {
      logoAttachmentLabel.innerText = this.isStateLayout
        ? this.logoAttachmentOfficialLabelValue
        : this.logoAttachmentFreeLabelValue;
    }
  }
}

function withDossier(url: string, dossierId: string) {
  const withParam = new URL(url);
  withParam.searchParams.set('dossier_id', dossierId);
  return withParam.toString();
}
