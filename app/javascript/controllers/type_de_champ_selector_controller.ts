import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = [
    'trigger',
    'panel',
    'searchInput',
    'clearButton',
    'option',
    'category',
    'hiddenInput'
  ];
  static values = { disabled: Boolean };

  declare triggerTarget: HTMLButtonElement;
  declare panelTarget: HTMLDivElement;
  declare searchInputTarget: HTMLInputElement;
  declare clearButtonTarget: HTMLButtonElement;
  declare optionTargets: HTMLDivElement[];
  declare categoryTargets: HTMLDivElement[];
  declare hiddenInputTarget: HTMLSelectElement;
  declare disabledValue: boolean;

  private focusedIndex = -1;
  private boundCloseOnClickOutside = this.closeOnClickOutside.bind(this);
  private escapeDiv = document.createElement('div');

  disconnect() {
    document.removeEventListener('click', this.boundCloseOnClickOutside);
  }

  toggle() {
    if (this.disabledValue) return;

    const isOpen = this.panelTarget.classList.contains('fr-hidden');
    if (isOpen) {
      this.open();
    } else {
      this.closePanel();
    }
  }

  search() {
    const query = this.normalizeText(this.searchInputTarget.value);
    const hasQuery = query.length > 0;

    this.clearButtonTarget.classList.toggle('fr-hidden', !hasQuery);

    this.optionTargets.forEach((option) => {
      const label = this.normalizeText(option.dataset.label || '');
      const categoryLabel = this.normalizeText(
        option.dataset.categoryLabel || ''
      );
      const matches = label.includes(query) || categoryLabel.includes(query);
      option.classList.toggle('fr-hidden', !matches);

      const labelEl = option.querySelector(
        '.type-de-champ-selector-option-label'
      );
      if (labelEl) {
        const originalLabel = option.dataset.label || '';
        if (hasQuery && matches) {
          labelEl.innerHTML = this.highlightMatch(
            originalLabel,
            this.searchInputTarget.value
          );
        } else {
          labelEl.textContent = originalLabel;
        }
      }
    });

    this.categoryTargets.forEach((category) => {
      const visibleOptions = category.querySelectorAll(
        '[data-type-de-champ-selector-target="option"]:not(.fr-hidden)'
      );
      category.classList.toggle('fr-hidden', visibleOptions.length === 0);
    });

    this.focusedIndex = -1;
    this.updateActiveDescendant();
  }

  clear() {
    this.searchInputTarget.value = '';
    this.search();
    this.searchInputTarget.focus();
  }

  select(event: Event) {
    const option = event.currentTarget as HTMLDivElement;
    if (option.getAttribute('aria-disabled') === 'true') return;

    const value = option.dataset.value || '';
    const label = option.dataset.label || '';
    const icon = option.dataset.icon || '';

    const selectEl = this.hiddenInputTarget;
    const existingOption = selectEl.querySelector('option');
    if (existingOption) {
      existingOption.value = value;
      existingOption.textContent = label;
    }
    selectEl.value = value;
    selectEl.dispatchEvent(new Event('change', { bubbles: true }));

    const triggerIcon = this.triggerTarget.querySelector(
      '[aria-hidden="true"]'
    );
    const triggerLabel = this.triggerTarget.querySelector(
      '.type-de-champ-selector-trigger-label'
    );
    if (triggerIcon) triggerIcon.className = `${icon} fr-icon--sm`;
    if (triggerLabel) triggerLabel.textContent = label;

    this.optionTargets.forEach((opt) => {
      const isSelected = opt.dataset.value === value;
      opt.classList.toggle('selected', isSelected);
      opt.setAttribute('aria-selected', isSelected.toString());
    });

    this.closePanel();
  }

  close(event: KeyboardEvent) {
    event.preventDefault();
    this.closePanel();
  }

  navigateUp(event: KeyboardEvent) {
    event.preventDefault();
    this.navigate(-1);
  }

  navigateDown(event: KeyboardEvent) {
    event.preventDefault();
    this.navigate(1);
  }

  selectFocused(event: KeyboardEvent) {
    event.preventDefault();
    const enabledOptions = this.getEnabledVisibleOptions();
    if (this.focusedIndex >= 0 && this.focusedIndex < enabledOptions.length) {
      enabledOptions[this.focusedIndex].click();
    }
  }

  private open() {
    this.panelTarget.classList.remove('fr-hidden');
    this.triggerTarget.setAttribute('aria-expanded', 'true');
    this.searchInputTarget.value = '';
    this.search();
    this.searchInputTarget.focus();
    this.focusedIndex = -1;
    this.updateActiveDescendant();
    document.addEventListener('click', this.boundCloseOnClickOutside);
  }

  private closePanel() {
    this.panelTarget.classList.add('fr-hidden');
    this.triggerTarget.setAttribute('aria-expanded', 'false');
    this.focusedIndex = -1;
    this.updateActiveDescendant();
    document.removeEventListener('click', this.boundCloseOnClickOutside);
  }

  private closeOnClickOutside(event: Event) {
    if (!this.element.contains(event.target as Node)) {
      this.closePanel();
    }
  }

  private navigate(direction: number) {
    const enabledOptions = this.getEnabledVisibleOptions();
    if (enabledOptions.length === 0) return;

    enabledOptions.forEach((opt) => opt.classList.remove('focused'));

    this.focusedIndex += direction;
    if (this.focusedIndex < 0) this.focusedIndex = enabledOptions.length - 1;
    if (this.focusedIndex >= enabledOptions.length) this.focusedIndex = 0;

    const focused = enabledOptions[this.focusedIndex];
    focused.classList.add('focused');
    focused.scrollIntoView({ block: 'nearest' });
    this.updateActiveDescendant();
  }

  private updateActiveDescendant() {
    const enabledOptions = this.getEnabledVisibleOptions();
    const focusedOption =
      this.focusedIndex >= 0 ? enabledOptions[this.focusedIndex] : null;
    if (focusedOption?.id) {
      this.panelTarget.setAttribute('aria-activedescendant', focusedOption.id);
    } else {
      this.panelTarget.removeAttribute('aria-activedescendant');
    }
  }

  private getEnabledVisibleOptions(): HTMLDivElement[] {
    return this.optionTargets.filter(
      (opt) =>
        !opt.classList.contains('fr-hidden') &&
        opt.getAttribute('aria-disabled') !== 'true'
    );
  }

  private normalizeText(text: string): string {
    return text
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase();
  }

  private highlightMatch(text: string, query: string): string {
    const normalizedQuery = this.normalizeText(query);
    const positionMap = this.buildPositionMap(text);
    const normalizedText = this.normalizeText(text);
    const index = normalizedText.indexOf(normalizedQuery);
    if (index === -1) return this.escapeHtml(text);

    const startOrig = positionMap[index];
    const endOrig =
      index + normalizedQuery.length < positionMap.length
        ? positionMap[index + normalizedQuery.length]
        : text.length;

    const before = text.slice(0, startOrig);
    const match = text.slice(startOrig, endOrig);
    const after = text.slice(endOrig);
    return `${this.escapeHtml(before)}<mark>${this.escapeHtml(match)}</mark>${this.escapeHtml(after)}`;
  }

  private buildPositionMap(text: string): number[] {
    const map: number[] = [];
    for (let i = 0; i < text.length; i++) {
      const nfdChars = text[i].normalize('NFD');
      for (let j = 0; j < nfdChars.length; j++) {
        if (!/[\u0300-\u036f]/.test(nfdChars[j])) {
          map.push(i);
        }
      }
    }
    return map;
  }

  private escapeHtml(text: string): string {
    this.escapeDiv.textContent = text;
    return this.escapeDiv.innerHTML;
  }
}
