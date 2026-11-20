'use client';
import type { Ref } from 'react';
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

// The body of an option: a DSFR icon (decorative, the label names the option),
// the label, and an optional description that screen readers announce as the
// option's description. `Text` slots wire the ARIA attributes inside a
// ListBoxItem; `SelectValue` renders the same children in the trigger, where the
// icon stays and the description is hidden by Select.css.
export function DropdownItemContent({
  icon,
  label,
  description
}: {
  icon?: string;
  label: string;
  description?: string;
}) {
  return (
    <>
      {icon ? (
        <span
          className={`dropdown-item__icon ${icon} fr-icon--sm`}
          aria-hidden="true"
        />
      ) : null}
      <Text slot="label">{label}</Text>
      {description ? <Text slot="description">{description}</Text> : null}
    </>
  );
}

export function DropdownListBox<T extends object>(
  props: ListBoxProps<T> & { ref?: Ref<HTMLDivElement> }
) {
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
              className="dropdown-item__check fr-icon-check-line fr-icon--sm"
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
