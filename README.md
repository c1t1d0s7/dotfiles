# dotfiles

macOS와 Ubuntu, Debian, Rocky Linux에서 사용하는 개발 환경 설정.

## 설치

### curl로 설치

macOS:

```bash
# Preview changes.
curl -fsSL https://raw.githubusercontent.com/c1t1d0s7/dotfiles/main/install_macos.sh | bash -s -- --dry

# Install.
curl -fsSL https://raw.githubusercontent.com/c1t1d0s7/dotfiles/main/install_macos.sh | bash
```

Linux (Ubuntu, Debian, Rocky Linux):

```bash
# Preview changes.
curl -fsSL https://raw.githubusercontent.com/c1t1d0s7/dotfiles/main/install_linux.sh | bash -s -- --dry

# Install.
curl -fsSL https://raw.githubusercontent.com/c1t1d0s7/dotfiles/main/install_linux.sh | bash
```

각 스크립트는 `main` 브랜치의 나머지 파일을 임시 디렉터리에 내려받고 종료할 때
삭제합니다. macOS에서는 Homebrew가 미리 설치되어 있어야 하며 curl 설치 시
`Brewfile`도 함께 적용합니다. 실행 전에 내용을 확인하려면 파이프 이후를 빼고 실행하세요.

로컬에서 설정을 수정하거나 커밋하려면 아래처럼 저장소를 클론해 설치합니다.

### macOS

```bash
git clone https://github.com/c1t1d0s7/dotfiles.git
cd dotfiles
./install_macos.sh --dry     # Preview changes.
./install_macos.sh           # Install configs, Oh My Zsh, and plugins.
brew bundle install --file=Brewfile  # Install Homebrew packages.
```

### Linux

리포를 받기 위한 `git`만 먼저 준비합니다.

```bash
# Ubuntu / Debian
sudo apt-get update && sudo apt-get install -y git

# Rocky Linux
sudo dnf install -y git

git clone https://github.com/c1t1d0s7/dotfiles.git
cd dotfiles
./install_linux.sh --dry
./install_linux.sh
chsh -s "$(command -v zsh)"  # Log out once after changing the login shell.
```

Linux에서는 `install_linux.sh`가 배포판을 감지해 빠진 `git`, `zsh`, `neovim`, `fzf`, `curl`,
`unzip`, `ca-certificates`, `coreutils`, `less`를 APT 또는 DNF로 설치합니다. Rocky Linux에서는
`chsh`를 제공하는 `util-linux-user`도 설치하고, `neovim`과 `fzf`를 위해 EPEL과
CRB(Rocky 8은 PowerTools)를 활성화합니다.
Oh My Posh는 [공식 Linux 설치 스크립트](https://ohmyposh.dev/docs/installation/linux)로
`~/.local/bin/oh-my-posh`에 설치합니다. `Brewfile`, Ghostty, VS Code 설정은 적용하지 않습니다.
프롬프트 아이콘을 표시하려면 접속하는 터미널에 Nerd Font가 필요합니다.

Linux의 기본 로그인 셸은 보통 Bash이므로 zsh도 설치 대상입니다. 다만 로그인 셸은 사용자
계정 설정이어서 스크립트가 자동으로 바꾸지 않고, 설치 후 실행할 `chsh` 명령만 안내합니다.

git 커밋 신원(계정·이름·이메일)은 실행 중에 물어봅니다. 미리 파일이나 환경변수로
넘기려면 [git 신원 설정](#git-신원-설정)을 참고하세요.

리포 파일을 홈으로 **복사**합니다(심볼릭 링크가 아닙니다). git 설정만 `~/.config/git/` 아래로 갑니다.
서드파티 플러그인은 리포 밖, `~/.config/zsh` 아래로 직접 받습니다.

두 설치 스크립트가 공통으로 받아오는 것:

- **oh-my-zsh 본체** → `~/.oh-my-zsh`. `.zshrc`가 이걸 소싱하므로 없으면
  프롬프트·플러그인은 물론 `$ZSH_CUSTOM/*.zsh`의 alias까지 통째로 안 뜹니다.
- **zsh 플러그인 3개** → `~/.config/zsh/plugins/`

이미 있으면 `git pull`로 갱신하므로 재실행해도 안전합니다.
하나가 실패해도 나머지와 설정 파일 복사는 그대로 진행하고, 마지막에 몇 개 실패했는지 알려주며 exit 1 합니다.

프롬프트 엔진 **oh-my-posh**는 macOS에서는 `Brewfile`, Linux에서는 공식 설치
스크립트로 설치하고, 이 리포의 설정을 `~/.config/oh-my-posh/config.omp.json`으로 복사합니다.

기존 파일은 덮어쓰지 않고 `~/.dotfiles-backup/<타임스탬프>/`로 옮깁니다.

## 구조

`→`는 복사 대상입니다. 고친 뒤 macOS는 `./install_macos.sh`, Linux는
`./install_linux.sh`를 다시 실행해야 반영됩니다.

```
zsh/
├── zshenv                  → ~/.zshenv        PATH, EDITOR, LANG (모든 zsh)
├── zshrc                   → ~/.zshrc         OMZ 뼈대 (대화형 셸)
└── custom/*.zsh            → ~/.config/zsh/   $ZSH_CUSTOM, OMZ가 자동 소싱
    ├── 10-aliases.zsh
    └── 20-history.zsh
oh-my-posh/
└── config.omp.json         → ~/.config/oh-my-posh/config.omp.json
git/
├── gitconfig               → ~/.config/git/config
├── gitignore_global        → ~/.config/git/ignore
└── gitmessage              → ~/.config/git/message   커밋 템플릿
ghostty/config.ghostty       → ~/.config/ghostty/       macOS에서만
vscode/                                                macOS에서만
├── settings.json           → ~/Library/Application Support/Code/User/settings.json
└── keybindings.json        → ~/Library/Application Support/Code/User/keybindings.json
Brewfile                                       macOS 패키지·VS Code 확장 목록
install_macos.sh                               macOS 설치 진입점
install_linux.sh                               Ubuntu/Debian/Rocky 설치 진입점
install_common.sh                              공통 설치 로직
```

리포에 없고 설치 스크립트가 `~/.config/zsh` 아래에 직접 받는 것:

```
~/.config/zsh/
└── plugins/{zsh-autosuggestions,zsh-completions,zsh-syntax-highlighting}/
```

### ghostty 설정이 `~/.config/ghostty/`에 있는 이유 (macOS)

ghostty는 설정을 **두 곳에서 읽고 나중 것이 이깁니다** — XDG 경로
(`$XDG_CONFIG_HOME/ghostty/` 또는 `~/.config/ghostty/`)를 먼저, macOS의
`~/Library/Application Support/com.mitchellh.ghostty/`를 나중에 읽습니다.

그래서 `install_macos.sh`가 Application Support 쪽 파일을 백업으로 치웁니다. 남겨두면
`~/.config/ghostty/`에 둔 설정이 통째로 가려집니다. git과 똑같은 함정입니다.

파일명은 `config.ghostty`입니다. ghostty 1.2.3부터 바뀐 이름이고 그 전에는
`config`였습니다 — 예전 이름의 파일도 같이 치웁니다.

### VS Code 설정이 `~/Library/Application Support/`에 있는 이유 (macOS)

**VS Code는 macOS에서 XDG를 보지 않습니다.** `~/.config/Code`를 만들어도 읽지 않고,
사용자 설정 경로는 `~/Library/Application Support/Code/User/` 한 곳뿐입니다. ghostty·git처럼
`~/.config` 아래로 맞출 수가 없어서 이것만 경로가 다릅니다.

**확장(extension)은 이 디렉터리가 아니라 `Brewfile`이 관리합니다.** `brew bundle dump`가
설치된 확장을 `vscode "publisher.name"` 줄로 뽑아주고, `brew bundle install`이 그대로 깝니다.
확장을 추가·삭제했으면 설정 파일이 아니라 Brewfile을 다시 dump 하세요.

두 파일 모두 JSONC라 **주석을 써도 됩니다.** 설정 UI에서 값을 바꿔도 VS Code가 주석을
지우지 않습니다. 다만 UI로 새로 추가한 항목은 파일 **맨 끝에** 붙으므로, 리포로 되가져올 때
알맞은 구역으로 옮겨주는 편이 좋습니다.

**기본값과 같은 값은 넣지 않습니다.** 동작은 그대로면서 무엇을 일부러 바꿨는지만 가려집니다.
설정 UI에서 항목 왼쪽에 파란 줄이 없으면 기본값이고, 확장 설정은
`~/.vscode/extensions/<확장>/package.json`의 `default`로 확인합니다.

예외가 하나 있습니다. `yaml.disableSchemaDetection`은 **확장이 스스로 써넣는 값**입니다
(`redhat.vscode-yaml`이 `github.vscode-github-actions` 설치 여부에 따라 글롭을 넣고 뺍니다).
리포에서 빼면 VS Code가 다시 써넣어 `./install_macos.sh --dry`가 영영 `(differs)`로 뜨므로,
확장이 만드는 값 그대로 둡니다.

> 설정 파일을 VS Code 편집기에 열어둔 채 `./install_macos.sh`를 돌리면, 디스크가 바뀐 걸
> 감지해 편집기 내용이 갱신됩니다. 저장 안 한 수정이 있다면 먼저 정리하세요.

`snippets/`, `profiles/`, `globalStorage/` 등 나머지는 추적하지 않습니다 — 대부분 VS Code가
스스로 쓰는 상태 파일입니다. 스니펫을 관리하고 싶어지면 `install_common.sh`의 `FILES`에 줄을 더하세요.

### git 설정이 `~/.config/git/`에 있는 이유

홈 최상위에 Git 설정 파일을 늘어놓는 대신 한 디렉터리로 모았습니다.
파일명은 git이 정한 규약을 그대로 씁니다:

| 파일 | 비고 |
|---|---|
| `config` | `~/.gitconfig`와 **둘 다 읽히고** `~/.gitconfig`가 이깁니다 |
| `ignore` | `core.excludesFile`의 기본값 — 설정 줄 자체가 필요 없습니다 |
| `message` | 기본값이 없어 `commit.template`이 이 경로를 가리킵니다 |

첫 줄이 중요합니다. **`~/.gitconfig`가 남아 있으면 여기 설정이 통째로 가려집니다.**
그래서 설치 스크립트가 예전 위치의 파일들을 백업으로 치웁니다. 신원 파일은 버리지 않고
새 위치로 옮기므로 다시 입력할 필요가 없습니다 — 예전 구조의 '기본 신원'만 어느 계정
것인지 정보가 없어서 한 번 물어봅니다.

`~/.gitconfig`가 없으면 `git config --global`도 `~/.config/git/config`에 씁니다.

> `XDG_CONFIG_HOME`을 `~/.config`가 아닌 값으로 쓰면 git이 이 파일들을 못 찾습니다.
> 리포에 경로가 문자열로 박혀 있어 자동으로 따라가지 않습니다. 설치 스크립트가 경고합니다.

### git 신원 설정

GitHub 계정과 SSH 키는 하나입니다. **리포의 위치가 커밋 이름·이메일을 정합니다.**

계정(또는 조직) 하나당 신원 하나입니다. 이름 하나가 세 곳을 동시에 정합니다:

| | |
|---|---|
| `~/git/<계정>/` | 이 아래 리포만 그 신원으로 커밋됩니다 |
| `~/.config/git/identity-<계정>` | 그 계정의 이름·이메일 |
| `github.com/<계정>/` | 디렉터리 이름 = GitHub 계정/조직 이름 |

**기본 신원은 없습니다.** `~/git/<등록한 계정>/` 밖에서는 커밋이 거부됩니다:

```
$ git commit -m "..."          # From ~/tmp/scratch.
fatal: no email was given and auto-detection is disabled
```

의도한 동작입니다. 회사 리포를 엉뚱한 곳에 클론했을 때 **조용히 개인 이메일로
커밋되는 것**보다 멈추는 편이 낫습니다. 잘못 박힌 신원은 rebase로만 고칠 수 있습니다.

막혔을 때 대처는 둘입니다. 리포를 `~/git/<계정>/` 아래로 옮기거나, 그 리포에만
지정하는 것입니다:

```bash
git config user.name  "Your Name"      # Do not add --global.
git config user.email you@example.com
```

> git이 출력하는 안내는 `--global`을 쓰라고 합니다. 그대로 하면
> `~/.config/git/config`에 쓰이는데, 이 파일은 리포에서 복사되므로 다음
> 다음 설치 때 사라집니다. 게다가 전역 기본값이 생겨 위 안전장치가 무너집니다.

막는 건 **커밋뿐**입니다. clone·fetch·push·status·log는 어디서든 정상입니다.

설치 스크립트가 **변수로 받고, 비어 있는 값만 물어봅니다.**

| 변수 | 값 |
|---|---|
| `GIT_PERSONAL_ACCOUNT` | 개인 GitHub 계정 (= `~/git/<계정>/`) |
| `GIT_PERSONAL_NAME` | 커밋 이름 |
| `GIT_PERSONAL_EMAIL` | 커밋 이메일 |
| `GIT_ORG_ACCOUNT` | 조직 이름 (= `~/git/<조직>/`) |
| `GIT_ORG_NAME` | 그 조직에서 쓸 커밋 이름 |
| `GIT_ORG_EMAIL` | 그 조직에서 쓸 커밋 이메일 |

우선순위는 **환경변수 > 설정 파일 > 입력**입니다. 셋 다 없으면 물어보고,
비대화형(CI, `curl | bash`)에서 물어볼 수 없으면 그 항목을 건너뜁니다.
Git identity가 필요 없으면 첫 `Your GitHub account` 질문에서 Enter를 눌러 전체 설정을
건너뛸 수 있습니다. 이 경우 Git의 이름과 이메일은 생성하지 않습니다.

**설정 파일**은 셸 조각이라 그대로 `source` 합니다. 기본 경로는 리포 안의
`install.conf`이고 `.gitignore`에 걸려 있습니다:

```bash
cat > install.conf <<'EOF'
GIT_PERSONAL_ACCOUNT=c1t1d0s7
GIT_PERSONAL_NAME="Your Name"
GIT_PERSONAL_EMAIL=you@example.com
GIT_ORG_ACCOUNT=acme-labs
GIT_ORG_NAME="Your Name"
GIT_ORG_EMAIL=you@company.example
EOF

./install_macos.sh                          # Reads install.conf automatically.
./install_macos.sh --config ~/my.conf       # Use another file.
DOTFILES_CONF=~/my.conf ./install_macos.sh  # Or set it through the environment.
```

Linux에서는 위 명령의 `./install_macos.sh`를 `./install_linux.sh`로 바꿉니다.

> `source` 이므로 파일 안의 임의의 명령이 실행됩니다. 남이 준 파일을 그냥 넘기지 마세요.
> `--config`로 지정한 파일이 없으면 조용히 넘어가지 않고 `exit 2` 합니다.

한 번에 지정할 수 있는 조직은 하나입니다. **둘 이상은 대화형으로 계속 물어봅니다** —
엔터로 끝낼 때까지 반복합니다:

```
git identity:
  One identity per GitHub account or organization. The name you enter sets
  both ~/git/<name>/ and the identity file — repos elsewhere cannot commit.
  Your GitHub account (empty to skip): c1t1d0s7
    Commit name for c1t1d0s7: Your Name
    Commit email for c1t1d0s7: you@example.com

  Organization on GitHub (empty to skip): acme-labs
    Commit name for acme-labs: Your Name
    Commit email for acme-labs: you@company.example

  Organization on GitHub (empty to finish):
```

계정 이름은 GitHub 규약으로 검증합니다 — 영숫자와 하이픈, 하이픈으로 시작·끝 불가,
39자 이하. 첫 질문에서 Enter를 누르면 설정을 건너뛰고, 계정을 선택한 뒤의 이름과 이메일은
빈 값으로 저장하지 않습니다. 형식이 틀리면 다시 물어봅니다.

`~/.config/git/identity`가 이미 있으면 묻지 않고 넘어갑니다. 다시 설정하려면 그 파일을
지우고 재실행하세요.

생성 결과는 이렇게 생겼습니다:

```ini
# ~/.config/git/identity — no default [user].
[includeIf "gitdir:~/git/c1t1d0s7/"]
	path = ~/.config/git/identity-c1t1d0s7

[includeIf "gitdir:~/git/acme-labs/"]
	path = ~/.config/git/identity-acme-labs
```

`~/.config/git/config`가 `[include]`로 이 파일을 항상 걸고, `user.useConfigOnly = true`가
폴백을 막습니다. git이 이메일을 `사용자@호스트명`으로 지어내는 걸 막는 설정입니다.

### zsh 파일이 나뉜 이유

| 파일 | 실행 시점 | 넣을 것 |
|---|---|---|
| `.zshenv` | 모든 zsh (스크립트, `zsh -c` 포함) | 환경변수 |
| `.zshrc` | 대화형 셸만 | 플러그인, alias, 프롬프트 |

PATH를 `.zshrc`에 두면 스크립트에서 Homebrew나 `~/.local/bin` 도구를 못 찾습니다.
우선순위는 `~/go/bin`, `~/.local/bin`, Homebrew, 시스템 경로 순입니다.
Zsh의 `path` 배열은 export된 `PATH`와 연결되어 있어 별도의 `export PATH`는 필요하지 않습니다.
VS Code가 시작 파일 실행 후 PATH를 주입하는 경우에는 첫 프롬프트에서 이 순서를 한 번 더 적용합니다.

### `$ZSH_CUSTOM`

oh-my-zsh는 `$ZSH_CUSTOM/*.zsh`를 알파벳 순으로 자동 소싱합니다(플러그인 로드 후, 테마 로드 전).
기본값 `~/.oh-my-zsh/custom` 대신 `~/.config/zsh`를 쓰므로,
**플러그인도 이 아래**에 있어야 합니다. 없으면 조용히 로드되지 않습니다.

파일명 앞의 번호는 소싱 순서용입니다.

### Homebrew completion (macOS)

로그인 셸은 `/bin/zsh`(애플 시스템 zsh)입니다. homebrew가 설치한 zsh를 로그인 셸로 쓰면
`$HOMEBREW_PREFIX/share/zsh/site-functions`가 기본 `fpath`에 들어가지만, 시스템 zsh는 아닙니다.
그래서 `.zshrc`가 `oh-my-zsh.sh` 소싱 **전에** 이 경로를 직접 넣어줍니다.
빠뜨리면 `gh`, `argocd`, `eksctl`, `istioctl`, `k9s` 등의 completion이 조용히 안 먹습니다.

## 관리

**설정은 리포에서 고치고 설치 스크립트로 반영합니다.** 복사 방식이라 방향이 한쪽입니다 —
`~/.zshrc`를 직접 고쳐도 리포에 올라오지 않고, 다음 설치 때 백업으로 밀려납니다.
아래 명령은 macOS 기준이며 Linux에서는 `./install_linux.sh`를 사용합니다.

```bash
# Edit a config.
vi zsh/zshrc
./install_macos.sh --dry     # Preview changes.
./install_macos.sh

# Find files that differ from the repository.
./install_macos.sh --dry

# Copy a home-side change back to the repository.
cp ~/.zshrc zsh/zshrc && git diff

# Copy VS Code settings changed through the UI.
cp "$HOME/Library/Application Support/Code/User/settings.json" vscode/settings.json && git diff

# Refresh packages and VS Code extensions.
brew bundle dump --force --file=Brewfile

# Update plugins.
./install_macos.sh
```

## 주의

- `.gitignore`에 토큰류 패턴이 있지만, 커밋 전 `git diff --cached` 확인 습관을 들이세요.
- `~/.aws`, `~/.kube`, `~/.ssh`, `~/.config/gh`는 의도적으로 추적하지 않습니다.
