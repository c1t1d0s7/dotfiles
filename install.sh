#!/usr/bin/env bash
# dotfiles 설치 — 홈 디렉토리로 설정 파일을 복사한다. macOS 전용.
#
#   ./install.sh                    실제 적용
#   ./install.sh --dry              무엇을 할지만 출력
#   ./install.sh --config FILE      신원 변수를 파일에서 읽는다 (기본: ./install.conf)
#
# 복사 방식이므로 리포를 고친 뒤 반드시 다시 실행해야 반영된다.
# 반대로 ~/.zshrc 등을 직접 고치면 리포에 반영되지 않는다.
# `./install.sh --dry` 가 어긋난 파일을 "(differs)"로 알려주므로,
# 편집 방향이 헷갈릴 때 먼저 확인할 것.
#
# 출력은 영어로 통일한다. 주석과 생성 파일의 설명만 한국어다.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY=false

# 신원 변수. 값이 있으면 그대로 쓰고, 비어 있으면 물어본다.
#   개인 계정  GIT_PERSONAL_ACCOUNT GIT_PERSONAL_NAME GIT_PERSONAL_EMAIL
#   조직       GIT_ORG_ACCOUNT      GIT_ORG_NAME      GIT_ORG_EMAIL
# 우선순위는 환경변수 > 설정 파일 > 입력. 조직을 둘 이상 두려면 대화형으로 계속 물어본다.
CONF_VARS="GIT_PERSONAL_ACCOUNT GIT_PERSONAL_NAME GIT_PERSONAL_EMAIL
GIT_ORG_ACCOUNT GIT_ORG_NAME GIT_ORG_EMAIL"

# 설정 파일 위치. --config 로 바꾸거나 $DOTFILES_CONF 로 지정할 수 있다.
# 리포 안에 두더라도 이메일이 들어가므로 .gitignore에 걸려 있다.
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

# 설정 파일은 셸 조각이라 그대로 source 한다. 즉 임의의 명령이 실행될 수 있으니
# 남이 준 파일을 그냥 넘기지 말 것. 이미 들어온 환경변수가 파일보다 우선한다.
load_conf() {
  local f="$1" v
  if [[ ! -f "$f" ]]; then
    # 직접 지정한 파일이 없으면 조용히 넘어가면 안 된다.
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

# ghostty는 XDG 경로를 먼저, macOS의 Application Support를 나중에 읽고 나중 것이 이긴다.
# 그래서 예전 위치의 파일을 반드시 치워야 한다(migrate_ghostty_to_xdg).
# 파일명은 1.2.3부터 config.ghostty 다. 그 전에는 config 였다.
GHOSTTY_DIR="$HOME/.config/ghostty"
GHOSTTY_LEGACY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
# .zshrc의 $ZSH_CUSTOM과 반드시 같아야 한다. 플러그인/테마도 이 아래에 있어야 로드된다.
ZSH_CUSTOM_DIR="$HOME/.config/zsh"
# git 설정은 홈 최상위 대신 여기에 모은다. 파일명은 git이 정한 것을 따른다:
#   config   ~/.gitconfig 대신 읽힌다(단, ~/.gitconfig가 있으면 그쪽이 이긴다)
#   ignore   core.excludesFile의 기본값이라 설정 없이 그냥 먹는다
#   message  기본값은 없다. gitconfig의 commit.template이 이 경로를 가리킨다.
# 리포의 git/gitconfig 안에도 이 경로가 문자열로 박혀 있으므로 둘이 어긋나면 안 된다.
GIT_CONFIG_DIR="$HOME/.config/git"

# 복사 목록: "리포 내 경로:목적지"
# $ZSH_CUSTOM_DIR/*.zsh 는 개수가 늘어날 수 있어 아래에서 따로 훑는다.
FILES=(
  "zsh/zshenv:$HOME/.zshenv"
  "zsh/zshrc:$HOME/.zshrc"
  "zsh/p10k.zsh:$HOME/.p10k.zsh"
  "ghostty/config.ghostty:$GHOSTTY_DIR/config.ghostty"
  "git/gitconfig:$GIT_CONFIG_DIR/config"
  "git/gitignore_global:$GIT_CONFIG_DIR/ignore"
  "git/gitmessage:$GIT_CONFIG_DIR/message"
)

copy() {
  local src="$DOTFILES/$1" dst="$2"

  if [[ ! -e "$src" ]]; then
    echo "  skip (no source): $1"
    return
  fi

  # 내용이 같은 실제 파일이면 손대지 않는다.
  # 심볼릭 링크는 내용이 같아도 교체 대상이다(예전 방식에서 넘어오는 경우).
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

  # 기존 파일/링크는 백업으로 옮긴다.
  # cp 전에 반드시 치워야 한다. dst가 심볼릭 링크로 남아 있으면 cp가 링크를 따라가서,
  #  - 링크가 딴 데를 가리키면: 그 엉뚱한 파일을 덮어쓰고 dst는 링크인 채로 남는다
  #  - 링크가 src를 가리키면:   cp가 "identical"로 exit 1 -> set -e에 스크립트가 죽는다
  # 예전 심볼릭 링크 방식에서 넘어올 때 정확히 이 상황이다.
  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP"
    mv "$dst" "$BACKUP/$(basename "$dst")"
    echo "  backup: $dst -> $BACKUP/"
  fi

  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "  copy: $dst"
}

FAILED=0   # 배열 대신 카운터 — macOS 기본 bash 3.2는 set -u에서 빈 배열 전개가 에러다

# git 리포를 받거나(없으면) 갱신한다(있으면). 실패해도 스크립트를 죽이지 않는다.
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

  # 임시 경로에 받아서 성공했을 때만 교체한다.
  # 곧바로 rm -rf "$dir" 하면 클론이 실패했을 때 기존 내용만 날린다.
  local tmp="$dir.tmp.$$"
  rm -rf "$tmp"
  if git clone -q --depth=1 "$url" "$tmp"; then
    rm -rf "$dir"
    mv "$tmp" "$dir"
    echo "  clone: $name"
  else
    rm -rf "$tmp"
    # 여기서 죽지 않는다 — 설정 복사는 진행하고 나중에 재실행할 수 있게.
    echo "  failed: $name (skipped)"
    FAILED=$((FAILED + 1))
  fi
}

# ── git 신원 ─────────────────────────────────────────────────────────────────
# 신원은 GitHub 계정/조직 하나당 하나다. 그 이름이 곧 디렉토리이자 파일명이다:
#
#   ~/git/<계정>/                        여기 있는 리포만 그 신원으로 커밋된다
#   $GIT_CONFIG_DIR/identity             includeIf 목록 (기본 [user]는 일부러 없다)
#   $GIT_CONFIG_DIR/identity-<계정>      그 계정의 이름/이메일
#
# 기본 신원을 두지 않으므로 ~/git/<계정>/ 밖에서는 커밋이 거부된다(useConfigOnly).
# 조용히 엉뚱한 이메일로 커밋되느니 멈추는 편이 낫다. 그 리포에만 쓰려면
# --global 없이 `git config user.email ...` 로 지정한다.
#
# 값에도 기본값을 두지 않는다. 엔터로 넘긴 값이 커밋에 박히는 것보다 낫다.
#
# 값은 위 CONF_VARS의 변수(환경변수 또는 설정 파일)로 받고, 비어 있으면 물어본다.
# 변수로 받을 수 있는 조직은 하나뿐이다. 둘 이상은 대화형으로 계속 입력받는다.
IDENTITY="$GIT_CONFIG_DIR/identity"

# read -p 의 프롬프트는 stderr로 나가므로 $(ask ...) 결과에 섞이지 않는다.
# 입력이 끝나면(Ctrl-D) 1을 돌려준다 — 안 그러면 아래 ask_until이 무한 루프에 빠진다.
ask() {   # ask <프롬프트>
  local reply=""
  read -r -p "  $1: " reply || return 1
  printf '%s\n' "$reply"
}

ask_until() {   # ask_until <프롬프트> <검증함수> — 통과할 때까지 다시 묻는다
  local prompt="$1" check="$2" value=""
  while :; do
    value="$(ask "$prompt")" || return 1
    "$check" "$value" && break
  done
  printf '%s\n' "$value"
}

# get_field <환경변수값> <프롬프트> <검증함수>
# 변수가 유효하면 그대로 쓰고, 아니면 대화형일 때만 물어본다. 정하지 못하면 1.
get_field() {
  local given="$1" prompt="$2" check="$3"
  if [[ -n "$given" ]] && "$check" "$given"; then
    printf '%s\n' "$given"
    return 0
  fi
  $INTERACTIVE || return 1
  ask_until "$prompt" "$check"
}

is_name()  { [[ -n "$1" ]] || { echo "  must not be empty" >&2; false; }; }
is_email() { [[ "$1" == *@*.* && "$1" != *" "* ]] || { echo "  not an email address" >&2; false; }; }
# 계정 이름은 경로(~/git/<계정>/)와 파일명(identity-<계정>) 양쪽에 그대로 들어간다.
# GitHub 규약을 그대로 쓴다 — 영숫자와 하이픈, 하이픈으로 시작·끝 불가, 39자 이하.
is_account() {
  [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]] \
    || { echo "  letters, digits and hyphens only, max 39, no leading/trailing hyphen" >&2; false; }
}

# 생성 파일도 다른 설정 파일과 같은 백업 디렉토리로 옮긴다.
stash_existing() {
  [[ -e "$1" || -L "$1" ]] || return 0
  mkdir -p "$BACKUP"
  mv "$1" "$BACKUP/$(basename "$1")"
  echo "  backup: $1 -> $BACKUP/"
}

write_account_config() {   # write_account_config <계정> <이름> <이메일>
  local dst="$GIT_CONFIG_DIR/identity-$1"
  stash_existing "$dst"
  mkdir -p "$GIT_CONFIG_DIR"
  cat > "$dst" <<EOF
# install.sh가 생성. ~/git/$1/ 아래에서만 적용된다.
[user]
	name = $2
	email = $3
EOF
  echo "  create: $dst"
}

write_identity() {   # write_identity <includeIf 블록들>
  mkdir -p "$GIT_CONFIG_DIR"
  stash_existing "$IDENTITY"
  cat > "$IDENTITY" <<EOF
# install.sh가 생성. ~/.config/git/config 가 [include]로 항상 읽는다.
# 기본 [user]는 일부러 두지 않는다 — ~/git/<계정>/ 밖에서는 커밋이 거부된다.
$1
EOF
  echo "  create: $IDENTITY"
}

# ghostty 설정을 Application Support에서 ~/.config/ghostty/ 로 이전.
# 남겨두면 나중에 읽히는 쪽이라 새 파일을 덮어써버린다.
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

# ── 예전 위치(홈 최상위)에서 ~/.config/git/ 으로 이전 ────────────────────────
# ~/.gitconfig 는 반드시 치워야 한다. git은 XDG 파일과 ~/.gitconfig 를 둘 다 읽고
# ~/.gitconfig 를 나중에 읽으므로, 남아 있으면 새 설정을 통째로 가려버린다.
migrate_git_to_xdg() {
  local f acct old new blocks="" name email
  local old_identity="$HOME/.gitconfig-identity"

  # 신원은 버리지 않고 옮긴다. 다시 입력할 이유가 없다.
  if [[ -f "$old_identity" && ! -f "$IDENTITY" ]]; then
    # includeIf가 실제로 가리키던 파일만 옮긴다. 계정 이름은 그대로 쓴다.
    # --file 은 include를 따라가지 않으므로 includeIf 키가 그대로 나온다.
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

    # 예전 구조의 '기본 신원'은 어느 계정 것인지 정보가 없다. 한 번만 물어본다.
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

  # 리포에서 복사되던 것들은 새 위치로 다시 복사되므로 치우기만 하면 된다.
  for f in "$HOME/.gitconfig" "$HOME/.gitignore_global" "$HOME/.gitmessage"; do
    [[ -e "$f" || -L "$f" ]] || continue
    if $DRY; then
      echo "  [dry] move to backup: $f"
    else
      stash_existing "$f"
    fi
  done

  # 옮기지 못하고 남은 예전 파일 — 이제 아무도 읽지 않는다.
  # dry run에서는 위 이전이 실제로 일어나지 않았으므로 훑어봐야 오답만 나온다.
  $DRY && return 0
  for f in "$HOME"/.gitconfig-*; do
    [[ -e "$f" ]] || continue
    echo "  note: $f is no longer used (safe to delete)"
  done
  return 0
}

# identity 블록을 쌓는다. bash 3.2에는 nameref가 없어 전역을 쓴다.
ACCOUNT_BLOCKS=""
ACCOUNT_COUNT=0
add_account() {   # add_account <계정> <이름> <이메일>
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
    echo "          to redo, delete it and run ./install.sh again"
    return 0
  fi

  if $DRY; then
    # 예전 위치에 신원이 있으면 위 이전 단계가 만들어주므로 여기서 물어볼 일이 없다.
    if [[ -f "$HOME/.gitconfig-identity" ]]; then
      echo "  reuse: $IDENTITY (migrated above)"
    else
      echo "  [dry] create: $IDENTITY (variables, then prompts for what is missing)"
    fi
    return 0
  fi

  # 파이프로 실행되면(curl | bash, CI) 물어볼 수가 없다. 이때는 변수만 쓴다.
  INTERACTIVE=true
  [[ -t 0 ]] || INTERACTIVE=false

  local acct name email

  $INTERACTIVE && {
    echo "  One identity per GitHub account or organization. The name you enter sets"
    echo "  both ~/git/<name>/ and the identity file — repos elsewhere cannot commit."
  }

  # ── 개인 계정 (필수) ──
  acct="$(get_field "${GIT_PERSONAL_ACCOUNT:-}" "Your GitHub account" is_account)" || {
    echo "  skip: GIT_PERSONAL_ACCOUNT is unset or invalid and cannot prompt"; return 0; }
  name="$(get_field "${GIT_PERSONAL_NAME:-}" "  Commit name for $acct" is_name)" || {
    echo "  skip: GIT_PERSONAL_NAME is unset or invalid and cannot prompt"; return 0; }
  email="$(get_field "${GIT_PERSONAL_EMAIL:-}" "  Commit email for $acct" is_email)" || {
    echo "  skip: GIT_PERSONAL_EMAIL is unset or invalid and cannot prompt"; return 0; }
  add_account "$acct" "$name" "$email"

  # ── 조직 (선택, 대화형이면 여러 개) ──
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
    # 변수로 받을 수 있는 조직은 하나뿐이다. 두 번째부터는 반드시 물어본다.
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
[[ -n "$CONF_LOADED" ]] && echo "config:   $CONF_LOADED"
$DRY && echo "(dry run — no changes)"
# git은 $XDG_CONFIG_HOME/git/config 를 본다. 그게 ~/.config 가 아니면 여기서 두는
# 파일을 git이 못 찾는다. 리포에 경로가 문자열로 박혀 있어 자동으로 못 따라간다.
if [[ -n "${XDG_CONFIG_HOME:-}" && "${XDG_CONFIG_HOME}" != "$HOME/.config" ]]; then
  echo "warning: XDG_CONFIG_HOME=$XDG_CONFIG_HOME — this repo assumes ~/.config"
fi
echo

# 예전 방식에서는 $ZSH_CUSTOM_DIR 자체가 리포를 가리키는 심볼릭 링크였다.
# 그대로 두면 아래 플러그인 클론이 리포 안으로 들어가므로 실제 디렉토리로 바꾼다.
# 이미 마이그레이션된 머신에서는 아무 일도 하지 않는다.
if [[ -L "$ZSH_CUSTOM_DIR" ]]; then
  echo "\$ZSH_CUSTOM cleanup:"
  if $DRY; then
    echo "  [dry] replace symlink with real directory: $ZSH_CUSTOM_DIR"
  else
    OLD_CUSTOM="$(readlink "$ZSH_CUSTOM_DIR")"
    rm "$ZSH_CUSTOM_DIR"          # 링크만 지운다. 가리키던 리포는 건드리지 않는다.
    mkdir -p "$ZSH_CUSTOM_DIR"
    # 리포 안에 이미 받아둔 플러그인/테마는 옮겨온다. 다시 받을 이유가 없다.
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

# oh-my-zsh 본체. .zshrc가 $ZSH/oh-my-zsh.sh를 소싱하므로 이게 없으면
# 프롬프트와 플러그인은 물론 $ZSH_CUSTOM/*.zsh의 alias까지 통째로 안 뜬다.
# 경로는 .zshrc의 $ZSH와 맞춰야 한다.
echo "oh-my-zsh:"
clone_or_pull "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh"
echo

# 서드파티 플러그인/테마는 리포 밖, $ZSH_CUSTOM 아래에 직접 받는다.
# URL에 ':'가 들어가므로 구분자는 '|'
REPOS=(
  "https://github.com/zsh-users/zsh-autosuggestions.git|$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
  "https://github.com/zsh-users/zsh-completions.git|$ZSH_CUSTOM_DIR/plugins/zsh-completions"
  "https://github.com/zsh-users/zsh-syntax-highlighting.git|$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
  "https://github.com/romkatv/powerlevel10k.git|$ZSH_CUSTOM_DIR/themes/powerlevel10k"
)

echo "zsh plugins/themes ($ZSH_CUSTOM_DIR):"
for entry in "${REPOS[@]}"; do
  clone_or_pull "${entry%%|*}" "${entry#*|}"
done
echo

echo "legacy config locations:"
migrate_git_to_xdg
migrate_ghostty_to_xdg
echo

echo "config files:"
for entry in "${FILES[@]}"; do
  copy "${entry%%:*}" "${entry#*:}"
done

# $ZSH_CUSTOM/*.zsh — 파일이 늘어도 install.sh를 고칠 필요 없게 훑는다.
for src in "$DOTFILES"/zsh/custom/*.zsh; do
  [[ -e "$src" ]] || continue
  copy "zsh/custom/$(basename "$src")" "$ZSH_CUSTOM_DIR/$(basename "$src")"
done

# 복사 방식의 함정: 리포에서 지운 파일이 목적지에 남아 계속 소싱된다.
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
if command -v brew >/dev/null; then
  echo "Run this yourself to install Homebrew packages:"
  echo "  brew bundle install --file=$DOTFILES/Brewfile"
else
  echo "Homebrew not found. See https://brew.sh"
fi

echo
[[ -d "$BACKUP" ]] && echo "backups: $BACKUP"

if ! $DRY && (( FAILED > 0 )); then
  echo
  echo "Failed to fetch $FAILED repo(s). Config files were copied,"
  echo "so check your network and run ./install.sh again."
  exit 1
fi

echo "Done. Open a new shell to verify: exec zsh"
exit 0
