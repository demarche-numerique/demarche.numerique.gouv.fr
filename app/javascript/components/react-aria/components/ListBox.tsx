'use client';
import {
  Text,
  ListBox as AriaListBox,
  ListBoxItem as AriaListBoxItem,
  composeRenderProps,
  type ListBoxItemProps,
  type ListBoxProps
} from 'react-aria-components';
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

export function DropdownItem({
  className,
  ...props
}: ListBoxItemProps & { className?: string }) {
  const textValue =
    props.textValue ||
    (typeof props.children == 'string' ? props.children : undefined);
  return (
    <ListBoxItem
      {...props}
      textValue={textValue}
      className={className ? `dropdown-item ${className}` : 'dropdown-item'}
    >
      {composeRenderProps(props.children, (children, { isSelected }) => (
        <>
          {isSelected && (
            <span
              className="fr-icon-check-line fr-icon--sm"
              aria-hidden="true"
            />
          )}
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
