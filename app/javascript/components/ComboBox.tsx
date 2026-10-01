import type { ListBoxItemProps } from 'react-aria-components';
import {
  ComboBox as AriaComboBox,
  ListBox,
  Popover,
  Input,
  Label,
  Text,
  Button,
  Virtualizer,
  ListLayout
} from 'react-aria-components';
import { useMemo, useRef, createContext, useContext, useId } from 'react';
import type { RefObject } from 'react';
import * as s from 'superstruct';

import {
  useDispatchChangeEvent,
  useMultiList,
  useRemoteList,
  useOnFormReset,
  createLoader,
  dataAttributes,
  getKey,
  type ComboBoxProps
} from './react-aria/hooks';
import {
  type Item,
  MultiComboBoxProps,
  RemoteComboBoxProps
} from './react-aria/props';
import { DropdownItem } from './react-aria/components/ListBox';
import { TagGroup } from './react-aria/components/TagGroup';

export function ComboBox({
  children,
  errorMessage,
  label,
  labelId,
  ariaLabelledbyPrefix,
  description,
  className,
  inputId,
  inputRef,
  isLoading,
  isOpen,
  placeholder,
  items,
  ...props
}: ComboBoxProps & {
  inputId?: string;
  inputRef?: RefObject<HTMLInputElement | null>;
  isOpen?: boolean;
  placeholder?: string;
  errorMessage?: string;
}) {
  const generatedId = useId();
  // if label is passed, we need to generate an id for the input, otherwise we use the labelId passed in the props
  const labelIdToUse = label ? generatedId : labelId;

  const inputAriaLabelledby =
    [ariaLabelledbyPrefix, labelIdToUse].filter(Boolean).join(' ') || undefined;

  return (
    <AriaComboBox
      {...props}
      items={items}
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
          id={inputId}
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
            className="fr-menu__list dropdown-listbox"
            renderEmptyState={() =>
              errorMessage ? (
                <p className="fr-message fr-message--error fr-p-1w">
                  {errorMessage}
                </p>
              ) : undefined
            }
          >
            {children}
          </ListBox>
        </Virtualizer>
      </Popover>
    </AriaComboBox>
  );
}

export function ComboBoxItem(props: ListBoxItemProps<Item>) {
  const { isDisabled, className, ...rest } = props;

  return (
    <DropdownItem
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

export function MultiComboBox(maybeProps: MultiComboBoxProps) {
  const {
    items: defaultItems,
    selectedKeys: defaultSelectedKeys,
    placeholder,
    name,
    form,
    formValue,
    allowsCustomValue,
    valueSeparator,
    className,
    ...props
  } = useMemo(() => s.create(maybeProps, MultiComboBoxProps), [maybeProps]);

  const { ref, dispatch } = useDispatchChangeEvent();
  const inputRef = useRef<HTMLInputElement>(null);

  const {
    selectedItems,
    hiddenInputValues,
    onRemove,
    onReset,
    items: filteredItems,
    ...comboBoxProps
  } = useMultiList({
    defaultItems,
    defaultSelectedKeys,
    formValue,
    allowsCustomValue,
    valueSeparator,
    focusInput: () => {
      inputRef.current?.focus();
    },
    onChange: dispatch
  });
  const formResetRef = useOnFormReset(onReset);

  const disabledKeys = useMemo(
    () => selectedItems.map((item) => item.value),
    [selectedItems]
  );

  return (
    <div className={`fr-ds-combobox__multiple ${className ? className : ''}`}>
      <TagGroup
        items={selectedItems}
        onRemove={(value) => onRemove(new Set([value]))}
        fallbackFocusRef={inputRef}
        className="fr-tag-list"
        aria-label={props['aria-label']}
      />
      <ComboBox
        allowsCustomValue={allowsCustomValue}
        inputRef={inputRef}
        menuTrigger="focus"
        placeholder={placeholder}
        {...comboBoxProps}
        items={filteredItems}
        disabledKeys={disabledKeys}
        {...props}
      >
        {(item) => <ComboBoxItem id={getKey(item)}>{item.label}</ComboBoxItem>}
      </ComboBox>
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
  const ref = useOnFormReset(onReset);
  return (
    <input
      ref={onReset ? ref : undefined}
      type="hidden"
      name={name}
      value={value}
      form={form}
      {...dataAttributes(data)}
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
