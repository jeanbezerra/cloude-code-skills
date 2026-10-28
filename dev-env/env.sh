#!/usr/bin/env bash
# Execute: source ./env.sh
# Applies only to the current shell. No shell profiles are changed.

_dev_env_home="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || return 1
if [[ -f "$_dev_env_home/env.local.sh" ]]; then
  source "$_dev_env_home/env.local.sh" || return 1
fi
export DEV_ENV_HOME="$_dev_env_home"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) _dev_env_windows=1 ;;
  *) _dev_env_windows=0 ;;
esac

if [[ -z "${DEV_ENV_INSTALL_DIR:-}" ]]; then
  if [[ "$_dev_env_windows" == 1 && -n "${LOCALAPPDATA:-}" ]]; then
    DEV_ENV_INSTALL_DIR="$LOCALAPPDATA/ClaudeDevEnv/bin"
  else
    DEV_ENV_INSTALL_DIR="$HOME/.local/bin"
  fi
fi
DEV_ENV_DOWNLOAD_DIR="${DEV_ENV_DOWNLOAD_DIR:-$DEV_ENV_HOME/downloads}"

# Accept variables inherited from CMD, including native paths with spaces.
if command -v cygpath >/dev/null 2>&1; then
  DEV_ENV_DOWNLOAD_DIR="$(cygpath -u "$DEV_ENV_DOWNLOAD_DIR")" || return 1
  DEV_ENV_INSTALL_DIR="$(cygpath -u "$DEV_ENV_INSTALL_DIR")" || return 1
fi
export DEV_ENV_DOWNLOAD_DIR DEV_ENV_INSTALL_DIR
export DEV_ENV_CATALOG="${DEV_ENV_CATALOG:-$DEV_ENV_HOME/artifacts/catalog.txt}"

export S3_BUCKET="${S3_BUCKET:-jb-static-files-177862772785-sa-east-1-an}"
export S3_REGION="${S3_REGION:-sa-east-1}"
export S3_PREFIX="${S3_PREFIX-dev-env}"
if [[ -z "${S3_BASE_URL:-}" && -n "$S3_BUCKET" ]]; then
  _dev_env_prefix="${S3_PREFIX#/}"
  _dev_env_prefix="${_dev_env_prefix%/}"
  S3_BASE_URL="https://$S3_BUCKET.s3.$S3_REGION.amazonaws.com"
  if [[ -n "$_dev_env_prefix" ]]; then
    S3_BASE_URL="$S3_BASE_URL/$_dev_env_prefix"
  fi
fi
export S3_BASE_URL="${S3_BASE_URL:-}"

export DISABLE_AUTOUPDATER=1
export DISABLE_UPDATES=1
export CLAUDE_CODE_USE_POWERSHELL_TOOL=0
if [[ "$_dev_env_windows" == 1 && -z "${CLAUDE_CODE_GIT_BASH_PATH:-}" ]]; then
  _dev_env_bash="$(command -v bash)" || return 1
  if command -v cygpath >/dev/null 2>&1; then
    CLAUDE_CODE_GIT_BASH_PATH="$(cygpath -aw "$_dev_env_bash")" || return 1
  else
    CLAUDE_CODE_GIT_BASH_PATH="$_dev_env_bash"
  fi
fi
if [[ -n "${CLAUDE_CODE_GIT_BASH_PATH:-}" ]]; then
  export CLAUDE_CODE_GIT_BASH_PATH
fi

case ":${PATH:-}:" in
  *":$DEV_ENV_INSTALL_DIR:"*) ;;
  *) export PATH="$DEV_ENV_INSTALL_DIR:${PATH:-}" ;;
esac

unset _dev_env_home _dev_env_windows _dev_env_prefix _dev_env_bash
