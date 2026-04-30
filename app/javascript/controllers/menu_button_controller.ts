import { ApplicationController } from './application_controller';

export class MenuButtonController extends ApplicationController {
  static targets = ['button', 'menu'];

  declare readonly buttonTarget: HTMLButtonElement;
  declare readonly menuTarget: HTMLElement;

  connect() {
    this.setup();
  }

  private get isOpen() {
    return (this.element as HTMLElement).classList.contains('open');
  }

  private get isMenu() {
    return this.menuTarget.getAttribute('role') == 'menu';
  }

  private setup() {
    // see:
    // To progressively enhance this navigation widget that is by default accessible,
    // the class to hide the menu and the inclusion of tabindex="-1" on the interactive menuitem
    // content should be added with JavaScript on load.
    this.menuTarget.classList.add('fade-in-down');
    if (this.isMenu) {
      this.menuItems.map((menuItem) => menuItem.setAttribute('tabindex', '-1'));
    }

    this.on('click', (event) => {
      const target = event.target as HTMLElement;
      if (this.buttonTarget == target || this.buttonTarget.contains(target)) {
        event.preventDefault();

        if (this.isOpen) {
          this.close();
        } else {
          this.open();
        }
      }
    });
    this.on('keydown', (event: KeyboardEvent) => {
      const target = event.target as HTMLElement;
      if (this.buttonTarget == target) {
        this.onButtonKeydown(event);
      } else if (
        this.isMenu &&
        (this.menuTarget == target || this.menuTarget.contains(target))
      ) {
        this.onMenuKeydown(event);
      }
    });

    this.on(document.body, 'click', (event) => {
      const target = event.target as HTMLElement;
      if (this.isOpen && this.isClickOutside(target)) {
        this.menuTarget.classList.remove('fade-in-down');
        this.close();
      }
    });
  }

  close() {
    this.buttonTarget.setAttribute('aria-expanded', 'false');
    this.menuTarget.parentElement?.classList.remove('open');
    this.setFocusToMenuitem(null);
  }

  private open(focusMenuItem: 'first' | 'last' = 'first') {
    this.buttonTarget.setAttribute('aria-expanded', 'true');
    this.menuTarget.parentElement?.classList.add('open');
    this.menuTarget.focus();

    requestAnimationFrame(() => {
      if (focusMenuItem == 'first') {
        this.setFocusToFirstMenuitem();
      } else {
        this.setFocusToLastMenuitem();
      }
    });
  }

  private isClickOutside(target: HTMLElement) {
    return (
      target.isConnected &&
      target != document.body &&
      !this.element.contains(target) &&
      !target.closest('reach-portal') &&
      !target.closest('#rac-portal') &&
      this.isOpen
    );
  }

  private get currentMenuItem() {
    return this.menuTarget.querySelector<HTMLElement>(
      '[role="menuitem"]:focus'
    );
  }

  private get menuItems() {
    return [
      ...this.menuTarget.querySelectorAll<HTMLElement>('[role="menuitem"]')
    ];
  }

  private setFocusToMenuitem(menuItem: HTMLElement | null) {
    if (menuItem) {
      menuItem.focus();
    } else {
      this.buttonTarget.focus();
    }
  }

  private setFocusToFirstMenuitem() {
    this.setFocusToMenuitem(this.menuItems[0]);
  }

  private setFocusToLastMenuitem() {
    const length = this.menuItems.length;
    this.setFocusToMenuitem(this.menuItems[length - 1]);
  }

  setFocusToPreviousMenuitem() {
    const { currentMenuItem, menuItems } = this;

    if (currentMenuItem) {
      const index = menuItems.indexOf(currentMenuItem);
      if (index == 0) {
        this.setFocusToLastMenuitem();
      } else {
        this.setFocusToMenuitem(menuItems[index - 1]);
      }
    }
  }

  setFocusToNextMenuitem() {
    const { currentMenuItem, menuItems } = this;

    if (currentMenuItem) {
      const index = menuItems.indexOf(currentMenuItem);
      if (index == menuItems.length - 1) {
        this.setFocusToFirstMenuitem();
      } else {
        this.setFocusToMenuitem(menuItems[index + 1]);
      }
    }
  }

  performMenuAction(target: EventTarget | null) {
    target?.dispatchEvent(new Event('click'));
  }

  private onButtonKeydown(event: KeyboardEvent) {
    let stopPropagation = false;
    switch (event.key) {
      case ' ':
      case 'Enter':
        if (this.isOpen) {
          this.close();
        } else {
          this.open();
        }
        stopPropagation = true;
        break;
      case 'ArrowDown':
      case 'Down':
        this.open();
        stopPropagation = true;
        break;
      case 'Esc':
      case 'Escape':
        this.close();
        stopPropagation = true;
        break;
      case 'Up':
      case 'ArrowUp':
        this.open('last');
        stopPropagation = true;
        break;
      default:
        break;
    }

    if (stopPropagation) {
      event.stopPropagation();
      event.preventDefault();
    }
  }

  onMenuKeydown(event: KeyboardEvent) {
    let stopPropagation = false;
    if (event.ctrlKey || event.altKey || event.metaKey) {
      return;
    }

    if (event.shiftKey) {
      if (event.key == 'Tab') {
        this.close();
        stopPropagation = true;
      }
    } else {
      switch (event.key) {
        case ' ':
          this.performMenuAction(event.target);
          stopPropagation = true;
          break;
        case 'Esc':
        case 'Escape':
          this.close();
          stopPropagation = true;
          break;
        case 'Up':
        case 'ArrowUp':
          this.setFocusToPreviousMenuitem();
          stopPropagation = true;
          break;
        case 'ArrowDown':
        case 'Down':
          this.setFocusToNextMenuitem();
          stopPropagation = true;
          break;
        case 'Home':
        case 'PageUp':
          this.setFocusToFirstMenuitem();
          stopPropagation = true;
          break;
        case 'End':
        case 'PageDown':
          this.setFocusToLastMenuitem();
          stopPropagation = true;
          break;
        case 'Tab':
          this.close();
          break;
        default:
          break;
      }
    }

    if (stopPropagation) {
      event.stopPropagation();
      event.preventDefault();
    }
  }
}
