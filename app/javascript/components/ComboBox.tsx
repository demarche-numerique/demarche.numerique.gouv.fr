import type { ListBoxItemProps } from 'react-aria-components';
import {
  ComboBox as AriaComboBox,
  ListBox,
  ListBoxItem,
  ListBoxSection,
  Header,
  Popover,
  Input,
  Label,
  Text,
  Button,
  TagGroup,
  TagList,
  Tag,
  Virtualizer,
  ListLayout,
  Collection
} from 'react-aria-components';
import { useMemo, useRef, createContext, useContext, useId } from 'react';
import type { RefObject } from 'react';
import * as s from 'superstruct';
import { Trans, useLingui } from '@lingui/react/macro';

import {
  useDispatchChangeEvent,
  useMultiList,
  useSingleList,
  useRemoteList,
  useOnFormReset,
  createLoader,
  getKey,
  type ComboBoxProps
} from './react-aria/hooks';
import {
  type Item,
  type Section,
  SingleComboBoxProps,
  MultiComboBoxProps,
  RemoteComboBoxProps
} from './react-aria/props';

function flattenSections(sections: Section[]): Item[] {
  return sections.flatMap((section) => section.items);
}

function reconstructSections(
  originalSections: Section[],
  filteredItems: Item[]
): Section[] {
  const filteredValues = new Set(filteredItems.map((item) => item.value));
  return originalSections
    .map((section) => ({
      label: section.label,
      items: section.items.filter((item) => filteredValues.has(item.value))
    }))
    .filter((section) => section.items.length > 0);
}

function getItems(
  items?: Item[],
  sections?: Section[]
): { flatItems: Item[]; sections: Section[] | null } {
  if (items && sections) {
    throw new Error('ComboBox: pass either `items` or `sections`, not both.');
  }
  if (!items && !sections) {
    return { flatItems: [], sections: null };
  }
  if (sections) {
    return { flatItems: flattenSections(sections), sections };
  }
  return { flatItems: items!, sections: null };
}

export function ComboBox({
  children,
  sections,
  errorMessage,
  label,
  labelId,
  ariaLabelledbyPrefix,
  description,
  className,
  inputRef,
  isLoading,
  isOpen,
  placeholder,
  items,
  ...props
}: ComboBoxProps & {
  inputRef?: RefObject<HTMLInputElement | null>;
  isOpen?: boolean;
  placeholder?: string;
  errorMessage?: string;
  sections?: Section[] | null;
}) {
  const generatedId = useId();
  // if label is passed, we need to generate an id for the input, otherwise we use the labelId passed in the props
  const labelIdToUse = label ? generatedId : labelId;

  const inputAriaLabelledby = ariaLabelledbyPrefix
    ? `${ariaLabelledbyPrefix} ${labelIdToUse}`
    : labelIdToUse;

  return (
    <AriaComboBox
      {...props}
      {...(sections ? {} : { items })}
      className={`fr-ds-combobox ${className ?? ''}`}
      shouldFocusWrap={true}
    >
      {label ? (
        <Label className="fr-label" id={labelIdToUse}>
          {label}
          {description ? (
            <Text slot="description" className="fr-hint-text fr-mb-1w">
              {description}
            </Text>
          ) : null}
        </Label>
      ) : null}
      <div className="fr-ds-combobox__input" style={{ position: 'relative' }}>
        <Input
          className="fr-select fr-autocomplete"
          ref={inputRef}
          aria-busy={isLoading}
          aria-labelledby={inputAriaLabelledby}
          placeholder={placeholder || undefined}
          translate="no"
        />
        <Button
          aria-haspopup="false"
          style={{
            width: '40px',
            height: '100%',
            position: 'absolute',
            opacity: 0,
            right: 0,
            top: 0
          }}
        >
          {' '}
        </Button>
      </div>
      <Popover className="fr-ds-combobox__menu fr-menu" isOpen={isOpen}>
        <Virtualizer layout={ListLayout}>
          <ListBox
            className="fr-menu__list"
            renderEmptyState={() =>
              errorMessage ? (
                <p className="fr-message fr-message--error fr-p-1w">
                  {errorMessage}
                </p>
              ) : undefined
            }
          >
            {sections ? (
              <Collection items={sections}>
                {(section) => (
                  <ListBoxSection id={section.label}>
                    <Header className="fr-ds-combobox__section-header">
                      {section.label}
                    </Header>
                    <Collection items={section.items}>{children}</Collection>
                  </ListBoxSection>
                )}
              </Collection>
            ) : (
              children
            )}
          </ListBox>
        </Virtualizer>
      </Popover>
    </AriaComboBox>
  );
}

export function ComboBoxItem(props: ListBoxItemProps<Item>) {
  const { isDisabled, className, ...rest } = props;

  return (
    <ListBoxItem
      {...rest}
      isDisabled={isDisabled}
      className={[
        'fr-menu__item',
        isDisabled ? 'fr-menu__item--disabled' : null,
        className
      ]
        .filter(Boolean)
        .join(' ')}
    />
  );
}

export function SingleComboBox({
  children,
  ...maybeProps
}: SingleComboBoxProps) {
  const {
    items: defaultItems,
    sections: defaultSections,
    selectedKey: defaultSelectedKey,
    placeholder,
    emptyFilterKey,
    name,
    formValue,
    form,
    data,
    ...props
  } = useMemo(() => s.create(maybeProps, SingleComboBoxProps), [maybeProps]);

  const { flatItems, sections } = useMemo(
    () => getItems(defaultItems, defaultSections),
    [defaultItems, defaultSections]
  );

  const { ref, dispatch } = useDispatchChangeEvent();

  const {
    selectedItem,
    onReset,
    items: filteredItems,
    ...comboBoxProps
  } = useSingleList({
    defaultItems: flatItems,
    defaultSelectedKey,
    emptyFilterKey,
    onChange: dispatch
  });

  const filteredSections = useMemo(
    () => (sections ? reconstructSections(sections, filteredItems) : null),
    [sections, filteredItems]
  );

  return (
    <>
      <ComboBox
        menuTrigger="focus"
        placeholder={placeholder}
        {...comboBoxProps}
        items={filteredItems}
        sections={filteredSections}
        {...props}
      >
        {(item) => <ComboBoxItem id={getKey(item)}>{item.label}</ComboBoxItem>}
      </ComboBox>
      {children || name ? (
        <span ref={ref}>
          <SelectedItemProvider value={selectedItem}>
            {name ? (
              <ComboBoxValueSlot
                field={formValue == 'text' ? 'label' : 'value'}
                name={name}
                form={form}
                onReset={onReset}
                data={data}
              />
            ) : null}
            {children}
          </SelectedItemProvider>
        </span>
      ) : null}
    </>
  );
}

export function MultiComboBox(maybeProps: MultiComboBoxProps) {
  const {
    items: defaultItems,
    sections: defaultSections,
    selectedKeys: defaultSelectedKeys,
    placeholder,
    name,
    form,
    formValue,
    allowsCustomValue,
    valueSeparator,
    className,
    focusOnSelect,
    tagsBelow = false,
    hideSelectedTags = false,
    ...props
  } = useMemo(() => s.create(maybeProps, MultiComboBoxProps), [maybeProps]);

  const { flatItems, sections } = useMemo(
    () => getItems(defaultItems, defaultSections),
    [defaultItems, defaultSections]
  );

  const keepSelectedItems = hideSelectedTags;
  const { ref, dispatch } = useDispatchChangeEvent();
  const inputRef = useRef<HTMLInputElement>(null);

  const { t } = useLingui();

  const {
    selectedItems,
    hiddenInputValues,
    onRemove,
    onReset,
    items: filteredItems,
    ...comboBoxProps
  } = useMultiList({
    defaultItems: flatItems,
    defaultSelectedKeys,
    formValue,
    allowsCustomValue,
    valueSeparator,
    keepSelectedItems,
    focusInput: () => {
      inputRef.current?.focus();
    },
    onChange: () => {
      dispatch();
      if (focusOnSelect) {
        document.getElementById(focusOnSelect)?.focus();
      }
    }
  });
  const formResetRef = useOnFormReset(onReset);

  const filteredSections = useMemo(
    () => (sections ? reconstructSections(sections, filteredItems) : null),
    [sections, filteredItems]
  );

  const tagGroup =
    selectedItems.length > 0 && !hideSelectedTags ? (
      <TagGroup
        onRemove={onRemove}
        aria-label={props['aria-label']}
        className={tagsBelow ? 'fr-mt-1w' : undefined}
      >
        <TagList items={selectedItems} className="fr-tag-list">
          {selectedItems.map((item) => (
            <Tag
              key={item.value}
              id={item.value}
              textValue={t`Supprimer ${item.label}`}
              className="fr-tag fr-tag--sm fr-tag--dismiss"
            >
              {item.label}
              <Button
                aria-labelledby=""
                aria-label=""
                slot="remove"
                className="fr-tag--dismiss"
              >
                <span className="fr-sr-only">
                  <Trans>Supprimer {item.label}</Trans>
                </span>
              </Button>
            </Tag>
          ))}
        </TagList>
      </TagGroup>
    ) : null;

  const disabledKeys = useMemo(
    () => selectedItems.map((item) => item.value),
    [selectedItems]
  );

  return (
    <div className={`fr-ds-combobox__multiple ${className ? className : ''}`}>
      {!tagsBelow ? tagGroup : null}
      <ComboBox
        allowsCustomValue={allowsCustomValue}
        inputRef={inputRef}
        menuTrigger="focus"
        placeholder={placeholder}
        {...comboBoxProps}
        items={filteredItems}
        sections={filteredSections}
        disabledKeys={disabledKeys}
        {...props}
      >
        {(item) => <ComboBoxItem id={getKey(item)}>{item.label}</ComboBoxItem>}
      </ComboBox>
      {tagsBelow ? tagGroup : null}
      {name ? (
        <span ref={ref}>
          {hiddenInputValues.length === 0 ? (
            <input
              type="hidden"
              value=""
              name={name}
              form={form}
              ref={formResetRef}
            />
          ) : (
            hiddenInputValues.map((value, i) => (
              <input
                type="hidden"
                value={value}
                name={name}
                form={form}
                ref={i === 0 ? formResetRef : undefined}
                key={value}
              />
            ))
          )}
        </span>
      ) : null}
    </div>
  );
}

export function RemoteComboBox({
  loader,
  onChange,
  children,
  ...maybeProps
}: RemoteComboBoxProps) {
  if ('sections' in maybeProps) {
    throw new Error('RemoteComboBox does not support the `sections` prop.');
  }
  const {
    items: defaultItems,
    selectedKey: defaultSelectedKey,
    placeholder,
    minimumInputLength,
    limit,
    debounce,
    coerce,
    formValue,
    name,
    form,
    data,
    usePost,
    translations,
    ...props
  } = useMemo(() => s.create(maybeProps, RemoteComboBoxProps), [maybeProps]);

  const { ref, dispatch } = useDispatchChangeEvent();

  const load = useMemo(
    () =>
      typeof loader === 'string'
        ? createLoader(loader, {
            minimumInputLength,
            limit,
            coerce,
            usePost,
            errorMessage: translations?.search_error
          })
        : loader,
    [loader, minimumInputLength, limit, coerce, usePost, translations]
  );

  const { selectedItem, onReset, shouldShowPopover, error, ...comboBoxProps } =
    useRemoteList({
      defaultItems,
      defaultSelectedKey,
      debounce,
      load,
      onChange: (item) => {
        onChange?.(item);
        dispatch();
      }
    });

  return (
    <>
      <ComboBox
        placeholder={placeholder}
        allowsEmptyCollection={
          comboBoxProps.inputValue.length >= (minimumInputLength ?? 0) ||
          !!error
        }
        errorMessage={error?.message}
        isOpen={shouldShowPopover}
        {...comboBoxProps}
        {...props}
      >
        {(item) => <ComboBoxItem id={getKey(item)}>{item.label}</ComboBoxItem>}
      </ComboBox>
      {children || name ? (
        <span ref={ref}>
          <SelectedItemProvider value={selectedItem}>
            {name ? (
              <ComboBoxValueSlot
                field={formValue == 'text' ? 'label' : 'value'}
                name={name}
                form={form}
                onReset={onReset}
                data={data}
              />
            ) : null}
            {children}
          </SelectedItemProvider>
        </span>
      ) : null}
    </>
  );
}

export function ComboBoxValueSlot({
  field,
  name,
  form,
  onReset,
  data
}: {
  field: 'label' | 'value' | 'data';
  name: string;
  form?: string;
  onReset?: () => void;
  data?: Record<string, string>;
}) {
  const selectedItem = useContext(SelectedItemContext);
  const value = getSelectedValue(selectedItem, field);
  const dataProps = Object.fromEntries(
    Object.entries(data ?? {}).map(([key, value]) => [
      `data-${key.replace(/_/g, '-')}`,
      value
    ])
  );
  const ref = useOnFormReset(onReset);
  return (
    <input
      ref={onReset ? ref : undefined}
      type="hidden"
      name={name}
      value={value}
      form={form}
      {...dataProps}
    />
  );
}

const SelectedItemContext = createContext<Item | null>(null);
const SelectedItemProvider = SelectedItemContext.Provider;

function getSelectedValue(
  selectedItem: Item | null,
  field: 'label' | 'value' | 'data'
): string {
  if (selectedItem == null) {
    return '';
  } else if (field == 'data') {
    if (typeof selectedItem.data == 'string') {
      return selectedItem.data;
    } else if (!selectedItem.data) {
      return '';
    }
    return JSON.stringify(selectedItem.data);
  }
  return selectedItem[field];
}
