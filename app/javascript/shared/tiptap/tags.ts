import type { SuggestionOptions, SuggestionProps } from '@tiptap/suggestion';
import * as s from 'superstruct';
import tippy, { type Instance as TippyInstance } from 'tippy.js';
import { matchSorter } from 'match-sorter';

export const tagSchema = s.coerce(
  s.object({ label: s.string(), id: s.string() }),
  s.type({
    tagLabel: s.string(),
    tagId: s.string()
  }),
  ({ tagId, tagLabel }) => ({ label: tagLabel, id: tagId })
);
export type TagSchema = s.Infer<typeof tagSchema>;

class SuggestionMenu {
  #selectedIndex = 0;
  #props: SuggestionProps<TagSchema>;

  #element?: Element;
  #popup?: TippyInstance;

  constructor(props: SuggestionProps<TagSchema>, editorElement: Element) {
    this.#props = props;
    this.render();
    this.init(editorElement);
  }

  init(editorElement: Element) {
    if (!this.#props.clientRect) {
      return;
    }

    this.#popup = tippy(document.body, {
      getReferenceClientRect: () => {
        const domRect = this.#props?.clientRect?.();
        if (!domRect) {
          throw new Error('domRect is null');
        }
        return domRect;
      },
      appendTo: editorElement,
      content: this.#element,
      showOnCreate: true,
      interactive: true,
      trigger: 'manual',
      placement: 'bottom-start'
    });
  }

  update(props: SuggestionProps<TagSchema>) {
    this.#props = props;

    if (!this.#props.clientRect) {
      return;
    }

    this.#popup?.setProps({
      getReferenceClientRect: () => {
        const domRect = props.clientRect?.();
        if (!domRect) {
          throw new Error('domRect is null');
        }
        return domRect;
      }
    });

    this.render();
  }

  onKeyDown(key: string) {
    switch (key) {
      case 'ArrowDown':
        this.down();
        return true;
      case 'ArrowUp':
        this.up();
        return true;
      case 'Escape':
        this.escape();
        return true;
      case 'Enter':
        this.enter();
        return true;
    }
    return false;
  }

  destroy() {
    this.#popup?.destroy();
    this.#element?.remove();
    this.#element?.removeEventListener('click', this.handleItemClick);
  }

  private render() {
    if (this.#props.items.length == 0) {
      this.#element?.remove();
      return;
    }

    this.#element ??= this.createMenu();
    const list = this.#element.firstChild as HTMLUListElement;

    list.textContent = '';

    const hintLi = document.createElement('li');
    const hintSpan = document.createElement('span');
    hintSpan.className = 'fr-hint-text';
    hintSpan.textContent =
      'Tapez le nom d\u2019une balise, naviguez avec les flèches, validez avec Entrée ou en cliquant sur la balise.';
    hintLi.append(hintSpan);
    list.append(hintLi);

    this.#props.items.forEach((item, i) => {
      const li = document.createElement('li');
      const button = document.createElement('button');
      button.className = 'fr-tag fr-tag--sm';
      button.setAttribute(
        'aria-pressed',
        i == this.#selectedIndex ? 'true' : 'false'
      );
      button.dataset.tagIndex = String(i);
      button.textContent = item.label;
      li.append(button);
      list.append(li);
    });
    list.querySelector<HTMLElement>('.selected')?.focus();
  }

  private createMenu() {
    const menu = document.createElement('div');
    menu.classList.add('fr-menu');

    const list = document.createElement('ul');
    list.classList.add('fr-menu__list', 'fr-tag-list', 'list-style-type-none');

    menu.appendChild(list);

    menu.addEventListener('click', this.handleItemClick);

    return menu;
  }

  private handleItemClick = (event: Event) => {
    const target = event.target as HTMLElement;
    if (!target || target.dataset.tagIndex === undefined) {
      return;
    }

    this.#props.command(this.#props.items[Number(target.dataset.tagIndex)]);
    this.#popup?.hide();
  };

  private up() {
    this.#selectedIndex =
      (this.#selectedIndex + this.#props.items.length - 1) %
      this.#props.items.length;
    this.render();
  }

  private down() {
    this.#selectedIndex = (this.#selectedIndex + 1) % this.#props.items.length;
    this.render();
  }

  private enter() {
    const item = this.#props.items[this.#selectedIndex];

    if (item) {
      this.#props.command(item);
    }
  }

  private escape() {
    this.#popup?.hide();
    this.#selectedIndex = 0;
  }
}

export function createSuggestionMenu(
  tags: TagSchema[],
  editorElement: Element
): Omit<SuggestionOptions<TagSchema>, 'editor'> {
  return {
    char: '@',
    allowedPrefixes: null,
    allowSpaces: true,
    items: ({ query }) => {
      return matchSorter(tags, query, { keys: ['label'] }).slice(0, 6);
    },
    render: () => {
      let menu: SuggestionMenu;

      return {
        onStart: (props) => {
          menu = new SuggestionMenu(props, editorElement);
        },

        onUpdate(props) {
          menu.update(props);
        },

        onKeyDown(props) {
          return menu.onKeyDown(props.event.key);
        },

        onExit() {
          menu.destroy();
        }
      };
    }
  };
}
