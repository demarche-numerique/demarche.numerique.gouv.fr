import type { LayerSpecification } from 'maplibre-gl';

// Same layer ids as rpg.ts on purpose: a map shows one parcelle layer at most
// (see PARCELLE_LAYERS in ../base.ts), and the editor addresses the parcelles
// by these ids whichever the source.
export const layers: LayerSpecification[] = [
  {
    id: 'batiments-line',
    type: 'line',
    source: 'cadastre',
    'source-layer': 'batiments',
    minzoom: 16,
    maxzoom: 22,
    layout: { visibility: 'visible' },
    paint: {
      'line-opacity': 1,
      'line-color': 'rgba(0, 0, 0, 1)',
      'line-width': 1
    }
  },
  {
    id: 'batiments-fill',
    type: 'fill',
    source: 'cadastre',
    'source-layer': 'batiments',
    layout: { visibility: 'visible' },
    paint: {
      'fill-color': 'rgba(150, 150, 150, 1)',
      'fill-opacity': {
        type: 'exponential',
        stops: [
          [16, 0],
          [17, 0.6]
        ]
      },
      'fill-antialias': true
    }
  },
  {
    id: 'parcelles',
    type: 'line',
    source: 'cadastre',
    'source-layer': 'parcelles',
    minzoom: 15.5,
    maxzoom: 24,
    layout: {
      visibility: 'visible',
      'line-cap': 'butt',
      'line-join': 'miter',
      'line-miter-limit': 2
    },
    paint: {
      'line-color': 'rgba(255, 255, 255, 1)',
      'line-opacity': 0.8,
      'line-width': {
        type: 'exponential',
        stops: [
          [16, 1.5],
          [17, 2]
        ]
      },
      'line-offset': 0,
      'line-blur': 0,
      'line-translate': [0, 1],
      'line-dasharray': [1],
      'line-gap-width': 0
    }
  },
  {
    id: 'parcelles-fill',
    type: 'fill',
    source: 'cadastre',
    'source-layer': 'parcelles',
    layout: {
      visibility: 'visible'
    },
    paint: {
      'fill-color': 'rgba(129, 123, 0, 1)',
      'fill-opacity': [
        'case',
        ['boolean', ['feature-state', 'hover'], false],
        0.7,
        0.1
      ]
    }
  },
  // Under the labels, so that the numero of a highlighted parcelle stays
  // readable.
  {
    id: 'parcelle-highlighted',
    type: 'fill',
    source: 'cadastre',
    'source-layer': 'parcelles',
    filter: ['in', 'id', ''],
    paint: {
      'fill-color': 'rgba(1, 129, 0, 1)',
      'fill-opacity': 0.7
    }
  },
  {
    id: 'parcelles-labels',
    type: 'symbol',
    source: 'cadastre',
    'source-layer': 'parcelles',
    minzoom: 16,
    layout: {
      visibility: 'visible',
      'text-field': ['get', 'numero'],
      'text-font': ['Noto Sans Bold'],
      'text-size': 12
    },
    paint: {
      'text-color': 'rgba(0, 0, 0, 1)',
      'text-halo-color': 'rgba(255, 255, 255, 1)',
      'text-halo-width': 1
    }
  },
  {
    id: 'sections',
    type: 'line',
    source: 'cadastre',
    'source-layer': 'sections',
    minzoom: 12,
    layout: { visibility: 'visible' },
    paint: {
      'line-color': 'rgba(0, 0, 0, 1)',
      'line-opacity': 0.7,
      'line-width': 2,
      'line-dasharray': [3, 3],
      'line-translate': [0, 0]
    }
  }
];
