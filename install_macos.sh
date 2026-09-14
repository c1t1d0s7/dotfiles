#!/usr/bin/env bash
# macOS entry point.
set -euo pipefail

[[ "$(uname -s)" == Darwin ]] || {
  echo "install_macos.sh is for macOS" >&2
  exit 1
}

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
DOTFILES=""
if [[ -n "$SCRIPT_PATH" ]]; then
  DOTFILES="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
fi

if [[ -z "$DOTFILES" || ! -f "$DOTFILES/install_common.sh" ]]; then
  ARCHIVE_URL="https://github.com/c1t1d0s7/dotfiles/archive/refs/heads/main.tar.gz"
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")"
  trap 'rm -rf "$WORK_DIR"' EXIT INT TERM

  curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$WORK_DIR"
  SOURCE_DIR="$WORK_DIR/dotfiles-main"
  [[ -f "$SOURCE_DIR/install_macos.sh" ]] || {
    echo "failed to download dotfiles" >&2
    exit 1
  }

  if [[ -t 2 ]]; then
    DOTFILES_REMOTE_INSTALL=true bash "$SOURCE_DIR/install_macos.sh" "$@" </dev/tty
  else
    DOTFILES_REMOTE_INSTALL=true bash "$SOURCE_DIR/install_macos.sh" "$@"
  fi
  exit
fi

DOTFILES_INSTALL_TARGET=macos \
DOTFILES_INSTALL_COMMAND=./install_macos.sh \
DOTFILES_AUTO_PACKAGES="${DOTFILES_REMOTE_INSTALL:-false}" \
  "$DOTFILES/install_common.sh" "$@"
