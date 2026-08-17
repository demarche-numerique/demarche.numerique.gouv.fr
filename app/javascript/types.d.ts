// This file contains type definitions for untyped packages. We are lucky to have only a few ;)
declare module 'react-coordinate-input';
declare module 'chartkick';
declare module 'trix';
declare module '@rails/actiontext';

// Vite returns the compiled stylesheet as a string when imported with ?inline.
declare module '*.css?inline' {
  const content: string;
  export default content;
}

interface Window {
  // Command queue consumed by the La Suite "gaufre" widget script.
  _lasuite_widget?: unknown[];
}
