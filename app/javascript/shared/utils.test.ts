import { suite, test, expect } from 'vite-plus/test';

import { show, hide, toggle, toggleExpandIcon } from './utils';

suite('@utils', () => {
  test('show', () => {
    const input = document.createElement('input');
    input.classList.add('hidden');

    show(input);
    expect(input.classList.contains('hidden')).toBeFalsy();
  });

  test('hide', () => {
    const input = document.createElement('input');

    hide(input);
    expect(input.classList.contains('hidden')).toBeTruthy();
  });

  test('toggle', () => {
    const input = document.createElement('input');

    toggle(input);
    expect(input.classList.contains('hidden')).toBeTruthy();
    toggle(input);
    expect(input.classList.contains('hidden')).toBeFalsy();
  });

  test('toggleExpandIcon', () => {
    const icon = document.createElement('icon');
    icon.classList.add('fr-icon-arrow-down-s-line');

    toggleExpandIcon(icon);
    expect(icon.classList.contains('fr-icon-arrow-up-s-line')).toBeTruthy();
    expect(icon.classList.contains('fr-icon-arrow-down-s-line')).toBeFalsy();
    toggleExpandIcon(icon);
    expect(icon.classList.contains('fr-icon-arrow-down-s-line')).toBeTruthy();
    expect(icon.classList.contains('fr-icon-arrow-up-s-line')).toBeFalsy();
  });
});
