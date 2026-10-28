#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/env.sh"
source "$script_dir/lib/common.sh"

if (( $# > 1 )); then
  printf 'Uso: %s [windows-x64|linux-x64]\n' "$0" >&2
  exit 2
fi
platform="${1:-$(dev_env_platform)}"
dev_env_check_platform "$platform"
dev_env_require sha256sum
dev_env_require mktemp

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    git_bash_path="${CLAUDE_CODE_GIT_BASH_PATH:-}"
    if [[ -z "$git_bash_path" ]]; then
      dev_env_error 'configure CLAUDE_CODE_GIT_BASH_PATH com o caminho completo de bash.exe'
      exit 1
    fi
    if command -v cygpath >/dev/null 2>&1; then
      git_bash_path="$(cygpath -u "$git_bash_path")"
    fi
    if [[ ! -f "$git_bash_path" ]]; then
      dev_env_error "Git Bash nao encontrado em CLAUDE_CODE_GIT_BASH_PATH: $git_bash_path"
      exit 1
    fi
    ;;
esac

if [[ -f "$DEV_ENV_DOWNLOAD_DIR/artifacts/catalog.txt" ]]; then
  catalog="$DEV_ENV_DOWNLOAD_DIR/artifacts/catalog.txt"
elif [[ -f "$DEV_ENV_HOME/artifacts/catalog.txt" ]]; then
  catalog="$DEV_ENV_HOME/artifacts/catalog.txt"
else
  dev_env_error 'catalogo nao encontrado; execute download-s3.sh ou obtenha o pacote completo'
  exit 1
fi
dev_env_read_catalog "$catalog"

selected=-1
for i in "${!CATALOG_PATHS[@]}"; do
  if [[ "${CATALOG_PRODUCTS[$i]}" == claude-code && "${CATALOG_PLATFORMS[$i]}" == "$platform" ]]; then
    selected="$i"
    break
  fi
done
if (( selected < 0 )); then
  dev_env_error "CLI nao encontrada no catalogo para $platform"
  exit 1
fi

relative_path="${CATALOG_PATHS[$selected]}"
expected_hash="${CATALOG_HASHES[$selected]}"
if [[ -f "$DEV_ENV_DOWNLOAD_DIR/$relative_path" ]]; then
  source_file="$DEV_ENV_DOWNLOAD_DIR/$relative_path"
elif [[ -f "$DEV_ENV_HOME/$relative_path" ]]; then
  source_file="$DEV_ENV_HOME/$relative_path"
else
  dev_env_error "binario ausente: $relative_path; execute download-s3.sh $platform claude-code"
  exit 1
fi
if ! dev_env_verify_hash "$source_file" "$expected_hash"; then
  dev_env_error "SHA256 divergente: $source_file; instalacao cancelada"
  exit 1
fi

case "$platform" in
  windows-x64) executable=claude.exe ;;
  linux-x64) executable=claude ;;
esac
mkdir -p -- "$DEV_ENV_INSTALL_DIR"
staged_file="$(mktemp "$DEV_ENV_INSTALL_DIR/.claude.XXXXXX.part")"
cleanup() {
  [[ -z "$staged_file" ]] || rm -f -- "$staged_file"
}
trap cleanup EXIT
cp -- "$source_file" "$staged_file"
if ! dev_env_verify_hash "$staged_file" "$expected_hash"; then
  dev_env_error 'SHA256 divergente depois da copia; instalacao cancelada'
  exit 1
fi
chmod +x -- "$staged_file"
mv -f -- "$staged_file" "$DEV_ENV_INSTALL_DIR/$executable"
staged_file=''
printf 'CLI instalada e validada: %s/%s\n' "$DEV_ENV_INSTALL_DIR" "$executable"
printf 'Aplique as variaveis nesta sessao com: source "%s/env.sh"\n' "$DEV_ENV_HOME"
