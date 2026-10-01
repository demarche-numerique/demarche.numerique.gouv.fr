import { fire, httpRequest } from '@utils';
import { matchSorter, type MatchSorterOptions } from 'match-sorter';
import type { Key } from 'react';
import { useEffect, useMemo, useRef, useState } from 'react';
import type { ComboBoxProps as AriaComboBoxProps } from 'react-aria-components';
import isEqual from 'react-fast-compare';
import { useAsyncList, type AsyncListOptions } from 'react-stately';
import { useEvent } from 'react-use-event-hook';
import * as s from 'superstruct';
import { useDebounceCallback } from 'usehooks-ts';

import { Item } from './props';

export type Loader = AsyncListOptions<Item, string>['load'];

export interface ComboBoxProps extends Omit<
  AriaComboBoxProps<Item>,
  'children'
> {
  children: React.ReactNode | ((item: Item) => React.ReactNode);
  label?: string;
  labelId?: string;
  ariaLabelledbyPrefix?: string;
  description?: string;
  isLoading?: boolean;
}

const inputMap = new WeakMap<HTMLInputElement, string>();
const inputCountMap = new WeakMap<HTMLSpanElement, number>();
export function useDispatchChangeEvent() {
  const ref = useRef<HTMLSpanElement>(null);
  const isDispatchPending = useRef(false);

  // Remember the values of every render the user did not cause: the first one, and those
  // where the server changes the props (a prefill). Otherwise the first dispatch always
  // looks like a change, and react-aria reports picking the already selected item (click,
  // Enter, blur) as a selection change — an untouched champ would be submitted. And going
  // back to a value the server has replaced since would look like no change at all.
  useEffect(() => {
    if (ref.current && !isDispatchPending.current) {
      rememberInputs(
        ref.current,
        Array.from(ref.current.querySelectorAll('input'))
      );
    }
  });

  return {
    ref,
    dispatch: () => {
      isDispatchPending.current = true;
      requestAnimationFrame(() => {
        isDispatchPending.current = false;
        if (ref.current) {
          const container = ref.current;
          const inputs = Array.from(container.querySelectorAll('input'));
          const input = inputs.at(0);
          if (input && inputChanged(container, inputs)) {
            rememberInputs(container, inputs);
            input.dispatchEvent(new Event('change', { bubbles: true }));
          }
        }
      });
    }
  };
}

function rememberInputs(
  container: HTMLSpanElement,
  inputs: HTMLInputElement[]
) {
  inputCountMap.set(container, inputs.length);
  for (const input of inputs) {
    inputMap.set(input, input.value.trim());
  }
}

// I am not proude of this code. We have to tack values and number of values to deal with multi select combobox.
// I have a plan to remove this code. Soon.
function inputChanged(container: HTMLSpanElement, inputs: HTMLInputElement[]) {
  const prevCount = inputCountMap.get(container) ?? 0;
  if (prevCount != inputs.length) {
    return true;
  }
  for (const input of inputs) {
    const value = input.value.trim();
    const prevValue = inputMap.get(input);
    if (prevValue == null || prevValue != value) {
      return true;
    }
  }
  return false;
}

const naturalSort: MatchSorterOptions['baseSort'] = (a, b) => {
  return String(a.rankedValue).localeCompare(String(b.rankedValue), undefined, {
    numeric: true,
    sensitivity: 'base'
  });
};

export function useMultiList({
  defaultItems,
  defaultSelectedKeys,
  allowsCustomValue,
  valueSeparator,
  onChange,
  focusInput,
  formValue
}: {
  defaultItems?: Item[];
  defaultSelectedKeys?: string[];
  allowsCustomValue?: boolean;
  valueSeparator?: string | false;
  onChange?: () => void;
  focusInput?: () => void;
  formValue?: 'text' | 'key';
}) {
  const valueSeparatorRegExp = useMemo(
    () =>
      valueSeparator === false
        ? false
        : valueSeparator
          ? new RegExp(valueSeparator)
          : /\s|,|;/,
    [valueSeparator]
  );
  const [selectedKeys, setSelectedKeys] = useState(
    () => new Set(defaultSelectedKeys ?? [])
  );
  const [inputValue, setInputValue] = useState('');
  const items = useMemo(
    () => (defaultItems ? distinctBy(defaultItems, 'value') : []),
    [defaultItems]
  );
  const itemsIndex = useMemo(() => {
    const index = new Map<string, Item>();
    for (const item of items) {
      index.set(item.value, item);
    }
    return index;
  }, [items]);

  const visibleItems = useMemo(
    () => items.filter((item) => !selectedKeys.has(item.value)),
    [items, selectedKeys]
  );

  const filteredItems = useMemo(() => {
    if (inputValue.length === 0) {
      return visibleItems;
    }

    return matchSorter(visibleItems, inputValue, {
      keys: ['label']
    });
  }, [visibleItems, inputValue]);

  const selectedItems = useMemo(() => {
    const selectedItems: Item[] = [];
    for (const key of selectedKeys) {
      const item = itemsIndex.get(key);
      if (item) {
        selectedItems.push(item);
      } else if (allowsCustomValue) {
        selectedItems.push({ label: key, value: key });
      }
    }
    return selectedItems;
  }, [itemsIndex, selectedKeys, allowsCustomValue]);
  const hiddenInputValues = useMemo(() => {
    const values = selectedItems.map((item) =>
      formValue == 'text' || allowsCustomValue ? item.label : item.value
    );
    if (!valueSeparatorRegExp || !allowsCustomValue || inputValue == '') {
      return values;
    }
    return [
      ...new Set([
        ...values,
        ...inputValue.split(valueSeparatorRegExp).filter(Boolean)
      ])
    ];
  }, [
    selectedItems,
    inputValue,
    valueSeparatorRegExp,
    allowsCustomValue,
    formValue
  ]);
  const isSelectionSetRef = useRef(false);
  const initialSelectedKeysRef = useRef(defaultSelectedKeys);

  // reset default selected keys when props change
  useEffect(() => {
    if (!isEqual(initialSelectedKeysRef.current, defaultSelectedKeys)) {
      initialSelectedKeysRef.current = defaultSelectedKeys;
      setSelectedKeys(new Set(defaultSelectedKeys));
    }
  }, [defaultSelectedKeys]);

  const onSelectionChange = useEvent<
    NonNullable<ComboBoxProps['onSelectionChange']>
  >((key) => {
    if (key) {
      isSelectionSetRef.current = true;
      setSelectedKeys((keys) => {
        const selectedKeys = new Set(keys.values());
        selectedKeys.add(String(key));
        return selectedKeys;
      });
      setInputValue('');
      onChange?.();
    }
  });

  const onInputChange = useEvent<NonNullable<ComboBoxProps['onInputChange']>>(
    (value) => {
      const isSelectionSet = isSelectionSetRef.current;
      isSelectionSetRef.current = false;
      if (isSelectionSet) {
        setInputValue('');
        return;
      }

      if (!valueSeparatorRegExp) {
        setInputValue(value);
        return;
      }

      const values = value.split(valueSeparatorRegExp);
      if (values.length < 2) {
        setInputValue(value);
        return;
      }

      // if input contains a separator, add all values
      const addedKeys = allowsCustomValue
        ? values.filter(Boolean)
        : values
            .filter(Boolean)
            .map((value) => items.find((item) => item.label == value)?.value)
            .filter((key) => key != null);
      setSelectedKeys((keys) => {
        const selectedKeys = new Set(keys.values());
        for (const key of addedKeys) {
          selectedKeys.add(key);
        }
        return selectedKeys;
      });
      onChange?.();
      setInputValue('');
    }
  );

  const onRemove = useEvent<(keys: Set<Key>) => void>((removedKeys) => {
    setSelectedKeys((keys) => {
      const selectedKeys = new Set(keys.values());
      for (const key of removedKeys) {
        selectedKeys.delete(String(key));
      }
      // focus input when all items are removed
      if (selectedKeys.size == 0) {
        focusInput?.();
      }
      return selectedKeys;
    });
    onChange?.();
  });

  const onReset = useEvent(() => {
    setSelectedKeys(new Set());
    setInputValue('');
  });

  return {
    onRemove,
    onSelectionChange,
    onInputChange,
    selectedItems,
    items: filteredItems,
    hiddenInputValues,
    inputValue,
    onReset
  };
}

export function useRemoteList({
  load,
  defaultItems,
  defaultSelectedKey,
  onChange,
  debounce
}: {
  load: Loader;
  defaultItems?: Item[];
  defaultSelectedKey?: Key | null;
  onChange?: (item: Item | null) => void;
  debounce?: number;
}) {
  const [selectedItem, setSelectedItem] = useState<Item | null>(() => {
    if (defaultItems) {
      return (
        defaultItems.find((item) => getKey(item) == defaultSelectedKey) ?? null
      );
    }
    return null;
  });
  const [inputValue, setInputValue] = useState(selectedItem?.label ?? '');
  const [isExplicitlySelected, setIsExplicitlySelected] = useState(false);
  const list = useAsyncList<Item>({ getKey, load });
  // `list.error` is sticky (useAsyncList never clears it), so we track the last
  // error the user dismissed (by typing or resetting) and only surface an error
  // whose identity differs from it. A brand new failure produces a new Error
  // instance and shows again.
  const [dismissedError, setDismissedError] = useState<Error | null>(null);
  const setFilterText = useEvent((filterText: string) => {
    list.setFilterText(filterText);
  });
  const debouncedSetFilterText = useDebounceCallback(
    setFilterText,
    debounce ?? 300
  );
  const [prevDefaultSelectedKey, setPrevDefaultSelectedKey] =
    useState(defaultSelectedKey);

  const onSelectionChange = useEvent<
    NonNullable<ComboBoxProps['onSelectionChange']>
  >((key) => {
    setIsExplicitlySelected(true);
    // A freshly loaded item wins over the selected one with the same key: it carries
    // the same data, but its token is newer (the server rejects an expired one).
    const item =
      typeof key != 'string'
        ? null
        : (list.getItem(key) ??
          (selectedItem && getKey(selectedItem) == key ? selectedItem : null));
    setSelectedItem(item);
    if (item) {
      setInputValue(item.label);
    } else {
      setInputValue('');
    }
    onChange?.(item);
  });

  const onInputChange = useEvent<NonNullable<ComboBoxProps['onInputChange']>>(
    (value) => {
      setDismissedError(list.error ?? null);
      debouncedSetFilterText(value);
      setIsExplicitlySelected(false);
      setInputValue(value);
      if (value == '') {
        onSelectionChange(null);
      }
    }
  );

  const onReset = useEvent(() => {
    setSelectedItem(null);
    setInputValue('');
    setDismissedError(list.error ?? null);
  });

  const error = list.error && list.error !== dismissedError ? list.error : null;

  // add to items list current selected item if it's not in the list
  const items = error
    ? []
    : selectedItem && !list.getItem(getKey(selectedItem))
      ? [selectedItem, ...list.items]
      : list.items;

  const shouldShowPopover = useMemo(() => {
    if (!isExplicitlySelected && error) {
      return true;
    }

    if (isExplicitlySelected || list.items.length == 0) {
      return false;
    }
    // Visible while loading new items or when loaded but explicit selection not yet done
    return list.loadingState == 'filtering' || !list.isLoading;
  }, [
    list.isLoading,
    list.loadingState,
    list.items.length,
    error,
    isExplicitlySelected
  ]);

  // reset selection when the defaultSelectedKey prop changes (adjusting state
  // during render, guarded by the previous value — see
  // https://react.dev/learn/you-might-not-need-an-effect#adjusting-some-state-when-a-prop-changes)
  if (prevDefaultSelectedKey != defaultSelectedKey) {
    setPrevDefaultSelectedKey(defaultSelectedKey);
    const item = defaultSelectedKey
      ? (items.find((item) => item.value == defaultSelectedKey) ??
        defaultItems?.find((item) => item.value == defaultSelectedKey) ??
        null)
      : null;
    if (item) {
      setSelectedItem(item);
      setInputValue(item.label);
    } else {
      setSelectedItem(null);
      setInputValue('');
    }
  }

  return {
    selectedItem,
    selectedKey: selectedItem ? getKey(selectedItem) : null,
    onSelectionChange,
    inputValue,
    onInputChange,
    items,
    onReset,
    isLoading: list.isLoading,
    shouldShowPopover,
    error
  };
}

// Items from remote search (format_response) include an `id` (MD5 of data) for unique keying.
// Items from server reload (selected_items) have no `id`, so we fallback to `value`.
export function getKey(item: Item) {
  return item.id ?? item.value;
}

const AnnuaireEducationPayload = s.type({
  records: s.array(
    s.type({
      fields: s.type({
        identifiant_de_l_etablissement: s.string(),
        nom_etablissement: s.string(),
        nom_commune: s.optional(s.string())
      })
    })
  )
});

const Coerce = {
  Default: s.array(Item),
  AnnuaireEducation: s.coerce(
    s.array(Item),
    AnnuaireEducationPayload,
    ({ records }) =>
      records.map((record) => ({
        label: `${record.fields.nom_etablissement}${record.fields.nom_commune ? `, ${record.fields.nom_commune}` : ''} (${record.fields.identifiant_de_l_etablissement})`,
        value: record.fields.identifiant_de_l_etablissement,
        data: record
      }))
  )
};

export const createLoader = (
  source: string,
  options?: {
    minimumInputLength?: number;
    limit?: number;
    param?: string;
    coerce?: keyof typeof Coerce;
    usePost?: boolean;
    errorMessage?: string;
  }
): Loader => {
  return async ({ signal, filterText }) => {
    const url = new URL(source, location.href);
    const minimumInputLength = options?.minimumInputLength ?? 2;
    const param = options?.param ?? 'q';
    const limit = options?.limit ?? 10;
    const usePost = options?.usePost ?? false;
    const coerceKey = options?.coerce ?? 'Default';

    if (!filterText || filterText.length < minimumInputLength) {
      return { items: [] };
    }

    try {
      const requestOptions: {
        method: 'GET' | 'POST';
        csrf: boolean;
        signal: AbortSignal | undefined;
        json?: unknown;
      } = { method: 'GET', csrf: false, signal };

      if (usePost) {
        requestOptions.method = 'POST';
        requestOptions.csrf = true;
        requestOptions.json = { [param]: filterText };
      } else {
        url.searchParams.set(param, filterText);
      }

      const requestUrl = url.toString();

      const json = await httpRequest(requestUrl, requestOptions).json();

      if (json) {
        const struct = Coerce[coerceKey];
        const [err, items] = s.validate(json, struct, {
          coerce: true
        });
        if (err) {
          fire(document, 'sentry:capture-exception', err);
        } else {
          const filteredItems = matchSorter(items, filterText, {
            keys: [
              (item) => item.label.replace(/[_ -]/g, ' '), // accept filter to match saint martin => "Saint-Martin"
              'label' // keep original label for exact match and filter (saint-martin => Saint-Martin)
            ],
            baseSort: naturalSort,
            threshold:
              items.length > limit
                ? matchSorter.rankings.MATCHES // default filter when there are many items
                : matchSorter.rankings.NO_MATCH // don't reject items when filter contains have typos or non exact matches with dashes/space etc…
          });
          return { items: filteredItems.slice(0, limit) };
        }
      }
      return { items: [] };
    } catch (error) {
      console.error(error);
      throw new Error(options?.errorMessage ?? 'An error occurred', {
        cause: error
      });
    }
  };
};

export function useOnFormReset(onReset?: () => void) {
  const ref = useRef<HTMLInputElement>(null);
  const onResetListener = useEvent<EventListener>((event) => {
    if (event.target == ref.current?.form) {
      onReset?.();
    }
  });
  useEffect(() => {
    if (onReset) {
      addEventListener('reset', onResetListener);
      return () => {
        removeEventListener('reset', onResetListener);
      };
    }
  }, [onReset, onResetListener]);

  return ref;
}

// `data: { autosubmit_target: 'input' }` from the server becomes `data-autosubmit-target`.
export function dataAttributes(data?: Record<string, string>) {
  return Object.fromEntries(
    Object.entries(data ?? {}).map(([key, value]) => [
      `data-${key.replace(/_/g, '-')}`,
      value
    ])
  );
}

function distinctBy<T>(array: T[], key: keyof T): T[] {
  const keys = array.map((item) => item[key]);
  return array.filter((item, index) => keys.indexOf(item[key]) == index);
}
