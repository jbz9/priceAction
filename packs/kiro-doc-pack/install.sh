#!/usr/bin/env bash
#
# kiro-doc-pack installer
#
# Usage (from target repo root):
#   curl -fsSL https://raw.githubusercontent.com/jbz9/priceAction/main/packs/kiro-doc-pack/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/jbz9/priceAction/main/packs/kiro-doc-pack/install.sh | bash -s -- --force
#
# Env:
#   KIRO_DOC_PACK_BASE  override base URL (default: jbz9/priceAction main)
#   KIRO_DOC_PACK_REF   git ref to pull from (default: main)
#
set -euo pipefail

VERSION="1.0.0"
REF="${KIRO_DOC_PACK_REF:-main}"
BASE_URL="${KIRO_DOC_PACK_BASE:-https://raw.githubusercontent.com/jbz9/priceAction/${REF}/packs/kiro-doc-pack}"
FILES=(doc-coauthoring.md canvas-design.md theme-factory.md)
TARGET=".kiro/steering"
FORCE="no"

for arg in "$@"; do
  case "$arg" in
    --force) FORCE="yes" ;;
    --help|-h)
      sed -n '1,15p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [[ ! -d ".git" ]]; then
  echo "WARN: '.git' not found in CWD; installing into ./$TARGET anyway" >&2
fi

mkdir -p "$TARGET"

installed=0
skipped=0
for f in "${FILES[@]}"; do
  dest="$TARGET/$f"
  if [[ -e "$dest" && "$FORCE" != "yes" ]]; then
    echo "SKIP  $dest (exists; use --force to overwrite)"
    skipped=$((skipped+1))
    continue
  fi
  url="$BASE_URL/steering/$f"
  printf "GET   %-25s <- %s\n" "$f" "$url"
  if ! curl -fsSL "$url" -o "$dest.tmp"; then
    echo "FAIL  download $url" >&2
    rm -f "$dest.tmp"
    exit 1
  fi
  mv "$dest.tmp" "$dest"
  installed=$((installed+1))
  echo "OK    $dest"
done

echo
echo "kiro-doc-pack v${VERSION} installed (${installed} written, ${skipped} skipped) at $(pwd)/$TARGET"
