#!/usr/bin/env bash
# Linux entry point for Ubuntu, Debian, and Rocky Linux.
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
DOTFILES=""
if [[ -n "$SCRIPT_PATH" ]]; then
  DOTFILES="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
fi
DRY=false
ARGS=("$@")

# Validate options before installing packages.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry) DRY=true ;;
    --config)
      [[ $# -ge 2 ]] || { echo "usage: $0 [--dry] [--config FILE]" >&2; exit 2; }
      shift ;;
    --config=*) ;;
    *) echo "usage: $0 [--dry] [--config FILE]" >&2; exit 2 ;;
  esac
  shift
done

[[ "$(uname -s)" == Linux && -r /etc/os-release ]] || {
  echo "install_linux.sh is for Linux" >&2
  exit 1
}

# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-} ${ID_LIKE:-}" in
  *ubuntu*|*debian*) LINUX_FAMILY=debian ;;
  *rocky*) LINUX_FAMILY=rocky ;;
  *)
    echo "unsupported Linux distribution: ${PRETTY_NAME:-${ID:-unknown}}" >&2
    exit 1
    ;;
esac

if [[ -z "$DOTFILES" || ! -f "$DOTFILES/install_common.sh" ]]; then
  ARCHIVE_URL="https://github.com/c1t1d0s7/dotfiles/archive/refs/heads/main.tar.gz"
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")"
  trap 'rm -rf "$WORK_DIR"' EXIT INT TERM

  curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$WORK_DIR"
  SOURCE_DIR="$WORK_DIR/dotfiles-main"
  [[ -f "$SOURCE_DIR/install_linux.sh" ]] || {
    echo "failed to download dotfiles" >&2
    exit 1
  }

  if [[ -t 2 ]]; then
    bash "$SOURCE_DIR/install_linux.sh" "${ARGS[@]}" </dev/tty
  else
    bash "$SOURCE_DIR/install_linux.sh" "${ARGS[@]}"
  fi
  exit
fi

PACKAGES=(git zsh neovim fzf curl unzip ca-certificates coreutils less)
if [[ "$LINUX_FAMILY" == rocky ]]; then
  PACKAGES+=(util-linux-user)
fi

run_as_root() {
  if (( EUID == 0 )); then
    "$@"
  elif command -v sudo >/dev/null; then
    sudo "$@"
  else
    echo "sudo is required for this operation" >&2
    exit 1
  fi
}

ensure_rocky_repositories() {
  local repository=crb
  if [[ "${VERSION_ID%%.*}" == 8 ]]; then
    repository=powertools
  fi

  if $DRY; then
    rpm -q epel-release >/dev/null 2>&1 \
      || echo "  [dry] dnf install: epel-release"
    echo "  [dry] enable: $repository"
    return 0
  fi

  rpm -q epel-release >/dev/null 2>&1 \
    || run_as_root dnf install -y epel-release

  if command -v crb >/dev/null; then
    run_as_root crb enable
    return 0
  fi

  run_as_root dnf install -y dnf-plugins-core
  run_as_root dnf config-manager --set-enabled "$repository"
}

install_linux_packages() {
  local package
  local -a missing=()

  for package in "${PACKAGES[@]}"; do
    case "$LINUX_FAMILY" in
      debian)
        dpkg-query -W -f='${Status}' "$package" 2>/dev/null \
          | grep -q '^install ok installed$' || missing+=("$package")
        ;;
      rocky)
        rpm -q "$package" >/dev/null 2>&1 || missing+=("$package")
        ;;
    esac
  done

  if (( ${#missing[@]} == 0 )); then
    echo "  installed: ${PACKAGES[*]}"
    return 0
  fi

  if [[ "$LINUX_FAMILY" == rocky ]]; then
    ensure_rocky_repositories
  fi

  if $DRY; then
    if [[ "$LINUX_FAMILY" == debian ]]; then
      echo "  [dry] apt-get install: ${missing[*]}"
    else
      echo "  [dry] dnf install: ${missing[*]}"
    fi
    return 0
  fi

  if [[ "$LINUX_FAMILY" == debian ]]; then
    run_as_root apt-get update
    run_as_root apt-get install -y "${missing[@]}"
  else
    run_as_root dnf install -y "${missing[@]}"
  fi
}

install_oh_my_posh() {
  local installer

  if [[ -x "$HOME/.local/bin/oh-my-posh" ]] || command -v oh-my-posh >/dev/null; then
    echo "  installed: oh-my-posh"
    return 0
  fi

  if $DRY; then
    echo "  [dry] install: oh-my-posh -> $HOME/.local/bin/oh-my-posh"
    return 0
  fi

  if ! mkdir -p "$HOME/.local/bin"; then
    echo "failed to create $HOME/.local/bin" >&2
    return 1
  fi

  installer="$(mktemp "${TMPDIR:-/tmp}/oh-my-posh-install.XXXXXX")"
  if ! curl -fsSL https://ohmyposh.dev/install.sh -o "$installer"; then
    rm -f "$installer"
    return 1
  fi
  if ! bash "$installer" -d "$HOME/.local/bin"; then
    rm -f "$installer"
    return 1
  fi
  rm -f "$installer"
  echo "  install: oh-my-posh"
}

configure_login_shell() {
  local target_user zsh_bin current_shell reply=""
  target_user="$(id -un)"
  zsh_bin="$(command -v zsh || true)"

  if [[ -z "$zsh_bin" ]]; then
    echo "zsh was not found; the login shell was not changed" >&2
    return 1
  fi

  current_shell="$(getent passwd "$target_user" 2>/dev/null | awk -F: '{print $7}' || true)"
  if [[ "$current_shell" == "$zsh_bin" ]]; then
    echo "login shell: $zsh_bin"
    return 0
  fi

  if $DRY; then
    echo "[dry] ask to change the login shell for $target_user to $zsh_bin"
    return 0
  fi

  if [[ ! -r /etc/shells ]] || ! grep -Fxq "$zsh_bin" /etc/shells; then
    echo "$zsh_bin is not listed in /etc/shells; the login shell was not changed" >&2
    return 1
  fi

  if ! command -v chsh >/dev/null; then
    echo "chsh was not found; the login shell was not changed" >&2
    return 1
  fi

  if [[ ! -t 0 ]]; then
    echo "Run this yourself to make zsh your login shell:"
    echo "  sudo chsh -s $zsh_bin $target_user"
    return 0
  fi

  if ! read -r -p "Make $zsh_bin the login shell for $target_user? [Y/n] " reply; then
    echo "login shell unchanged"
    return 0
  fi
  case "$reply" in
    ""|[Yy]*)
      run_as_root chsh -s "$zsh_bin" "$target_user"
      echo "login shell changed to $zsh_bin; log out and back in to apply"
      ;;
    *)
      echo "login shell unchanged"
      ;;
  esac
}

echo "linux packages:"
install_linux_packages
echo

echo "oh-my-posh:"
install_oh_my_posh
echo

DOTFILES_INSTALL_TARGET=linux \
DOTFILES_INSTALL_COMMAND=./install_linux.sh \
  "$DOTFILES/install_common.sh" "${ARGS[@]}"

echo
configure_login_shell
