import { vi, suite, test, expect, beforeEach, afterEach } from 'vite-plus/test';
import type { Root } from 'react-dom/client';

import { createAppRoot } from '../../../test/react';

type Handler = () => void;

const maps: FakeMap[] = [];

class FakeMap {
  handlers = new Map<string, Handler[]>();

  constructor() {
    maps.push(this);
  }

  addControl(control: { onAdd?: () => HTMLElement }) {
    control.onAdd?.();
    return this;
  }

  on(event: string, handler: Handler) {
    this.handlers.set(event, [...(this.handlers.get(event) ?? []), handler]);
    return this;
  }

  once(event: string, handler: Handler) {
    const wrapper = () => {
      this.off(event, wrapper);
      handler();
    };
    return this.on(event, wrapper);
  }

  off(event: string, handler: Handler) {
    this.handlers.set(
      event,
      (this.handlers.get(event) ?? []).filter((h) => h != handler)
    );
    return this;
  }

  fire(event: string) {
    for (const handler of this.handlers.get(event) ?? []) {
      handler();
    }
  }

  setStyle() {}
}

vi.mock('maplibre-gl', () => ({
  Map: FakeMap,
  NavigationControl: class {},
  addProtocol() {},
  setWorkerUrl() {}
}));

const { MapLibre } = await import('./MapLibre');

suite('MapLibre', () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    maps.length = 0;
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue({
      getParameter() {}
    } as unknown as WebGL2RenderingContext);
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createAppRoot(container);
  });

  afterEach(() => {
    root.unmount();
    container.remove();
    vi.restoreAllMocks();
  });

  test('renders its layers once the style is loaded, without waiting for every tile', async () => {
    root.render(
      <MapLibre layers={[]}>
        <p data-testid="layer">layer</p>
      </MapLibre>
    );

    const map = await vi.waitFor(() => {
      expect(maps).toHaveLength(1);
      return maps[0];
    });
    expect(container.querySelector('[data-testid="layer"]')).toBeNull();

    map.fire('style.load');

    await vi.waitFor(() =>
      expect(container.querySelector('[data-testid="layer"]')).not.toBeNull()
    );
  });
});
