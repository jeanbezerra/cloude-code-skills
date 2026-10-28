#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/env.sh"
source "$script_dir/lib/common.sh"

if (( $# > 2 )); then
  printf 'Uso: %s [windows-x64|linux-x64] [all|claude-code|claude-desktop]\n' "$0" >&2
  exit 2
fi
platform="${1:-$(dev_env_platform)}"
product="${2:-all}"
dev_env_check_platform "$platform"
case "$product" in
  all|claude-code|claude-desktop) ;;
  *) dev_env_error "produto invalido: $product"; exit 2 ;;
esac
dev_env_require curl
dev_env_require sha256sum
dev_env_require mktemp
case "$S3_BASE_URL" in
  https://?*) ;;
  *) dev_env_error 'configure S3_BUCKET ou S3_BASE_URL com um endpoint HTTPS em env.local.sh'; exit 2 ;;
esac
base_url="${S3_BASE_URL%/}"
catalog_source="${DEV_ENV_CATALOG:-$DEV_ENV_HOME/artifacts/catalog.txt}"
if command -v cygpath >/dev/null 2>&1; then
  catalog_source="$(cygpath -u "$catalog_source")"
fi
if [[ ! -f "$catalog_source" ]]; then
  dev_env_error "catalogo local ausente: $catalog_source; copie artifacts/catalog.txt junto com o kit"
  exit 1
fi

mkdir -p -- "$DEV_ENV_DOWNLOAD_DIR"
catalog_temp="$(mktemp "$DEV_ENV_DOWNLOAD_DIR/.catalog.XXXXXX.part")"
part_file=''
cleanup() {
  [[ -z "$catalog_temp" ]] || rm -f -- "$catalog_temp"
  [[ -z "$part_file" ]] || rm -f -- "$part_file"
}
trap cleanup EXIT

fetch_https() {
  curl --fail --show-error --location --proto '=https' --proto-redir '=https' \
    --retry 3 --retry-delay 2 --connect-timeout 30 --output "$2" "$1"
}

printf 'Usando catalogo local: %s\n' "$catalog_source"
cp -- "$catalog_source" "$catalog_temp"
dev_env_read_catalog "$catalog_temp"

matches=0
for i in "${!CATALOG_PATHS[@]}"; do
  [[ "${CATALOG_PLATFORMS[$i]}" == "$platform" ]] || continue
  [[ "$product" == all || "${CATALOG_PRODUCTS[$i]}" == "$product" ]] || continue
  matches=$((matches + 1))
  relative_path="${CATALOG_PATHS[$i]}"
  expected_hash="${CATALOG_HASHES[$i]}"
  destination="$DEV_ENV_DOWNLOAD_DIR/$relative_path"
  if [[ -f "$destination" ]] && dev_env_verify_hash "$destination" "$expected_hash"; then
    printf 'Ja validado: %s\n' "$relative_path"
    continue
  fi
  mkdir -p -- "$(dirname -- "$destination")"
  part_file="$(mktemp "$destination.XXXXXX.part")"
  printf 'Baixando %s\n' "$relative_path"
  fetch_https "$base_url/$relative_path" "$part_file"
  if ! dev_env_verify_hash "$part_file" "$expected_hash"; then
    dev_env_error "SHA256 divergente: $relative_path; download descartado"
    exit 1
  fi
  mv -f -- "$part_file" "$destination"
  part_file=''
done

if (( matches == 0 )); then
  dev_env_error "nenhum artefato encontrado para $platform / $product"
  exit 1
fi
mkdir -p -- "$DEV_ENV_DOWNLOAD_DIR/artifacts"
mv -f -- "$catalog_temp" "$DEV_ENV_DOWNLOAD_DIR/artifacts/catalog.txt"
catalog_temp=''
printf 'Download concluido e SHA256 validado em %s\n' "$DEV_ENV_DOWNLOAD_DIR"
