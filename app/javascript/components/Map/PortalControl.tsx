import type { ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { useControl, type ControlPosition } from '@vis.gl/react-maplibre';
import type { IControl } from 'maplibre-gl';

class ContainerControl implements IControl {
  readonly container = document.createElement('div');

  constructor() {
    this.container.className = 'maplibregl-ctrl maplibregl-ctrl-group ds-ctrl';
  }

  onAdd(): HTMLElement {
    return this.container;
  }

  onRemove(): void {
    this.container.remove();
  }
}

export function PortalControl({
  position,
  children
}: {
  position: ControlPosition;
  children: ReactNode;
}) {
  const control = useControl(() => new ContainerControl(), { position });
  return createPortal(children, control.container);
}
