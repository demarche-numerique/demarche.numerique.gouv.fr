import {
  Select as AriaSelect,
  Autocomplete,
  SelectValue,
  Button,
  Popover,
  Virtualizer,
  ListLayout,
  TagGroup as AriaTagGroup,
  TagList,
  Tag,
  useFilter
} from 'react-aria-components';
import type {
  SelectProps as AriaSelectProps,
  TagGroupProps
} from 'react-aria-components';
import { useState, useMemo, useRef, type Key } from 'react';
import { flushSync } from 'react-dom';
import * as s from 'superstruct';

import './react-aria/components/Select.css';
import { SearchField } from './react-aria/components/SearchField';
import {
  DropdownListBox as SelectListBox,
  DropdownItem as SelectItem
} from './react-aria/components/ListBox';
import { type Item, MultipleSelectProps } from './react-aria/props';

type SelectionMode = 'single' | 'multiple';
type SelectProps<M extends SelectionMode = 'single'> = AriaSelectProps<
  Item,
  M
> & {
  items: Item[];
  value: M extends 'single' ? string : string[];
  labelId: string;
  ariaLabelledbyPrefix: string;
};

function Select<M extends SelectionMode = 'single'>({
  items,
  labelId,
  ariaLabelledbyPrefix,
  ...props
}: SelectProps<M>) {
  const { contains } = useFilter({ sensitivity: 'base', numeric: true });
  const inputAriaLabelledby = `${ariaLabelledbyPrefix} ${labelId}`;

  return (
    <AriaSelect {...props} aria-labelledby={inputAriaLabelledby}>
      <Button className="react-aria-Select fr-select">
        <SelectValue />
      </Button>
      <Popover
        className="react-aria-Popover select-popover"
        style={{ display: 'flex', flexDirection: 'column' }}
      >
        <Autocomplete<Item> filter={contains}>
          <SearchField autoFocus style={{ margin: 4 }} />
          <Virtualizer layout={ListLayout}>
            <SelectListBox items={items}>
              {(item) => <SelectItem id={item.value}>{item.label}</SelectItem>}
            </SelectListBox>
          </Virtualizer>
        </Autocomplete>
      </Popover>
    </AriaSelect>
  );
}

export function MultipleSelect(maybeProps: SelectProps<'multiple'>) {
  const { value: initialValue, ...props } = useMemo(
    () => s.create(maybeProps, MultipleSelectProps),
    [maybeProps]
  );
  const [value, setValue] = useState<string[]>(() => initialValue);
  const selectedItems = value.flatMap((key) => {
    const item = props.items.find((item) => item.value === key);
    return item ? [item] : [];
  });
  const changeDispatchRef = useRef<HTMLInputElement>(null);

  const dispatchChange = () => {
    changeDispatchRef.current?.dispatchEvent(
      new Event('change', { bubbles: true })
    );
  };

  const onChange = (keys: Key[]) => {
    flushSync(() => {
      setValue(keys.map(String));
    });
    dispatchChange();
  };

  const onRemove = (keys: Set<Key>) => {
    flushSync(() => {
      setValue((value) => value.filter((item) => !keys.has(item)));
    });
    dispatchChange();
  };

  return (
    <div className="fr-ds-select_multiple">
      <Select
        selectionMode="multiple"
        value={value}
        onChange={onChange}
        {...props}
      />
      <TagGroup items={selectedItems} onRemove={onRemove} />
      <input ref={changeDispatchRef} type="hidden" />
    </div>
  );
}

function TagGroup({ items, ...props }: TagGroupProps & { items: Item[] }) {
  return (
    <AriaTagGroup {...props}>
      <TagList items={items} className="fr-tag-list">
        {(item) => (
          <Tag
            key={item.value}
            id={item.value}
            textValue={`Supprimer ${item.label}`}
            className="fr-tag fr-tag--sm fr-tag--dismiss"
          >
            {item.label}
            <Button
              aria-label=""
              aria-labelledby=""
              slot="remove"
              className="fr-tag--dismiss"
            >
              <span className="sr-only">Supprimer {item.label}</span>
            </Button>
          </Tag>
        )}
      </TagList>
    </AriaTagGroup>
  );
}
