import {
  Select as AriaSelect,
  Autocomplete,
  SelectValue,
  Button,
  Label,
  Text,
  Popover,
  Virtualizer,
  ListLayout,
  ListBoxSection,
  Collection,
  Header,
  ButtonContext,
  useFilter,
  useSlottedContext
} from 'react-aria-components';
import type {
  SelectProps as AriaSelectProps,
  AutocompleteProps
} from 'react-aria-components';
import { useState, useMemo, useRef, useCallback, useId, type Key } from 'react';
import { flushSync } from 'react-dom';
import * as s from 'superstruct';
import { Plural, useLingui } from '@lingui/react/macro';

import './react-aria/components/Select.css';
import { SearchField } from './react-aria/components/SearchField';
import {
  DropdownListBox as SelectListBox,
  DropdownItem as SelectItem,
  DropdownItemContent
} from './react-aria/components/ListBox';
import {
  type Item,
  type Section,
  SingleSelectProps,
  MultipleSelectProps
} from './react-aria/props';
import { TagGroup } from './react-aria/components/TagGroup';
import { dataAttributes } from './react-aria/hooks';

type SelectionMode = 'single' | 'multiple';
type SelectProps<M extends SelectionMode = 'single'> = AriaSelectProps<
  Item,
  M
> & {
  items?: Item[];
  sections?: Section[];
  value: M extends 'single' ? string | null : string[];
  label?: string;
  description?: string;
  triggerId?: string;
  labelId?: string;
  ariaLabelledbyPrefix?: string;
  alwaysShowKey?: string;
  emptyHint?: string;
  selectedLabels?: { one: string; other: string };
  data?: Record<string, string>;
};
type AutocompleteFilter = NonNullable<AutocompleteProps<Item>['filter']>;

function Select<M extends SelectionMode = 'single'>({
  items,
  sections,
  label,
  description,
  triggerId,
  labelId,
  ariaLabelledbyPrefix,
  alwaysShowKey,
  emptyHint,
  selectedLabels,
  id: _id, // eslint-disable-line @typescript-eslint/no-unused-vars -- intentionally discarded to prevent AriaSelect from putting it on a hidden <select>
  ...props
}: SelectProps<M>) {
  const { t } = useLingui();
  const { contains } = useFilter({ sensitivity: 'base', numeric: true });
  const filter = useCallback<AutocompleteFilter>(
    (textValue, inputValue, node) => {
      if (alwaysShowKey && node.value?.value == alwaysShowKey) {
        return true;
      }
      return contains(textValue, inputValue);
    },
    [contains, alwaysShowKey]
  );

  if (!items && !sections) {
    throw new Error('Select must be provided with either items or sections');
  }

  if (!props['aria-label'] && labelId) {
    props['aria-labelledby'] = [ariaLabelledbyPrefix, labelId]
      .filter(Boolean)
      .join(' ');
  }

  return (
    <AriaSelect {...props}>
      {label ? (
        <Label className="fr-label">
          {label}
          {description ? (
            <Text slot="description" className="fr-hint-text">
              {description}
            </Text>
          ) : null}
        </Label>
      ) : null}
      {props.selectionMode == 'single' ? (
        <Button id={triggerId} className="fr-select">
          <SelectValue />
        </Button>
      ) : (
        <MultipleSelectValue
          triggerId={triggerId}
          emptyHint={emptyHint}
          selectedLabels={selectedLabels}
        />
      )}
      <Popover
        className="react-aria-Popover select-popover"
        style={{ display: 'flex', flexDirection: 'column' }}
      >
        <Autocomplete<Item> filter={filter}>
          <SearchField
            autoFocus
            aria-label={labelId ? undefined : t`Rechercher dans la liste`}
            aria-labelledby={labelId}
            placeholder={t`Rechercher`}
            style={{ margin: 4 }}
          />
          <Virtualizer layout={ListLayout}>
            <SelectListBox items={sections ? undefined : items}>
              {sections ? (
                <Collection items={sections}>
                  {(section) => (
                    // Section keys share the collection with item keys, and a
                    // key collision sends react-aria's filter into infinite
                    // recursion. Item values are strings, so a numeric key
                    // can never collide with one.
                    <ListBoxSection id={sections.indexOf(section)}>
                      <Header className="dropdown-section-header">
                        {section.label}
                      </Header>
                      <Collection items={section.items}>
                        {selectOption}
                      </Collection>
                    </ListBoxSection>
                  )}
                </Collection>
              ) : (
                selectOption
              )}
            </SelectListBox>
          </Virtualizer>
        </Autocomplete>
      </Popover>
    </AriaSelect>
  );
}

// The render function must return the item element itself (the collection
// reads its `id`), so this is a function, not a component. `textValue` is what
// the search filter and typeahead match; it is derived from string children
// only, hence explicit here where the children are not a string.
function selectOption(item: Item) {
  const label = item.mandatory ? `${item.label} *` : item.label;
  return (
    <SelectItem id={item.value} textValue={label}>
      <DropdownItemContent
        icon={item.icon}
        label={label}
        description={item.description}
      />
    </SelectItem>
  );
}

function selectedLabel(count: number, labels?: { one: string; other: string }) {
  if (!labels || count == 0) {
    return null;
  }
  return count == 1 ? labels.one : labels.other.replace('#', String(count));
}

function MultipleSelectValue({
  triggerId,
  emptyHint,
  selectedLabels
}: {
  triggerId?: string;
  emptyHint?: string;
  selectedLabels?: { one: string; other: string };
}) {
  const selectButtonRef = useRef<HTMLButtonElement>(null);
  const { t } = useLingui();
  const valueId = useId();
  const buttonContext = useSlottedContext(ButtonContext);
  const describedBy = [buttonContext?.['aria-describedby'], valueId]
    .filter(Boolean)
    .join(' ');
  return (
    <SelectValue<Item>>
      {({ selectedItems, state, defaultChildren }) => (
        <>
          <Button
            id={triggerId}
            className="fr-select"
            ref={selectButtonRef}
            aria-describedby={describedBy}
          >
            <span
              id={valueId}
              className="react-aria-SelectValue"
              data-placeholder
            >
              {selectedLabel(selectedItems.length, selectedLabels) ?? (
                <Plural
                  value={selectedItems.length}
                  _0={defaultChildren}
                  one="1 choix sélectionné"
                  other="# choix sélectionnés"
                />
              )}
            </span>
          </Button>
          {selectedItems.length === 0 && emptyHint ? (
            <p className="select-empty-hint fr-text--sm fr-text-mention--grey fr-mt-1w fr-mb-0">
              {emptyHint}
            </p>
          ) : (
            <TagGroup
              items={selectedItems.filter((item) => item != null)}
              onRemove={(value) => {
                if (Array.isArray(state.value)) {
                  state.setValue(state.value.filter((k) => k !== value));
                }
              }}
              fallbackFocusRef={selectButtonRef}
              aria-label={t`Sélection`}
            />
          )}
        </>
      )}
    </SelectValue>
  );
}

export function SingleSelect(maybeProps: SelectProps<'single'>) {
  const {
    value: initialValue,
    className,
    data,
    ...props
  } = useMemo(() => s.create(maybeProps, SingleSelectProps), [maybeProps]);
  const [value, setValue] = useState<string | null>(() => initialValue);
  const changeDispatchRef = useRef<HTMLInputElement>(null);

  const dispatchChange = () => {
    changeDispatchRef.current?.dispatchEvent(
      new Event('change', { bubbles: true })
    );
  };

  const onChange = (key: Key | null) => {
    flushSync(() => {
      setValue(key ? String(key) : null);
    });
    dispatchChange();
  };

  return (
    <>
      <Select
        className={`fr-ds-select_single react-aria-Select ${className ?? ''}`}
        selectionMode="single"
        value={value}
        onChange={onChange}
        {...props}
      />
      {/* The form value travels in react-aria's hidden <select>. This input only carries
          the change event, so it mirrors the value and takes the `data` attributes for the
          Stimulus controllers listening to it (autosubmit, enable-submit-if-filled). */}
      <input
        ref={changeDispatchRef}
        type="hidden"
        value={value ?? ''}
        {...dataAttributes(data)}
      />
    </>
  );
}

export function MultipleSelect(maybeProps: SelectProps<'multiple'>) {
  const {
    value: initialValue,
    className,
    name,
    ...props
  } = useMemo(() => s.create(maybeProps, MultipleSelectProps), [maybeProps]);
  const [value, setValue] = useState<string[]>(() => initialValue);
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

  // `name` is destructured out above so the `{...props}` spread no longer carries
  // it into <Select>. Otherwise react-aria's hidden <select multiple> picks up the
  // name and the browser submits its selected options in DOM (collection) order —
  // losing the user's selection order. The explicit hidden inputs below carry the
  // form value in selection order instead.
  return (
    <>
      <Select
        className={`fr-ds-select_multiple react-aria-Select ${className ?? ''}`}
        selectionMode="multiple"
        value={value}
        onChange={onChange}
        {...props}
      />
      {value.length === 0 ? (
        <input ref={changeDispatchRef} type="hidden" name={name} value="" />
      ) : (
        value.map((v, i) => (
          <input
            key={v}
            ref={i === 0 ? changeDispatchRef : undefined}
            type="hidden"
            name={name}
            value={v}
          />
        ))
      )}
    </>
  );
}
