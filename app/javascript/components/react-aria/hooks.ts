import { fire, httpRequest } from '@utils';
import { matchSorter, type MatchSorterOptions } from 'match-sorter';
import type { Key } from 'react';
import { useEffect, useMemo, useRef, useState } from 'react';
import type {
  ComboBoxProps as AriaComboBoxProps,
  TagGroupProps
} from 'react-aria-components';
import isEqual from 'react-fast-compare';
import { useAsyncList, type AsyncListOptions } from 'react-stately';
import { useEvent } from 'react-use-event-hook';
import * as s from 'superstruct';
import { useDebounceCallback } from 'usehooks-ts';

import { Item } from './props';

export type Loader = AsyncListOptions<Item, string>['load'];

export interface ComboBoxProps
  extends Omit<AriaComboBoxProps<Item>, 'children'> {
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

  return {
    ref,
    dispatch: () => {
      requestAnimationFrame(() => {
        if (ref.current) {
          const container = ref.current;
          const inputs = Array.from(container.querySelectorAll('input'));
          const input = inputs.at(0);
          if (input && inputChanged(container, inputs)) {
            inputCountMap.set(container, inputs.length);
            for (const input of inputs) {
              inputMap.set(input, input.value.trim());
            }
            input.dispatchEvent(new Event('change', { bubbles: true }));
          }
        }
      });
    }
  };
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

export function useSingleList({
  defaultItems,
  defaultSelectedKey,
  emptyFilterKey,
  onChange
}: {
  defaultItems?: Item[];
  defaultSelectedKey?: string | null;
  emptyFilterKey?: string | null;
  onChange?: (item: Item | null) => void;
}) {
  const [selectedKey, setSelectedKey] = useState(defaultSelectedKey);
  const items = useMemo(
    () => (defaultItems ? distinctBy(defaultItems, 'value') : []),
    [defaultItems]
  );
  const selectedItem = useMemo(
    () => items.find((item) => item.value == selectedKey) ?? null,
    [items, selectedKey]
  );
  const [inputValue, setInputValue] = useState(() => selectedItem?.label ?? '');
  // show fallback item when input value is not matching any items
  const fallbackItem = useMemo(
    () => items.find((item) => item.value == emptyFilterKey),
    [items, emptyFilterKey]
  );
  const filteredItems = useMemo(() => {
    if (inputValue == '') {
      return items;
    }
    const filteredItems = matchSorter(items, inputValue, {
      keys: ['label'],
      baseSort: naturalSort
    });
    if (filteredItems.length == 0 && fallbackItem) {
      return [fallbackItem];
    } else {
      return filteredItems;
    }
  }, [items, inputValue, fallbackItem]);

  const initialSelectedKeyRef = useRef(defaultSelectedKey);

  const setSelection = useEvent((key?: string | null) => {
    const inputValue = key
      ? items.find((item) => item.value == key)?.label
      : '';
    setSelectedKey(key);
    setInputValue(inputValue ?? '');
  });
  const onSelectionChange = useEvent<
    NonNullable<ComboBoxProps['onSelectionChange']>
  >((key) => {
    setSelection(key ? String(key) : null);
    const item =
      (typeof key != 'string'
        ? null
        : selectedItem?.value == key
          ? selectedItem
          : items.find((item) => item.value == key)) ?? null;
    onChange?.(item);
  });
  const onInputChange = useEvent<NonNullable<ComboBoxProps['onInputChange']>>(
    (value) => {
      setInputValue(value);
      if (value == '') {
        onSelectionChange(null);
      }
    }
  );
  const onReset = useEvent(() => {
    setSelectedKey(null);
    setInputValue('');
  });

  // reset default selected key when props change
  useEffect(() => {
    if (initialSelectedKeyRef.current != defaultSelectedKey) {
      initialSelectedKeyRef.current = defaultSelectedKey;
      setSelection(defaultSelectedKey);
    }
  }, [defaultSelectedKey, setSelection]);

  return {
    selectedItem,
    selectedKey,
    onSelectionChange,
    inputValue,
    onInputChange,
    items: filteredItems,
    onReset
  };
}

export function useMultiList({
  defaultItems,
  defaultSelectedKeys,
  allowsCustomValue,
  valueSeparator,
  onChange,
  focusInput,
  formValue,
  keepSelectedItems = false
}: {
  defaultItems?: Item[];
  defaultSelectedKeys?: string[];
  allowsCustomValue?: boolean;
  valueSeparator?: string | false;
  onChange?: () => void;
  focusInput?: () => void;
  formValue?: 'text' | 'key';
  keepSelectedItems?: boolean;
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

  const visibleItems = useMemo(() => {
    return keepSelectedItems
      ? items
      : items.filter((item) => !selectedKeys.has(item.value));
  }, [items, selectedKeys, keepSelectedItems]);

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

  const onRemove = useEvent<NonNullable<TagGroupProps['onRemove']>>(
    (removedKeys) => {
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
    }
  );

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
  const [error, setError] = useState<Error | null>(null);
  const setFilterText = useEvent((filterText: string) => {
    list.setFilterText(filterText);
  });
  const debouncedSetFilterText = useDebounceCallback(
    setFilterText,
    debounce ?? 300
  );
  const initialSelectedKeyRef = useRef(defaultSelectedKey);

  const onSelectionChange = useEvent<
    NonNullable<ComboBoxProps['onSelectionChange']>
  >((key) => {
    setIsExplicitlySelected(true);
    const item =
      (typeof key != 'string'
        ? null
        : selectedItem && getKey(selectedItem) == key
          ? selectedItem
          : list.getItem(key)) ?? null;
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
      setError(null);
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
    setError(null);
  });

  useEffect(() => {
    if (list.error) {
      setError(list.error);
    }
  }, [list.error]);

  useEffect(() => {
    if (!list.isLoading && !list.error) {
      setError(null);
    }
  }, [list.isLoading, list.error]);

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

  // reset default selected key when props change
  useEffect(() => {
    if (initialSelectedKeyRef.current != defaultSelectedKey) {
      initialSelectedKeyRef.current = defaultSelectedKey;
      const item = defaultSelectedKey
        ? items.find((item) => item.value == defaultSelectedKey)
        : null;
      if (item) {
        setSelectedItem(item);
        setInputValue(item.label);
      } else {
        setSelectedItem(null);
        setInputValue('');
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [defaultSelectedKey]);

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

function distinctBy<T>(array: T[], key: keyof T): T[] {
  const keys = array.map((item) => item[key]);
  return array.filter((item, index) => keys.indexOf(item[key]) == index);
}
