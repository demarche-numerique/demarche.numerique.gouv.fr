import type { SuggestionOptions, SuggestionProps } from '@tiptap/suggestion';
import * as s from 'superstruct';
import { matchSorter } from 'match-sorter';

export const tagSchema = s.coerce(
  s.object({
    label: s.string(),
    id: s.string(),
    mandatory: s.optional(s.boolean()),
    conditional: s.optional(s.boolean())
  }),
  s.type({
    tagLabel: s.string(),
    tagId: s.string(),
    tagMandatory: s.optional(s.string()),
    tagConditional: s.optional(s.string())
  }),
  ({ tagId, tagLabel, tagMandatory, tagConditional }) => ({
    label: tagLabel,
    id: tagId,
    mandatory: tagMandatory === 'true',
    conditional: tagConditional === 'true'
  })
);
export type TagSchema = s.Infer<typeof tagSchema>;

export function tagDisplay({
  label,
  mandatory,
  conditional
}: Pick<TagSchema, 'label' | 'mandatory' | 'conditional'>): {
  text: string;
  classes: string[];
} {
  let text = label;
  if (mandatory) {
    text += ' *';
  }
  if (conditional) {
    text += ' [conditionné]';
  }

  const classes = ['fr-tag', 'fr-tag--sm'];
  if (conditional) {
    classes.push('fr-tag--purple-glycine');
  }

  return { text, classes };
}

class SuggestionMenu {
  #selectedIndex = 0;
  #props: SuggestionProps<TagSchema>;

  #element: HTMLElement;
  #unmount: () => void;

  constructor(props: SuggestionProps<TagSchema>) {
    this.#props = props;
    this.#element = this.createMenu();
    this.render();
    this.#unmount = props.mount(this.#element);
  }

  update(props: SuggestionProps<TagSchema>) {
    this.#props = props;
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
      case 'Enter':
        this.enter();
        return true;
    }
    return false;
  }

  destroy() {
    this.#unmount();
    this.#element.removeEventListener('click', this.handleItemClick);
  }

  private render() {
    // No item while the first fetch runs, or when nothing matches the query.
    this.#element.classList.toggle('hidden', this.#props.items.length == 0);

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
      const { text, classes } = tagDisplay(item);
      button.className = classes.join(' ');
      button.setAttribute(
        'aria-pressed',
        i == this.#selectedIndex ? 'true' : 'false'
      );
      button.dataset.tagIndex = String(i);
      button.textContent = text;
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
}

export function createSuggestionMenu(
  tags: TagSchema[],
  editorElement: HTMLElement
): Omit<SuggestionOptions<TagSchema>, 'editor'> {
  return {
    char: '@',
    allowedPrefixes: null,
    allowSpaces: true,
    // Inside the editor, where the tags menu styles apply.
    container: editorElement,
    offset: { mainAxis: 10 },
    items: ({ query }) => {
      return matchSorter(tags, query, { keys: ['label'] }).slice(0, 6);
    },
    render: () => {
      let menu: SuggestionMenu;

      return {
        onStart: (props) => {
          menu = new SuggestionMenu(props);
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
