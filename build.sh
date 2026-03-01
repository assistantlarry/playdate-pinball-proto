#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PLAYDATE_SDK_PATH:-}" ]; then
  CAND=$(find "$HOME" -maxdepth 1 -type d -name "PlaydateSDK*" | sort | tail -n1 || true)
  if [ -n "$CAND" ]; then
    PLAYDATE_SDK_PATH="$CAND"
  else
    echo "Set PLAYDATE_SDK_PATH to your Playdate SDK path" >&2
    exit 1
  fi
fi

PDC="$PLAYDATE_SDK_PATH/bin/pdc"
OUTDIR="/home/assistantlarry/playdate-builds"
mkdir -p "$OUTDIR"
"$PDC" -sdkpath "$PLAYDATE_SDK_PATH" source "$OUTDIR/PinballPrototype.pdx"
(
  cd "$OUTDIR"
  rm -f PinballPrototype.pdx.zip
  zip -r PinballPrototype.pdx.zip PinballPrototype.pdx >/dev/null
)
echo "Built $OUTDIR/PinballPrototype.pdx and zip"
