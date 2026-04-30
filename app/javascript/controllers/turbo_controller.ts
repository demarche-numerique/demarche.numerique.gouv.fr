import { session as TurboSession, type StreamElement } from '@hotwired/turbo';
import { Actions } from 'coldwired/actions';
import { createReactPlugin, createRoot, type Root } from 'coldwired/react';
import { parseTurboStream } from 'coldwired/turbo-stream';
import { makeRetriable } from 'p-retry';
import type { ComponentType } from 'react';
import invariant from 'tiny-invariant';

import { ApplicationController } from './application_controller';

type StreamRenderEvent = CustomEvent<{
  render(streamElement: StreamElement): void;
}>;

type FrameRenderEvent = CustomEvent<{
  render(currentElement: Element, newElement: Element): void;
}>;

export class TurboController extends ApplicationController {
  static targets = ['spinner'];

  declare readonly spinnerTargets: HTMLElement[];

  #submitting = false;
  #actions?: Actions;
  #root?: Root;

  // `actions` instrface exposes all available actions as methods and also `applyActions` method
  // wich allows to apply a batch of actions. On top of regular `turbo-stream` actions we also
  // expose `focus`, `enable`, `disable`, `show` and `hide` actions. Each action take a `targets`
  // option (wich can be a CSS selector or a list of DOM nodes) and a `fragment` option (wich is a
  // `DocumentFragment` and only required on "rendering" actions).
  get actions() {
    invariant(this.#actions, 'Actions not initialized');
    return this.#actions;
  }

  connect() {
    this.#root = createRoot({
      layoutComponentName: 'Layout/Layout',
      loader,
      schema: {
        fragmentTagName: 'react-fragment',
        componentTagName: 'react-component',
        slotTagName: 'react-slot',
        loadingClassName: 'loading'
      }
    });
    const plugin = createReactPlugin(this.#root);
    this.#actions = new Actions({
      element: document.body,
      schema: {
        forceAttribute: 'data-turbo-force',
        focusGroupAttribute: 'data-turbo-focus-group',
        focusDirectionAttribute: 'data-turbo-focus-direction',
        hiddenClassName: 'hidden'
      },
      plugins: [plugin],
      debug: false
    });

    // actions#observe() is an interface over specialized mutation observers.
    // They allow us to preserve certain HTML changes across mutations.
    this.#actions.observe();

    this.#actions.ready().then(() => {
      document.body.classList.add('dom-ready');
    });

    // setup spinner events
    this.onGlobal('turbo:submit-start', () => this.startSpinner());
    this.onGlobal('turbo:submit-end', () => this.stopSpinner());
    this.onGlobal('turbo:fetch-request-error', () => this.stopSpinner());

    // prevent scroll on turbo form submits
    this.onGlobal('turbo:render', () => this.preventScrollIfNeeded());

    // see: https://turbo.hotwired.dev/handbook/streams#custom-actions
    this.onGlobal('turbo:before-stream-render', (event: StreamRenderEvent) => {
      event.detail.render = (streamElement: StreamElement) =>
        this.actions.applyActions([parseTurboStream(streamElement)]);
    });

    // see: https://turbo.hotwired.dev/handbook/frames#custom-rendering
    this.onGlobal('turbo:before-frame-render', (event: FrameRenderEvent) => {
      event.detail.render = (currentElement, newElement) => {
        // There is a bug in morphdom when it comes to mutate a custom element. It will miserably
        // crash. We mutate its content instead.
        const fragment = document.createDocumentFragment();
        fragment.append(...newElement.childNodes);
        this.actions.update({ targets: [currentElement], fragment });
      };
    });
  }

  disconnect(): void {
    this.#actions?.disconnect();
    this.#root?.destroy();
  }

  private startSpinner() {
    this.#submitting = true;
    this.actions.show({ targets: this.spinnerTargets });
  }

  private stopSpinner() {
    this.#submitting = false;
    this.actions.hide({ targets: this.spinnerTargets });
  }

  private preventScrollIfNeeded() {
    if (this.#submitting && TurboSession.navigator.currentVisit) {
      TurboSession.navigator.currentVisit.scrolled = true;
    }
  }
}

type Loader = (exportName: string) => Promise<ComponentType<unknown>>;
const componentsRegistry: Record<string, Loader> = {};
const components = import.meta.glob<Record<string, ComponentType<unknown>>>(
  '../components/*.tsx'
);

const loader: Loader = (name) => {
  const [moduleName, exportName] = name.split('/');
  const loader = componentsRegistry[moduleName];
  invariant(loader, `Cannot find a React component with name "${name}"`);
  return loader(exportName ?? 'default');
};

for (const [path, loader] of Object.entries(components)) {
  const [filename] = path.split('/').reverse();
  const componentClassName = filename.replace(/\.(ts|tsx)$/, '');
  console.debug(`Registered lazy export for "${componentClassName}" component`);
  const retriableLoader = makeRetriable(loader);
  componentsRegistry[componentClassName] = (exportName) =>
    retriableLoader().then((mod) => mod[exportName]);
}
