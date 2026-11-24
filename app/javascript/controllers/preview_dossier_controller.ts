import { ApplicationController } from './application_controller';

// Points the previews at the dossier chosen in the picker: `url` targets get it as a
// `dossier_id` query param (in `src`, `href` or `data-preview-dossier-attribute`),
// `input` targets as their value, so that the form they belong to submits it.
export class PreviewDossierController extends ApplicationController {
  static targets = ['url', 'input'];

  declare readonly urlTargets: HTMLElement[];
  declare readonly inputTargets: HTMLInputElement[];

  select(event: Event) {
    const { value } = event.target as HTMLInputElement;

    this.urlTargets.forEach((element) => {
      const attribute = urlAttribute(element);
      const url = element.getAttribute(attribute);
      if (url) {
        element.setAttribute(attribute, withDossier(url, value));
      }
    });

    this.inputTargets.forEach((input) => {
      input.value = value;
      input.dispatchEvent(new Event('change', { bubbles: true }));
    });
  }
}

function urlAttribute(element: HTMLElement) {
  if (element.dataset.previewDossierAttribute) {
    return element.dataset.previewDossierAttribute;
  }
  return element instanceof HTMLAnchorElement ? 'href' : 'src';
}

function withDossier(url: string, dossierId: string) {
  const withParam = new URL(url, window.location.href);
  withParam.searchParams.set('dossier_id', dossierId);
  return withParam.toString();
}
