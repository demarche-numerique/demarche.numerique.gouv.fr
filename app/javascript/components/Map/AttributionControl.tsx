import { useControl } from '@vis.gl/react-maplibre';
import { AttributionControl as MapLibreAttributionControl } from 'maplibre-gl';
import type { Map } from 'maplibre-gl';

const SHOW = 'maplibregl-compact-show';

// maplibre opens the attribution with the map, and folds it as soon as the map
// is dragged: fold it from the start, behind its button.
class FoldedAttributionControl extends MapLibreAttributionControl {
  #observer?: MutationObserver;

  onAdd(map: Map): HTMLElement {
    const container = super.onAdd(map);
    // The attribution only opens once the sources told who to credit.
    this.#observer = new MutationObserver(() => this.#fold(container));
    this.#observer.observe(container, {
      attributes: true,
      attributeFilter: ['class']
    });
    this.#fold(container);
    return container;
  }

  onRemove(): void {
    this.#observer?.disconnect();
    super.onRemove();
  }

  #fold(container: HTMLElement) {
    if (container.classList.contains(SHOW)) {
      container.classList.remove(SHOW);
      // The container is a <details>: closed for a screen reader too.
      container.removeAttribute('open');
      this.#observer?.disconnect();
    }
  }
}

export function AttributionControl() {
  useControl(() => new FoldedAttributionControl(), {
    position: 'bottom-right'
  });
  return null;
}
