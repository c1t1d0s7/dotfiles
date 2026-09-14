#!/usr/bin/env bash
# Shared installer used by the OS-specific entry points.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY=false

# Environment > config file > prompt.
CONF_VARS="GIT_PERSONAL_ACCOUNT GIT_PERSONAL_NAME GIT_PERSONAL_EMAIL
GIT_ORG_ACCOUNT GIT_ORG_NAME GIT_ORG_EMAIL"

CONF="${DOTFILES_CONF:-$DOTFILES/install.conf}"
CONF_GIVEN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry) DRY=true ;;
    --config)
      [[ $# -ge 2 ]] || { echo "usage: $0 [--dry] [--config FILE]" >&2; exit 2; }
      CONF="$2"; CONF_GIVEN=true; shift ;;
    --config=*) CONF="${1#*=}"; CONF_GIVEN=true ;;
    *) echo "usage: $0 [--dry] [--config FILE]" >&2; exit 2 ;;
  esac
  shift
done

# Internal override used by the OS-specific entry points.
PLATFORM="${DOTFILES_INSTALL_TARGET:-}"
INSTALL_COMMAND="${DOTFILES_INSTALL_COMMAND:-installer}"
case "$PLATFORM" in
  macos)
    [[ "$(uname -s)" == Darwin ]] || {
      echo "install_macos.sh is for macOS" >&2
      exit 1
    }
    ;;
  linux)
    [[ "$(uname -s)" == Linux ]] || {
      echo "install_linux.sh is for Linux" >&2
      exit 1
    }
    ;;
  *)
    echo "run install_macos.sh or install_linux.sh" >&2
    exit 2
    ;;
esac

# The config is sourced as shell code. Existing environment values win.
load_conf() {
  local f="$1" v
  if [[ ! -f "$f" ]]; then
    $CONF_GIVEN && { echo "config file not found: $f" >&2; exit 2; }
    return 0
  fi
  for v in $CONF_VARS; do eval "__env_$v=\"\${$v:-}\""; done
  # shellcheck disable=SC1090
  . "$f"
  for v in $CONF_VARS; do
    eval "[[ -n \"\${__env_$v}\" ]] && $v=\"\${__env_$v}\"" || true
    eval "unset __env_$v"
  done
  CONF_LOADED="$f"
}
CONF_LOADED=""
load_conf "$CONF"

GHOSTTY_DIR="$HOME/.config/ghostty"
GHOSTTY_LEGACY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
ZSH_CUSTOM_DIR="$HOME/.config/zsh"
OH_MY_POSH_DIR="$HOME/.config/oh-my-posh"
GIT_CONFIG_DIR="$HOME/.config/git"
VSCODE_DIR="$HOME/Library/Application Support/Code/User"

# Format: repository path:destination.
FILES=(
  "zsh/zshenv:$HOME/.zshenv"
  "zsh/zshrc:$HOME/.zshrc"
  "oh-my-posh/config.omp.json:$OH_MY_POSH_DIR/config.omp.json"
  "git/gitconfig:$GIT_CONFIG_DIR/config"
  "git/gitignore_global:$GIT_CONFIG_DIR/ignore"
  "git/gitmessage:$GIT_CONFIG_DIR/message"
)

if [[ "$PLATFORM" == macos ]]; then
  FILES+=(
    "ghostty/config.ghostty:$GHOSTTY_DIR/config.ghostty"
    "vscode/settings.json:$VSCODE_DIR/settings.json"
    "vscode/keybindings.json:$VSCODE_DIR/keybindings.json"
  )
fi

copy() {
  local src="$DOTFILES/$1" dst="$2"

  if [[ ! -e "$src" ]]; then
    echo "  skip (no source): $1"
    return
  fi

  # Replace legacy symlinks even when their contents match.
  if [[ -f "$dst" && ! -L "$dst" ]] && cmp -s "$src" "$dst"; then
    echo "  unchanged: $dst"
    return
  fi

  if $DRY; then
    if [[ -L "$dst" ]]; then
      echo "  [dry] replace symlink with real file: $dst"
    elif [[ -e "$dst" ]]; then
      echo "  [dry] backup and overwrite: $dst   (differs)"
    else
      echo "  [dry] create: $dst"
    fi
    return
  fi

  # Move the destination first so cp never follows a legacy symlink.
  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP"
    mv "$dst" "$BACKUP/$(basename "$dst")"
    echo "  backup: $dst -> $BACKUP/"
  fi

  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "  copy: $dst"
}

FAILED=0   # Compatible with the Bash 3.2 bundled with macOS.

# Clone missing repositories and fast-forward existing ones.
clone_or_pull() {
  local url="$1" dir="$2"
  local name
  name="$(basename "$dir")"

  if $DRY; then
    [[ -d "$dir/.git" ]] && echo "  [dry] update: $name" || echo "  [dry] clone: $name"
    return
  fi

  if [[ -d "$dir/.git" ]]; then
    if git -C "$dir" pull -q --ff-only 2>/dev/null; then
      echo "  update: $name"
    else
      echo "  skip (local changes or network): $name"
    fi
    return
  fi

  # Replace the target only after a successful clone.
  local tmp="$dir.tmp.$$"
  rm -rf "$tmp"
  if git clone -q --depth=1 "$url" "$tmp"; then
    rm -rf "$dir"
    mv "$tmp" "$dir"
    echo "  clone: $name"
  else
    rm -rf "$tmp"
    echo "  failed: $name (skipped)"
    FAILED=$((FAILED + 1))
  fi
}

# Git identities are scoped to ~/git/<account>/ with includeIf.
IDENTITY="$GIT_CONFIG_DIR/identity"

ask() {
  local reply=""
  read -r -p "  $1: " reply || return 1
  printf '%s\n' "$reply"
}

ask_until() {
  local prompt="$1" check="$2" value=""
  while :; do
    value="$(ask "$prompt")" || return 1
    "$check" "$value" && break
  done
  printf '%s\n' "$value"
}

get_field() {
  local given="$1" prompt="$2" check="$3"
  if [[ -n "$given" ]] && "$check" "$given"; then
    printf '%s\n' "$given"
    return 0
  fi
  $INTERACTIVE || return 1
  ask_until "$prompt" "$check"
}

get_optional_account() {
  local given="$1" prompt="$2" value=""
  if [[ -n "$given" ]] && is_account "$given"; then
    printf '%s\n' "$given"
    return 0
  fi
  $INTERACTIVE || return 1

  while :; do
    value="$(ask "$prompt")" || return 1
    [[ -z "$value" ]] && return 1
    if is_account "$value"; then
      printf '%s\n' "$value"
      return 0
    fi
  done
}

is_name()  { [[ -n "$1" ]] || { echo "  must not be empty" >&2; false; }; }
is_email() { [[ "$1" == *@*.* && "$1" != *" "* ]] || { echo "  not an email address" >&2; false; }; }
is_account() {
  [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]] \
    || { echo "  letters, digits and hyphens only, max 39, no leading/trailing hyphen" >&2; false; }
}

stash_existing() {
  [[ -e "$1" || -L "$1" ]] || return 0
  mkdir -p "$BACKUP"
  mv "$1" "$BACKUP/$(basename "$1")"
  echo "  backup: $1 -> $BACKUP/"
}

write_account_config() {
  local dst="$GIT_CONFIG_DIR/identity-$1"
  stash_existing "$dst"
  mkdir -p "$GIT_CONFIG_DIR"
  cat > "$dst" <<EOF
# Generated by the dotfiles installer for ~/git/$1/.
[user]
	name = $2
	email = $3
EOF
  echo "  create: $dst"
}

write_identity() {
  mkdir -p "$GIT_CONFIG_DIR"
  stash_existing "$IDENTITY"
  cat > "$IDENTITY" <<EOF
# Generated by the dotfiles installer. No default Git identity is set.
$1
EOF
  echo "  create: $IDENTITY"
}

# Remove the higher-priority legacy Ghostty config.
migrate_ghostty_to_xdg() {
  local f
  for f in "$GHOSTTY_LEGACY_DIR/config.ghostty" "$GHOSTTY_LEGACY_DIR/config"; do
    [[ -e "$f" || -L "$f" ]] || continue
    if $DRY; then
      echo "  [dry] move to backup: $f"
    else
      stash_existing "$f"
    fi
  done
  return 0
}

# Migrate legacy Git files to ~/.config/git/.
migrate_git_to_xdg() {
  local f acct old new blocks="" name email
  local old_identity="$HOME/.gitconfig-identity"

  if [[ -f "$old_identity" && ! -f "$IDENTITY" ]]; then
    # Move only identity files referenced by the old includeIf config.
    for old in $(git config --file "$old_identity" --get-regexp '^includeif\..*\.path' 2>/dev/null | awk '{print $NF}'); do
      case "$old" in
        "~/.gitconfig-"*) acct="${old#\~/.gitconfig-}" ;;
        *) continue ;;
      esac
      [[ -f "$HOME/.gitconfig-$acct" ]] || continue
      new="$GIT_CONFIG_DIR/identity-$acct"
      if $DRY; then
        echo "  [dry] move: ~/.gitconfig-$acct -> $new"
      else
        mkdir -p "$GIT_CONFIG_DIR"
        mv "$HOME/.gitconfig-$acct" "$new"
        echo "  move: ~/.gitconfig-$acct -> $new"
      fi
      blocks="$blocks
[includeIf \"gitdir:~/git/$acct/\"]
	path = ~/.config/git/identity-$acct
"
    done

    # The old default identity needs an account scope.
    name="$(git config --file "$old_identity" user.name 2>/dev/null || true)"
    email="$(git config --file "$old_identity" user.email 2>/dev/null || true)"
    if [[ -n "$email" ]]; then
      if $DRY; then
        echo "  [dry] ask which account owns the old default identity <$email>"
      elif [[ -t 0 ]]; then
        echo "  The old setup had a default identity: $name <$email>"
        echo "  It now needs an account — repos outside ~/git/<account>/ can no longer commit."
        acct="$(ask_until "GitHub account or organization for <$email>" is_account)" || acct=""
        if [[ -n "$acct" ]]; then
          write_account_config "$acct" "$name" "$email"
          blocks="$blocks
[includeIf \"gitdir:~/git/$acct/\"]
	path = ~/.config/git/identity-$acct
"
        fi
      else
        echo "  note: old default identity <$email> needs an account; re-run interactively"
      fi
    fi

    if $DRY; then
      echo "  [dry] create: $IDENTITY (from ~/.gitconfig-identity)"
    elif [[ -n "$blocks" ]]; then
      write_identity "$blocks"
      stash_existing "$old_identity"
    fi
  fi

  for f in "$HOME/.gitconfig" "$HOME/.gitignore_global" "$HOME/.gitmessage"; do
    [[ -e "$f" || -L "$f" ]] || continue
    if $DRY; then
      echo "  [dry] move to backup: $f"
    else
      stash_existing "$f"
    fi
  done

  # Report unused legacy files after a real migration.
  $DRY && return 0
  for f in "$HOME"/.gitconfig-*; do
    [[ -e "$f" ]] || continue
    echo "  note: $f is no longer used (safe to delete)"
  done
  return 0
}

# Globals avoid namerefs, which Bash 3.2 does not support.
ACCOUNT_BLOCKS=""
ACCOUNT_COUNT=0
add_account() {
  write_account_config "$1" "$2" "$3"
  ACCOUNT_BLOCKS="$ACCOUNT_BLOCKS
[includeIf \"gitdir:~/git/$1/\"]
	path = ~/.config/git/identity-$1
"
  ACCOUNT_COUNT=$((ACCOUNT_COUNT + 1))
}

setup_git_identity() {
  if [[ -f "$IDENTITY" && -z "${GIT_PERSONAL_ACCOUNT:-}" ]]; then
    echo "  exists: $IDENTITY"
    echo "          to redo, delete it and run $INSTALL_COMMAND again"
    return 0
  fi

  if $DRY; then
    if [[ -f "$HOME/.gitconfig-identity" ]]; then
      echo "  reuse: $IDENTITY (migrated above)"
    else
      echo "  [dry] configure: $IDENTITY (optional; empty account skips)"
    fi
    return 0
  fi

  # Non-interactive runs use variables only.
  INTERACTIVE=true
  [[ -t 0 ]] || INTERACTIVE=false

  local acct name email

  $INTERACTIVE && {
    echo "  One identity per GitHub account or organization. The name you enter sets"
    echo "  both ~/git/<name>/ and the identity file — repos elsewhere cannot commit."
  }

  # Skip all identity setup when the first account is empty.
  acct="$(get_optional_account "${GIT_PERSONAL_ACCOUNT:-}" "Your GitHub account (empty to skip)")" || {
    echo "  skip: Git identity was not configured"; return 0; }
  name="$(get_field "${GIT_PERSONAL_NAME:-}" "  Commit name for $acct" is_name)" || {
    echo "  skip: GIT_PERSONAL_NAME is unset or invalid and cannot prompt"; return 0; }
  email="$(get_field "${GIT_PERSONAL_EMAIL:-}" "  Commit email for $acct" is_email)" || {
    echo "  skip: GIT_PERSONAL_EMAIL is unset or invalid and cannot prompt"; return 0; }
  add_account "$acct" "$name" "$email"

  # Organizations (optional).
  acct="${GIT_ORG_ACCOUNT:-}"
  if [[ -z "$acct" ]] && $INTERACTIVE; then
    echo
    acct="$(ask "Organization on GitHub (empty to skip)")"
  fi
  while [[ -n "$acct" ]]; do
    if ! is_account "$acct"; then
      $INTERACTIVE || break
      acct="$(ask "Organization on GitHub (empty to finish)")"
      continue
    fi
    name="$(get_field "${GIT_ORG_NAME:-}" "  Commit name for $acct" is_name)" || {
      echo "  skip $acct: GIT_ORG_NAME is unset or invalid"; break; }
    email="$(get_field "${GIT_ORG_EMAIL:-}" "  Commit email for $acct" is_email)" || {
      echo "  skip $acct: GIT_ORG_EMAIL is unset or invalid"; break; }
    add_account "$acct" "$name" "$email"

    $INTERACTIVE || break
    # Additional organizations are interactive only.
    unset GIT_ORG_NAME GIT_ORG_EMAIL
    echo
    acct="$(ask "Organization on GitHub (empty to finish)")"
  done

  if (( ACCOUNT_COUNT == 0 )); then
    echo "  skip: no account configured — git will refuse to commit anywhere"
    return 0
  fi
  write_identity "$ACCOUNT_BLOCKS"
  return 0
}


echo "dotfiles: $DOTFILES"
echo "platform: $PLATFORM"
[[ -n "$CONF_LOADED" ]] && echo "config:   $CONF_LOADED"
$DRY && echo "(dry run — no changes)"
# This repository intentionally targets ~/.config.
if [[ -n "${XDG_CONFIG_HOME:-}" && "${XDG_CONFIG_HOME}" != "$HOME/.config" ]]; then
  echo "warning: XDG_CONFIG_HOME=$XDG_CONFIG_HOME — this repo assumes ~/.config"
fi
echo

# Replace the old ZSH_CUSTOM symlink with a real directory.
if [[ -L "$ZSH_CUSTOM_DIR" ]]; then
  echo "\$ZSH_CUSTOM cleanup:"
  if $DRY; then
    echo "  [dry] replace symlink with real directory: $ZSH_CUSTOM_DIR"
  else
    OLD_CUSTOM="$(readlink "$ZSH_CUSTOM_DIR")"
    rm "$ZSH_CUSTOM_DIR"
    mkdir -p "$ZSH_CUSTOM_DIR"
    for sub in plugins themes; do
      if [[ -d "$OLD_CUSTOM/$sub" ]]; then
        mv "$OLD_CUSTOM/$sub" "$ZSH_CUSTOM_DIR/$sub"
        echo "  move: $OLD_CUSTOM/$sub -> $ZSH_CUSTOM_DIR/$sub"
      fi
    done
    echo "  replaced symlink with real directory: $ZSH_CUSTOM_DIR"
  fi
  echo
fi
$DRY || mkdir -p "$ZSH_CUSTOM_DIR"

# Install Oh My Zsh at the path used by .zshrc.
echo "oh-my-zsh:"
clone_or_pull "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh"
echo

# Format: repository URL|destination.
REPOS=(
  "https://github.com/zsh-users/zsh-autosuggestions.git|$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
  "https://github.com/zsh-users/zsh-completions.git|$ZSH_CUSTOM_DIR/plugins/zsh-completions"
  "https://github.com/zsh-users/zsh-syntax-highlighting.git|$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
)

echo "zsh plugins ($ZSH_CUSTOM_DIR):"
for entry in "${REPOS[@]}"; do
  clone_or_pull "${entry%%|*}" "${entry#*|}"
done
echo

echo "legacy config locations:"
migrate_git_to_xdg
[[ "$PLATFORM" != macos ]] || migrate_ghostty_to_xdg
echo

echo "config files:"
for entry in "${FILES[@]}"; do
  copy "${entry%%:*}" "${entry#*:}"
done

# Copy every managed custom zsh file.
for src in "$DOTFILES"/zsh/custom/*.zsh; do
  [[ -e "$src" ]] || continue
  copy "zsh/custom/$(basename "$src")" "$ZSH_CUSTOM_DIR/$(basename "$src")"
done

# Warn about stale copied files.
for dst in "$ZSH_CUSTOM_DIR"/*.zsh; do
  [[ -e "$dst" ]] || continue
  if [[ ! -f "$DOTFILES/zsh/custom/$(basename "$dst")" ]]; then
    echo "  note: $dst is not in the repo (delete it if you removed it)"
  fi
done

echo
echo "git identity:"
setup_git_identity
echo
if [[ "$PLATFORM" == macos ]]; then
  if command -v brew >/dev/null; then
    if [[ "${DOTFILES_AUTO_PACKAGES:-false}" == true ]]; then
      if $DRY; then
        echo "[dry] brew bundle install --file=$DOTFILES/Brewfile"
      else
        brew bundle install --file="$DOTFILES/Brewfile"
      fi
    else
      echo "Run this yourself to install Homebrew packages:"
      echo "  brew bundle install --file=$DOTFILES/Brewfile"
    fi
  else
    echo "Homebrew not found. See https://brew.sh"
  fi
fi

echo
[[ -d "$BACKUP" ]] && echo "backups: $BACKUP"

if ! $DRY && (( FAILED > 0 )); then
  echo
  echo "Failed to fetch $FAILED repo(s). Config files were copied,"
  echo "so check your network and run $INSTALL_COMMAND again."
  exit 1
fi

echo "Done. Open a new shell to verify: exec zsh"
exit 0
