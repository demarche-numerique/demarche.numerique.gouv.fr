#!/usr/bin/env bash
# Recette guidée au lecteur d'écran : filme tout l'écran avec la voix de VoiceOver
# (sortie multiple → BlackHole), pendant que recette.mjs tourne en mode guide.
# Usage, depuis ../review-pr-N :
#   voiceover.sh --check                                  vérifie la configuration du Mac
#   voiceover.sh tmp/recette/scenario.mjs [options recette.mjs]   (--base-url, --out…)
# Produit tmp/recette/recette-voiceover.mp4 et tmp/recette/parole.txt (plages où VoiceOver parle).
set -uo pipefail

SKILL="$(cd "$(dirname "$0")" && pwd)"
AUDIO="${RECETTE_AUDIO_DEVICE:-BlackHole 2ch}"
ECRAN="${RECETTE_ECRAN:-Capture screen 0}"

check() {
  local ok=0
  echo "Configuration VoiceOver de la recette :"
  if system_profiler SPAudioDataType 2>/dev/null | grep -q "$AUDIO:"; then
    echo "  ✓ pilote audio « $AUDIO »"
  else
    echo "  ✗ pas de « $AUDIO » : brew install blackhole-2ch, puis redémarrer le Mac"; ok=1
  fi
  if system_profiler SPAudioDataType 2>/dev/null | grep -qiE "sortie multiple|multi-output"; then
    echo "  ✓ appareil à sorties multiples"
  else
    echo "  ✗ pas d'appareil à sorties multiples (Configuration audio et MIDI > + > casque + $AUDIO)"; ok=1
  fi
  local png; png="$(mktemp -t recette-ecran).png"
  if screencapture -x "$png" 2>/dev/null; then
    echo "  ✓ enregistrement de l'écran autorisé pour ce terminal"
  else
    echo "  ✗ enregistrement de l'écran refusé : Réglages Système > Confidentialité > Enregistrement de l'écran, cocher le terminal, puis le quitter (⌘Q) et le rouvrir"; ok=1
  fi
  rm -f "$png"
  command -v ffmpeg >/dev/null && echo "  ✓ ffmpeg" || { echo "  ✗ ffmpeg absent : brew install ffmpeg"; ok=1; }
  echo "  ? à vérifier à la main, Utilitaire VoiceOver : Son > Périphérique de sortie = l'appareil à sorties multiples ;"
  echo "    Effets visuels > panneau des sous-titres affiché (le texte dit par VoiceOver apparaît dans la vidéo)"
  return $ok
}

if [ "${1:-}" = "--check" ]; then check; exit $?; fi
SCENARIO="${1:?usage: voiceover.sh --check | voiceover.sh <scenario.mjs> [options recette.mjs]}"; shift
check >/dev/null || { check; exit 1; }

DIR="$(dirname "$SCENARIO")"
VIDEO="$DIR/recette-voiceover.mp4"   # hors du dossier de résultats, que recette.mjs vide au départ
PAROLE="$DIR/parole.txt"

# nv12 : avfoundation refuse yuv420p en entrée ; SIGINT à la fin pour un mp4 finalisé.
ffmpeg -hide_banner -loglevel error -y -f avfoundation -pixel_format nv12 -framerate 30 -capture_cursor 1 \
  -i "$ECRAN:$AUDIO" -c:v libx264 -preset veryfast -pix_fmt yuv420p -vf "scale=1280:-2" \
  -c:a aac "$VIDEO" 2> >(grep -v NSKVONotifying >&2) &
FFMPEG=$!

node "$SKILL/recette.mjs" "$SCENARIO" --mode guide --out "$DIR/resultats-voiceover" "$@"

kill -INT "$FFMPEG"; wait "$FFMPEG"

# Plages de parole : ce sont les instants à regarder pour lire les sous-titres de VoiceOver.
ffmpeg -hide_banner -i "$VIDEO" -vn -af silencedetect=n=-50dB:d=1 -f null - 2>&1 \
  | sed -nE 's/.*silence_(start|end): ([0-9.]+).*/\1 \2/p' \
  | LC_ALL=C awk 'BEGIN { debut = 0 } $1 == "start" { if ($2 > debut + 0.3) printf "parole %6.1f s → %6.1f s\n", debut, $2 } $1 == "end" { debut = $2 }
         END { if (debut > 0) printf "parole %6.1f s → fin\n", debut }' > "$PAROLE"
echo "vidéo : $VIDEO"
echo "parole : $PAROLE"
[ -s "$PAROLE" ] || echo "⚠ aucune parole détectée : VoiceOver n'a pas été activé, ou sa sortie ne passe pas par $AUDIO"
