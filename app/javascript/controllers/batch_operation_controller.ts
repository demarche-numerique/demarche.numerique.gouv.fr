import { ApplicationController } from './application_controller';
import { disable, enable, show, hide } from '@utils';
import invariant from 'tiny-invariant';

export class BatchOperationController extends ApplicationController {
  static values = { limit: Number };
  declare readonly limitValue: number;

  static targets = [
    'menu',
    'input',
    'dropdown',
    'checkboxCount',
    'avisForm',
    'archiveForm',
    'commentaireForm',
    'commentaireTitleSingular',
    'commentaireTitlePlural',
    'commentaireWarning',
    'commentaireFormContainer'
  ];

  declare readonly menuTargets: HTMLButtonElement[];
  declare readonly inputTargets: HTMLInputElement[];
  declare readonly dropdownTargets: HTMLButtonElement[];
  declare readonly checkboxCountTarget: HTMLElement;
  declare readonly avisFormTarget: HTMLFormElement;
  declare readonly archiveFormTarget: HTMLFormElement;
  declare readonly commentaireFormTarget: HTMLFormElement;
  declare readonly commentaireTitleSingularTarget: HTMLElement;
  declare readonly commentaireTitlePluralTarget: HTMLElement;
  declare readonly commentaireWarningTarget: HTMLElement;
  declare readonly commentaireFormContainerTarget: HTMLElement;

  onCheckOne() {
    this.toggleSubmitButtonWhenNeeded();
    this.updateCheckboxCount();
    deleteSelection();
  }

  onCheckAll(event: Event) {
    const target = event.target as HTMLInputElement;

    this.inputTargets.forEach((e) => {
      e.checked = target.checked;
      e.dispatchEvent(new Event('change')); // dispatch change for dsfr checkbox behavior
    });

    this.toggleSubmitButtonWhenNeeded();
    this.updateCheckboxCount();

    const pagination = document.querySelector(
      '.fr-table__footer .fr-pagination'
    );
    if (pagination) {
      displayNotice(this.inputTargets);
    }

    // add focus on button for a11y
    const button = document.getElementById('js_select_more');
    if (button) {
      button.focus();
    }
  }

  onSelectMore(event: {
    preventDefault: () => void;
    target: HTMLInputElement;
  }) {
    event.preventDefault();

    const target = event.target as HTMLInputElement;
    const dossierIds = target.getAttribute('data-dossiers');

    const hidden_input_multiple_ids = document.querySelector<HTMLInputElement>(
      '#input_multiple_ids_batch_operation'
    );
    if (hidden_input_multiple_ids) {
      hidden_input_multiple_ids.value = dossierIds || '';
    }

    hide(document.querySelector('#not_selected'));
    show(document.querySelector('#selected'));

    // add focus on button for a11y
    const button = document.getElementById('js_delete_selection');
    if (button) {
      button.focus();
    }

    this.updateCheckboxCount();
  }

  onDeleteSelection(event: { preventDefault: () => void }) {
    event.preventDefault();
    emptyCheckboxes();
    deleteSelection();
    this.toggleSubmitButtonWhenNeeded();
    this.updateCheckboxCount();
  }

  toggleSubmitButtonWhenNeeded() {
    const buttons = [
      ...this.element.querySelectorAll<HTMLButtonElement>('[data-operation]')
    ];
    const checked = this.inputTargets.filter((input) => input.checked);
    if (checked.length) {
      const available = buttons.filter((button) => {
        const operation = button.dataset.operation;
        invariant(operation, 'data-operation is required');
        const available = checked.every(isInputForOperation(operation));
        switchButton(button, available);
        return available;
      });

      if (this.menuTargets.length) {
        if (available.length) {
          this.menuTargets.forEach((e) => enable(e));
        } else {
          this.menuTargets.forEach((e) => disable(e));
        }
      }

      this.dropdownTargets.forEach((dropdown) => {
        const buttons = Array.from(
          document.querySelectorAll<HTMLButtonElement>(
            `[aria-labelledby='${dropdown.id}'] button[data-operation]`
          )
        );

        const disabled = buttons.every((button) => button.disabled);

        if (disabled) {
          disable(dropdown);
        } else {
          enable(dropdown);
        }
      });

      // pour chaque chaque dropdown, on va chercher tous les boutons
      // si tous les boutons sont disabled, on disable le dropdown
    } else {
      this.menuTargets.forEach((e) => disable(e));
      buttons.forEach((button) => switchButton(button, false));

      this.dropdownTargets.forEach((e) => disable(e));
    }
  }

  updateCheckboxCount() {
    if (!this.checkboxCountTarget) return;

    // Use hidden input value if present
    const hiddenInput = document.querySelector<HTMLInputElement>(
      '#input_multiple_ids_batch_operation'
    );

    const count =
      hiddenInput && hiddenInput.value.trim() !== ''
        ? hiddenInput.value.split(',').filter((id) => id.trim() !== '').length
        : // fallback to visible checked checkboxes
          this.inputTargets.filter((input) => input.checked).length;

    const label = `${count} dossier${count > 1 ? 's' : ''} sélectionné${count > 1 ? 's' : ''}`;
    this.checkboxCountTarget.textContent = label;

    const classList = this.checkboxCountTarget.classList;
    if (count > 0) {
      classList.add('text-high-blue', 'fr-text--bold');
    } else {
      classList.remove('text-high-blue', 'fr-text--bold');
    }
  }

  injectSelectedIdsIntoModal(event: Event) {
    event.preventDefault();

    const trigger = event.currentTarget as HTMLElement | null;
    const modalType = trigger?.dataset?.modalType;
    const modalForm = this.modalFormFor(modalType);

    if (!modalForm) return;

    const ids = this.getSelectedIds();
    if (modalType === 'archive') {
      modalForm.reset();
    }
    this.clearPreviousInputs(modalForm);
    this.injectHiddenInputs(modalForm, ids);
    if (modalType === 'commentaire') {
      this.updateCommentaireModal(ids);
    }
    if (modalType === 'avis') {
      this.setDefaultConfidentialOption();
    }
  }

  dispatchSelectedIds(event: Event) {
    event.preventDefault();
    this.dispatch('selection', {
      detail: { ids: this.getSelectedIds() },
      target: window
    });
  }

  private modalFormFor(modalType?: string): HTMLFormElement {
    switch (modalType) {
      case 'avis':
        return this.avisFormTarget;
      case 'archive':
        return this.archiveFormTarget;
      default:
        return this.commentaireFormTarget;
    }
  }

  private getSelectedIds(): string[] {
    const hiddenInput = document.querySelector<HTMLInputElement>(
      '#input_multiple_ids_batch_operation'
    );

    if (hiddenInput && hiddenInput.value.trim() !== '') {
      // Cas 1 : sélection étendue (select all + select more)
      return hiddenInput.value
        .split(',')
        .map((id) => id.trim())
        .filter(Boolean);
    } else {
      // Cas 2 : sélection visible via les checkboxes
      const checkedInputs = document.querySelectorAll<HTMLInputElement>(
        'input[name="batch_operation[dossier_ids][]"]:checked:not(:disabled)'
      );
      return Array.from(checkedInputs).map((input) => input.value);
    }
  }

  private clearPreviousInputs(modalForm: HTMLFormElement): void {
    modalForm
      .querySelectorAll('input[name="batch_operation[dossier_ids][]"]')
      .forEach((el) => el.remove());
  }

  private injectHiddenInputs(modalForm: HTMLFormElement, ids: string[]): void {
    ids.forEach((id) => {
      const input = document.createElement('input');
      input.type = 'hidden';
      input.name = 'batch_operation[dossier_ids][]';
      input.value = id;
      modalForm.appendChild(input);
    });
  }

  private updateCommentaireModal(ids: string[]): void {
    const dossiersCount = ids.length;

    // Mettre à jour le titre avec les traductions pré-rendues
    if (dossiersCount === 1) {
      this.commentaireTitleSingularTarget.classList.remove('hidden');
      this.commentaireTitlePluralTarget.classList.add('hidden');
    } else {
      this.commentaireTitleSingularTarget.classList.add('hidden');
      this.commentaireTitlePluralTarget.classList.remove('hidden');
      // Remplacer __COUNT__ par le nombre réel
      this.commentaireTitlePluralTarget.textContent =
        this.commentaireTitlePluralTarget.textContent?.replace(
          '__COUNT__',
          dossiersCount.toString()
        ) || '';
    }

    // Gérer la limite
    if (this.commentaireWarningTarget && this.commentaireFormContainerTarget) {
      if (dossiersCount > this.limitValue) {
        this.commentaireWarningTarget.classList.remove('hidden');
        this.commentaireFormContainerTarget.classList.add('hidden');
      } else {
        this.commentaireWarningTarget.classList.add('hidden');
        this.commentaireFormContainerTarget.classList.remove('hidden');
      }
    }
  }

  private setDefaultConfidentialOption(): void {
    const confidentialRadio = document.querySelector<HTMLInputElement>(
      '#confidentiel_false'
    );
    if (confidentialRadio) {
      confidentialRadio.checked = true;
    }
  }
}

function isInputForOperation(operation: string) {
  return (input: HTMLInputElement) =>
    (input.dataset.operations?.split(',') ?? []).includes(operation);
}

function switchButton(button: HTMLButtonElement, flag: boolean) {
  if (flag) {
    enable(button);
    button.querySelectorAll('button').forEach((button) => enable(button));
  } else {
    disable(button);
    button.querySelectorAll('button').forEach((button) => disable(button));
  }
}

function displayNotice(inputs: HTMLInputElement[]) {
  const checkbox_all = document.querySelector<HTMLInputElement>(
    '#checkbox_all_batch_operation'
  );
  if (checkbox_all) {
    if (checkbox_all.checked) {
      show(document.querySelector('#js_batch_select_more'));
      hide(document.querySelector('#selected'));
      show(document.querySelector('#not_selected'));
    } else {
      hide(document.querySelector('#js_batch_select_more'));
      deleteSelection();
    }
  }

  const dynamic_number = document.querySelector('#dynamic_number');

  if (dynamic_number) {
    dynamic_number.textContent = inputs.length.toString();
  }
}

function deleteSelection() {
  const hidden_input_multiple_ids = document.querySelector<HTMLInputElement>(
    '#input_multiple_ids_batch_operation'
  );

  if (hidden_input_multiple_ids) {
    hidden_input_multiple_ids.value = '';
  }

  hide(document.querySelector('#js_batch_select_more'));
}

function emptyCheckboxes() {
  const inputs = document.querySelectorAll<HTMLInputElement>(
    'div[data-controller="batch-operation"] input[type=checkbox]'
  );
  inputs.forEach((e) => (e.checked = false));
}
