'use client';
import {
  Button,
  Input,
  SearchField as AriaSearchField,
  type SearchFieldProps as AriaSearchFieldProps
} from 'react-aria-components';
import { Search, X } from 'lucide-react';
import './SearchField.css';

export interface SearchFieldProps extends AriaSearchFieldProps {
  placeholder?: string;
}

export function SearchField({ placeholder, ...props }: SearchFieldProps) {
  return (
    <AriaSearchField {...props}>
      <Search size={18} />
      <Input placeholder={placeholder} className="react-aria-Input fr-input" />
      <Button className="clear-button">
        <X size={14} />
      </Button>
    </AriaSearchField>
  );
}
