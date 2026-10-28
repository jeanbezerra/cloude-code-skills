#!/usr/bin/env bash
# Internal helpers shared by the Git Bash/Linux entry points.

dev_env_error() {
  printf 'Erro: %s\n' "$*" >&2
}

dev_env_require() {
  command -v "$1" >/dev/null 2>&1 || {
    dev_env_error "comando necessario nao encontrado: $1"
    return 1
  }
}

dev_env_platform() {
  local machine os
  machine="$(uname -m)" || return 1
  case "$machine" in
    x86_64|amd64|AMD64) ;;
    *) dev_env_error "arquitetura nao suportada: $machine (este pacote usa x64)"; return 1 ;;
  esac
  os="$(uname -s)" || return 1
  case "$os" in
    MINGW*|MSYS*|CYGWIN*) printf '%s\n' windows-x64 ;;
    Linux*) printf '%s\n' linux-x64 ;;
    *) dev_env_error "sistema nao suportado: $os"; return 1 ;;
  esac
}

dev_env_check_platform() {
  case "$1" in
    windows-x64|linux-x64) ;;
    *) dev_env_error "plataforma invalida: $1 (use windows-x64 ou linux-x64)"; return 1 ;;
  esac
}

dev_env_verify_hash() {
  local actual
  actual="$(sha256sum -- "$1")" || return 1
  actual="${actual%% *}"
  [[ "${actual,,}" == "${2,,}" ]]
}

dev_env_read_catalog() {
  local catalog_line row_product row_platform relative_path expected_hash seen key
  CATALOG_PRODUCTS=()
  CATALOG_PLATFORMS=()
  CATALOG_PATHS=()
  CATALOG_HASHES=()
  seen='|'
  while IFS= read -r catalog_line || [[ -n "$catalog_line" ]]; do
    catalog_line="${catalog_line%$'\r'}"
    [[ -n "$catalog_line" ]] || continue
    IFS='|' read -r row_product row_platform relative_path expected_hash <<< "$catalog_line"
    case "$row_product" in
      claude-code|claude-desktop) ;;
      *) dev_env_error 'catalogo invalido: produto desconhecido'; return 1 ;;
    esac
    dev_env_check_platform "$row_platform" || return 1
    if [[ ! "$relative_path" =~ ^artifacts/[A-Za-z0-9._/-]+$ || "$relative_path" == */ ]]; then
      dev_env_error 'catalogo invalido: caminho de artefato inseguro'
      return 1
    fi
    case "/$relative_path/" in
      *'/../'*|*'/./'*|*'//'*) dev_env_error 'catalogo invalido: caminho de artefato inseguro'; return 1 ;;
    esac
    if [[ ! "$expected_hash" =~ ^[[:xdigit:]]{64}$ ]]; then
      dev_env_error 'catalogo invalido: SHA256 deve conter 64 caracteres hexadecimais'
      return 1
    fi
    key="$row_product/$row_platform"
    case "$seen" in
      *"|$key|"*) dev_env_error "catalogo invalido: entrada duplicada para $key"; return 1 ;;
    esac
    seen="$seen$key|"
    CATALOG_PRODUCTS+=("$row_product")
    CATALOG_PLATFORMS+=("$row_platform")
    CATALOG_PATHS+=("$relative_path")
    CATALOG_HASHES+=("${expected_hash,,}")
  done < "$1"
  if [[ "${#CATALOG_PATHS[@]}" == 0 ]]; then
    dev_env_error 'catalogo vazio'
    return 1
  fi
}
