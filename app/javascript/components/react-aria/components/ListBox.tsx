'use client';
import {
  Text,
  ListBox as AriaListBox,
  ListBoxItem as AriaListBoxItem,
  composeRenderProps,
  type ListBoxItemProps,
  type ListBoxProps
} from 'react-aria-components';
import { Check } from 'lucide-react';
import './ListBox.css';

export function ListBoxItem(props: ListBoxItemProps) {
  const textValue =
    props.textValue ||
    (typeof props.children == 'string' ? props.children : undefined);
  return (
    <AriaListBoxItem {...props} textValue={textValue}>
      {composeRenderProps(props.children, (children) =>
        typeof children == 'string' ? (
          <Text slot="label">{children}</Text>
        ) : (
          children
        )
      )}
    </AriaListBoxItem>
  );
}

export function DropdownListBox<T extends object>(props: ListBoxProps<T>) {
  return <AriaListBox {...props} className="dropdown-listbox" />;
}

export function DropdownItem(props: ListBoxItemProps) {
  const textValue =
    props.textValue ||
    (typeof props.children == 'string' ? props.children : undefined);
  return (
    <ListBoxItem {...props} textValue={textValue} className="dropdown-item">
      {composeRenderProps(props.children, (children, { isSelected }) => (
        <>
          {isSelected && <Check />}
          {typeof children === 'string' ? (
            <Text slot="label">{children}</Text>
          ) : (
            children
          )}
        </>
      ))}
    </ListBoxItem>
  );
}
