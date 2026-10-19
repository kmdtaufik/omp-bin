#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

repo="can1357/oh-my-pi"
assets=(
  "x86_64-linux:omp-linux-x64"
  "aarch64-linux:omp-linux-arm64"
)

auth=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

version="${1:-}"
if [ -z "$version" ]; then
  version="$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)"
  version="${version#v}"
  current="$(jq -r .version source.json)"
  if [ "$version" = "$current" ]; then
    echo "already at $version" >&2
    exit 0
  fi
fi
version="${version#v}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

entries=()
for entry in "${assets[@]}"; do
  system="${entry%%:*}"
  asset="${entry#*:}"
  url="https://github.com/$repo/releases/download/v$version/$asset"
  echo "fetching $url" >&2
  curl -fsSL "$url" -o "$tmp/$asset"
  hash="sha256-$(sha256sum "$tmp/$asset" | cut -d' ' -f1 | xxd -r -p | base64 -w0)"
  entries+=("$system" "$url" "$hash")
done

{
  printf '{\n  "version": "%s",\n  "assets": {\n' "$version"
  for ((i = 0; i < ${#entries[@]}; i += 3)); do
    printf '    "%s": {\n      "url": "%s",\n      "hash": "%s"\n    }' \
      "${entries[i]}" "${entries[i + 1]}" "${entries[i + 2]}"
    if ((i + 3 < ${#entries[@]})); then
      printf ','
    fi
    printf '\n'
  done
  printf '  }\n}\n'
} > source.json

echo "updated source.json to $version" >&2
