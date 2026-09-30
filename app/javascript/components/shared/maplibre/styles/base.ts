import type {
  LayerSpecification,
  RasterLayerSpecification,
  RasterSourceSpecification,
  StyleSpecification
} from 'maplibre-gl';
import invariant from 'tiny-invariant';

import { layers as cadastreLayers } from './layers/cadastre.ts';
import { layers as rpgLayers } from './layers/rpg.ts';

// The parcelle layers, mirroring CarteTypeDeChamp::PARCELLE_LAYERS: a champ
// enables at most one of them, which is why their layers share their ids. The
// parcelles of a dossier are never drawn from their geometry: the tiles'
// parcelles are highlighted through the filter of the `parcelle-highlighted`
// layer, by the id property below.
export const PARCELLE_LAYERS = {
  cadastres: { source: 'cadastre', idProperty: 'id', layers: cadastreLayers },
  rpg: { source: 'rpg', idProperty: 'ID_PARCEL', layers: rpgLayers }
} as const;

export type ParcelleLayer = keyof typeof PARCELLE_LAYERS;

export function isParcelleLayer(id: string): id is ParcelleLayer {
  return id in PARCELLE_LAYERS;
}

// The parcelle layer among the enabled ones, if any.
export function getParcelleLayer(ids: string[]): ParcelleLayer | undefined {
  const parcelleLayers = ids.filter(isParcelleLayer);
  invariant(
    parcelleLayers.length <= 1,
    `A map shows one parcelle layer at most, got ${parcelleLayers.join(', ')}`
  );
  return parcelleLayers[0];
}

// Hidden layers closing every basemap: the layers added by the map components
// are inserted before them, so their order never depends on which component
// got to add its layer first.
export const ANCHORS = {
  optionalLayers: 'anchor-optional-layers',
  selections: 'anchor-selections'
} as const;

export const anchorLayers: LayerSpecification[] = Object.values(ANCHORS).map(
  (id) => ({ id, type: 'background', layout: { visibility: 'none' } })
);

// The attribution of a source set here wins over the one of its TileJSON, and
// maplibre shows an attribution once, when it is repeated word for word or is
// part of a longer one: the same credit must read the same on every source.
const CREDITS = {
  dinum: '<a href="https://www.data.gouv.fr/">© DINUM (data.gouv.fr)</a>',
  openstreetmap:
    '<a href="https://www.openstreetmap.org/copyright">© Contributeurs OpenStreetMap</a>',
  openmaptiles: '<a href="https://www.openmaptiles.org/">© OpenMapTiles</a>',
  ign: '<a href="https://www.ign.fr/">© IGN</a>',
  // The protected areas are drawn by PatriNat, the OFB-MNHN-CNRS-IRD unit
  // behind the INPN, and only served by the IGN.
  patrinat: '<a href="https://inpn.mnhn.fr/">© PatriNat (OFB-MNHN-CNRS-IRD)</a>'
};

function ignServiceURL(layer: string, style: string, format = 'image/png') {
  const url = `https://data.geopf.fr/wmts`;
  const query =
    'service=WMTS&request=GetTile&version=1.0.0&tilematrixset=PM&tilematrix={z}&tilecol={x}&tilerow={y}';

  return `${url}?${query}&layer=${layer}&format=${format}&style=${style}`;
}

const OPTIONAL_LAYERS: { label: string; id: string; layers: string[][] }[] = [
  {
    label: 'UNESCO',
    id: 'unesco',
    layers: [
      ['Aires protégées Géoparcs', 'Patrinat_GEOPARC', 'normal'],
      ['Réserves de biosphère', 'Patrinat_BIOS', 'normal']
    ]
  },
  {
    label: 'Arrêtés de protection',
    id: 'arretes_protection',
    layers: [
      ['Arrêtés de protection de biotope', 'Patrinat_APB', 'normal'],
      ['Arrêtés de protection de géotope', 'Patrinat_APG', 'normal']
    ]
  },
  {
    label: 'Conservatoire du Littoral',
    id: 'conservatoire_littoral',
    layers: [
      [
        'Conservatoire du littoral : parcelles protégées',
        'CONSERVATOIRE_LITTORAL.PARCELLES',
        'normal'
      ],
      [
        'Conservatoire du littoral : périmètres d’intervention',
        'CONSERVATOIRE_LITTORAL.PERIMETRES',
        'normal'
      ]
    ]
  },
  {
    label: 'Réserves nationales de chasse et de faune sauvage',
    id: 'reserves_chasse_faune_sauvage',
    layers: [
      [
        'Réserves nationales de chasse et de faune sauvage',
        'Patrinat_RNCFS',
        'normal'
      ]
    ]
  },
  {
    label: 'Réserves biologiques',
    id: 'reserves_biologiques',
    layers: [['Réserves biologiques', 'Patrinat_RB', 'normal']]
  },
  {
    label: 'Réserves naturelles',
    id: 'reserves_naturelles',
    layers: [
      ['Réserves naturelles nationales', 'Patrinat_RNN', 'normal'],
      [
        'Périmètres de protection de réserves naturelles',
        'Patrinat_PPRNN',
        'normal'
      ],
      ['Réserves naturelles de Corse', 'Patrinat_RNC', 'normal'],
      ['Réserves naturelles régionales', 'Patrinat_RNR', 'normal']
    ]
  },
  {
    label: 'Natura 2000',
    id: 'natura_2000',
    layers: [
      ['Sites Natura 2000 (Directive Habitats)', 'Patrinat_SIC', 'normal'],
      ['Sites Natura 2000 (Directive Oiseaux)', 'Patrinat_ZPS', 'normal']
    ]
  },
  {
    label: 'Zones humides d’importance internationale',
    id: 'zones_humides',
    layers: [
      ['Zones humides d’importance internationale', 'Patrinat_RAMSAR', 'normal']
    ]
  },
  {
    label: 'ZNIEFF',
    id: 'znieff',
    layers: [
      [
        'Zones naturelles d’intérêt écologique faunistique et floristique de type 1 (ZNIEFF 1 mer)',
        'Patrinat_ZNIEFF1_MER',
        'normal'
      ],
      [
        'Zones naturelles d’intérêt écologique faunistique et floristique de type 1 (ZNIEFF 1)',
        'Patrinat_ZNIEFF1',
        'normal'
      ],
      [
        'Zones naturelles d’intérêt écologique faunistique et floristique de type 2 (ZNIEFF 2 mer)',
        'Patrinat_ZNIEFF2_MER',
        'normal'
      ],
      [
        'Zones naturelles d’intérêt écologique faunistique et floristique de type 2 (ZNIEFF 2)',
        'Patrinat_ZNIEFF2',
        'normal'
      ]
    ]
  },
  {
    label: 'Cadastre',
    id: 'cadastres',
    layers: [
      ['Cadastre', 'CADASTRE', 'DECALAGE DE LA REPRESENTATION CADASTRALE']
    ]
  },
  {
    label: 'RPG',
    id: 'rpg',
    layers: [['RPG', 'RPG', 'DECALAGE DE LA REPRESENTATION CADASTRALE']]
  }
];

// `cadastre` and `rpg` back the two parcelle layers, and nothing else. Declare
// them only when their layer is enabled, instead of in the base style: a source
// that never loads leaves the style permanently "not loaded", which downgrades
// subsequent setStyle() calls to a full reload — aborting and refetching every
// tile in flight.
export function buildOptionalSources(
  ids: string[]
): StyleSpecification['sources'] {
  const sources: StyleSpecification['sources'] = {};

  switch (getParcelleLayer(ids)) {
    case 'cadastres':
      sources[PARCELLE_LAYERS.cadastres.source] = {
        type: 'vector',
        url: 'https://openmaptiles.geo.data.gouv.fr/data/cadastre.json',
        attribution: CREDITS.dinum
      };
      break;
    case 'rpg':
      sources[PARCELLE_LAYERS.rpg.source] = {
        type: 'vector',
        url: 'pmtiles://https://pmtiles-data.s3.rbx.io.cloud.ovh.net/rpg_2023.pmtiles',
        attribution: CREDITS.ign
      };
      break;
  }

  return sources;
}

function buildSources() {
  return Object.fromEntries(
    OPTIONAL_LAYERS.filter(({ id }) => !isParcelleLayer(id))
      .flatMap(({ layers }) => layers)
      .map(([, code, style]) => [
        getLayerCode(code),
        rasterSource([ignServiceURL(code, style)], CREDITS.patrinat)
      ])
  );
}

function rasterSource(
  tiles: string[],
  attribution: string
): RasterSourceSpecification {
  return {
    type: 'raster',
    tiles,
    tileSize: 256,
    attribution,
    minzoom: 0,
    maxzoom: 18
  };
}

function rasterLayer(
  source: string,
  opacity: number
): RasterLayerSpecification {
  return {
    id: source,
    source,
    type: 'raster',
    paint: { 'raster-resampling': 'linear', 'raster-opacity': opacity }
  };
}

// `highlighted` holds the ids of the parcelles to highlight; without it, the
// filter of `parcelle-highlighted` is left to the caller (the editor sets it).
export function buildOptionalLayers(
  ids: string[],
  opacity: Record<string, number>,
  highlighted?: string[]
): LayerSpecification[] {
  const parcelleLayer = getParcelleLayer(ids);

  return OPTIONAL_LAYERS.filter(({ id }) => ids.includes(id))
    .flatMap(({ layers, id }) =>
      layers.map(([, code]) => [code, opacity[id] / 100] as const)
    )
    .flatMap(([code, opacity]) => {
      if (code == 'CADASTRE' || code == 'RPG') {
        invariant(parcelleLayer, `No parcelle layer for ${code}`);
        return parcelleLayers(PARCELLE_LAYERS[parcelleLayer], highlighted);
      }
      return [rasterLayer(getLayerCode(code), opacity)];
    });
}

function parcelleLayers(
  { idProperty, layers }: (typeof PARCELLE_LAYERS)[ParcelleLayer],
  highlighted?: string[]
): LayerSpecification[] {
  if (!highlighted) {
    return layers;
  }
  return layers.map((layer) =>
    layer.id == 'parcelle-highlighted'
      ? {
          ...layer,
          filter: ['in', ['get', idProperty], ['literal', highlighted]]
        }
      : layer
  );
}

export const NBS = ' ' as const;

export function getLayerName(layer: string): string {
  const name = OPTIONAL_LAYERS.find(({ id }) => id == layer);
  invariant(name, `Layer "${layer}" not found`);
  return name.label.replace(/\s/g, NBS);
}

function getLayerCode(code: string) {
  return code.toLowerCase().replace(/\./g, '-');
}

export const style: StyleSpecification = {
  version: 8,
  metadata: {
    'mapbox:autocomposite': false,
    'mapbox:groups': {
      1444849242106.713: { collapsed: false, name: 'Places' },
      1444849334699.1902: { collapsed: true, name: 'Bridges' },
      1444849345966.4436: { collapsed: false, name: 'Roads' },
      1444849354174.1904: { collapsed: true, name: 'Tunnels' },
      1444849364238.8171: { collapsed: false, name: 'Buildings' },
      1444849382550.77: { collapsed: false, name: 'Water' },
      1444849388993.3071: { collapsed: false, name: 'Land' }
    },
    'mapbox:type': 'template',
    'openmaptiles:mapbox:owner': 'openmaptiles',
    'openmaptiles:mapbox:source:url': 'mapbox://openmaptiles.4qljc88t',
    'openmaptiles:version': '3.x',
    'maputnik:renderer': 'mbgljs'
  },
  center: [0, 0],
  zoom: 1,
  bearing: 0,
  pitch: 0,
  sources: {
    'decoupage-administratif': {
      type: 'vector',
      url: 'https://openmaptiles.geo.data.gouv.fr/data/decoupage-administratif.json',
      attribution: CREDITS.dinum
    },
    openmaptiles: {
      type: 'vector',
      url: 'https://openmaptiles.geo.data.gouv.fr/data/france-vector.json',
      attribution: `${CREDITS.openstreetmap} ${CREDITS.openmaptiles} ${CREDITS.dinum}`
    },
    'photographies-aeriennes': rasterSource(
      [ignServiceURL('ORTHOIMAGERY.ORTHOPHOTOS', 'normal', 'image/jpeg')],
      CREDITS.ign
    ),
    'plan-ign': rasterSource(
      [ignServiceURL('GEOGRAPHICALGRIDSYSTEMS.PLANIGNV2', 'normal')],
      CREDITS.ign
    ),
    ...buildSources()
  },
  sprite: 'https://openmaptiles.github.io/osm-bright-gl-style/sprite',
  glyphs: 'https://openmaptiles.geo.data.gouv.fr/fonts/{fontstack}/{range}.pbf',
  layers: []
};
