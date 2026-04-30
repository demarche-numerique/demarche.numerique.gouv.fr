import { disable, enable, hide, show } from 'coldwired/actions';
import { isInputElement } from 'coldwired/utils';

export function showMotivation(event: Event, state: string) {
  event.preventDefault();
  motivationCancel();
  const stateElement = document.querySelector(`.motivation.${state}`);

  if (stateElement) {
    show(stateElement.parentElement);
    show(stateElement);
    stateElement.querySelectorAll('input, textarea').forEach(enable);
  }
}

export function motivationCancel() {
  document.querySelectorAll('.motivation').forEach((stateElement) => {
    hide(stateElement);
    hide(stateElement.parentElement);
    stateElement.querySelectorAll('input, textarea').forEach(disable);
  });

  hide('.js_delete_motivation');
}

export function showDeleteJustificatif(name: string) {
  const justificatif = document.querySelector(
    `#dossier_justificatif_motivation_${name}`
  );

  if (isInputElement(justificatif)) {
    if (justificatif.value != '') {
      show(`#delete_motivation_import_${name}`);
    }
  }
}

export function deleteJustificatif(name: string) {
  const justificatif = document.querySelector(
    `#dossier_justificatif_motivation_${name}`
  );
  if (isInputElement(justificatif)) {
    justificatif.value = '';
    hide(`#delete_motivation_import_${name}`);
  }
}

export function showImportJustificatif(name: string) {
  show(`#justificatif_motivation_import_${name}`);
  hide(`#justificatif_motivation_suggest_${name}`);
}
