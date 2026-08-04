# dotfiles

macOS (Apple Silicon) 개발 환경 설정.

## 설치

```bash
git clone https://github.com/c1t1d0s7/dotfiles.git
cd dotfiles
./install.sh --dry     # 무엇이 바뀌는지 먼저 확인
./install.sh           # oh-my-zsh + 플러그인 클론 + 설정 파일 복사
brew bundle install --file=Brewfile
```

git 커밋 신원(계정·이름·이메일)은 실행 중에 물어봅니다. 미리 파일이나 환경변수로
넘기려면 [git 신원 설정](#git-신원-설정)을 참고하세요.

리포 파일을 홈으로 **복사**합니다(심볼릭 링크가 아닙니다). git 설정만 `~/.config/git/` 아래로 갑니다.
서드파티 플러그인은 리포 밖, `~/.config/zsh` 아래로 직접 받습니다.

`install.sh`가 받아오는 것:

- **oh-my-zsh 본체** → `~/.oh-my-zsh`. `.zshrc`가 이걸 소싱하므로 없으면
  프롬프트·플러그인은 물론 `$ZSH_CUSTOM/*.zsh`의 alias까지 통째로 안 뜹니다.
- **zsh 플러그인 3개** → `~/.config/zsh/plugins/`
- **powerlevel10k** → `~/.config/zsh/themes/`

이미 있으면 `git pull`로 갱신하므로 재실행해도 안전합니다.
하나가 실패해도 나머지와 설정 파일 복사는 그대로 진행하고, 마지막에 몇 개 실패했는지 알려주며 exit 1 합니다.

기존 파일은 덮어쓰지 않고 `~/.dotfiles-backup/<타임스탬프>/`로 옮깁니다.

## 구조

`→`는 복사 대상입니다. 고친 뒤 `./install.sh`를 다시 실행해야 반영됩니다.

```
zsh/
├── zshenv                  → ~/.zshenv        PATH, EDITOR, LANG (모든 zsh)
├── zshrc                   → ~/.zshrc         OMZ 뼈대 (대화형 셸)
├── p10k.zsh                → ~/.p10k.zsh      프롬프트 외형
└── custom/*.zsh            → ~/.config/zsh/   $ZSH_CUSTOM, OMZ가 자동 소싱
    ├── 10-aliases.zsh
    └── 20-history.zsh
git/
├── gitconfig               → ~/.config/git/config
├── gitignore_global        → ~/.config/git/ignore
└── gitmessage              → ~/.config/git/message   커밋 템플릿
ghostty/config.ghostty       → ~/.config/ghostty/
Brewfile                                       brew bundle dump 결과
```

리포에 없고 `install.sh`가 `~/.config/zsh` 아래에 직접 받는 것:

```
~/.config/zsh/
├── plugins/{zsh-autosuggestions,zsh-completions,zsh-syntax-highlighting}/
└── themes/powerlevel10k/
```

### ghostty 설정이 `~/.config/ghostty/`에 있는 이유

ghostty는 설정을 **두 곳에서 읽고 나중 것이 이깁니다** — XDG 경로
(`$XDG_CONFIG_HOME/ghostty/` 또는 `~/.config/ghostty/`)를 먼저, macOS의
`~/Library/Application Support/com.mitchellh.ghostty/`를 나중에 읽습니다.

그래서 `install.sh`가 Application Support 쪽 파일을 백업으로 치웁니다. 남겨두면
`~/.config/ghostty/`에 둔 설정이 통째로 가려집니다. git과 똑같은 함정입니다.

파일명은 `config.ghostty`입니다. ghostty 1.2.3부터 바뀐 이름이고 그 전에는
`config`였습니다 — 예전 이름의 파일도 같이 치웁니다.

### git 설정이 `~/.config/git/`에 있는 이유

홈 최상위에 `.gitconfig*` 다섯 개를 늘어놓는 대신 한 디렉터리로 모았습니다.
파일명은 git이 정한 규약을 그대로 씁니다:

| 파일 | 비고 |
|---|---|
| `config` | `~/.gitconfig`와 **둘 다 읽히고** `~/.gitconfig`가 이깁니다 |
| `ignore` | `core.excludesFile`의 기본값 — 설정 줄 자체가 필요 없습니다 |
| `message` | 기본값이 없어 `commit.template`이 이 경로를 가리킵니다 |

첫 줄이 중요합니다. **`~/.gitconfig`가 남아 있으면 여기 설정이 통째로 가려집니다.**
그래서 `install.sh`가 예전 위치의 파일들을 백업으로 치웁니다. 신원 파일은 버리지 않고
새 위치로 옮기므로 다시 입력할 필요가 없습니다 — 예전 구조의 '기본 신원'만 어느 계정
것인지 정보가 없어서 한 번 물어봅니다.

`~/.gitconfig`가 없으면 `git config --global`도 `~/.config/git/config`에 씁니다.

> `XDG_CONFIG_HOME`을 `~/.config`가 아닌 값으로 쓰면 git이 이 파일들을 못 찾습니다.
> 리포에 경로가 문자열로 박혀 있어 자동으로 따라가지 않습니다. `install.sh`가 경고합니다.

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
$ git commit -m "..."          # ~/tmp/scratch 에서
fatal: no email was given and auto-detection is disabled
```

의도한 동작입니다. 회사 리포를 엉뚱한 곳에 클론했을 때 **조용히 개인 이메일로
커밋되는 것**보다 멈추는 편이 낫습니다. 잘못 박힌 신원은 rebase로만 고칠 수 있습니다.

막혔을 때 대처는 둘입니다. 리포를 `~/git/<계정>/` 아래로 옮기거나, 그 리포에만
지정하는 것입니다:

```bash
git config user.name  "Your Name"      # --global 을 붙이면 안 됩니다
git config user.email you@example.com
```

> git이 출력하는 안내는 `--global`을 쓰라고 합니다. 그대로 하면
> `~/.config/git/config`에 쓰이는데, 이 파일은 리포에서 복사되므로 다음
> `./install.sh` 때 사라집니다. 게다가 전역 기본값이 생겨 위 안전장치가 무너집니다.

막는 건 **커밋뿐**입니다. clone·fetch·push·status·log는 어디서든 정상입니다.

`install.sh`가 **변수로 받고, 비어 있는 값만 물어봅니다.**

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

./install.sh                          # install.conf 를 자동으로 읽습니다
./install.sh --config ~/my.conf       # 다른 파일을 쓰려면
DOTFILES_CONF=~/my.conf ./install.sh  # 환경변수로 지정해도 됩니다
```

> `source` 이므로 파일 안의 임의의 명령이 실행됩니다. 남이 준 파일을 그냥 넘기지 마세요.
> `--config`로 지정한 파일이 없으면 조용히 넘어가지 않고 `exit 2` 합니다.

한 번에 지정할 수 있는 조직은 하나입니다. **둘 이상은 대화형으로 계속 물어봅니다** —
엔터로 끝낼 때까지 반복합니다:

```
git identity:
  One identity per GitHub account or organization. The name you enter sets
  both ~/git/<name>/ and the identity file — repos elsewhere cannot commit.
  Your GitHub account: c1t1d0s7
    Commit name for c1t1d0s7: Your Name
    Commit email for c1t1d0s7: you@example.com

  Organization on GitHub (empty to skip): acme-labs
    Commit name for acme-labs: Your Name
    Commit email for acme-labs: you@company.example

  Organization on GitHub (empty to finish):
```

계정 이름은 GitHub 규약으로 검증합니다 — 영숫자와 하이픈, 하이픈으로 시작·끝 불가,
39자 이하. **입력에 기본값은 없습니다.** 엔터로 넘긴 값이 그대로 커밋에 박히는 것보다
낫다고 봤습니다. 형식이 틀리면 다시 물어봅니다.

`~/.config/git/identity`가 이미 있으면 묻지 않고 넘어갑니다. 다시 설정하려면 그 파일을
지우고 재실행하세요.

생성 결과는 이렇게 생겼습니다:

```ini
# ~/.config/git/identity — 기본 [user] 가 없다
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

PATH를 `.zshrc`에 두면 스크립트에서 homebrew 도구를 못 찾습니다.

### `$ZSH_CUSTOM`

oh-my-zsh는 `$ZSH_CUSTOM/*.zsh`를 알파벳 순으로 자동 소싱합니다(플러그인 로드 후, 테마 로드 전).
기본값 `~/.oh-my-zsh/custom` 대신 `~/.config/zsh`를 쓰므로,
**플러그인과 테마도 이 아래**에 있어야 합니다. 없으면 조용히 로드되지 않습니다.

파일명 앞의 번호는 소싱 순서용입니다.

### brew completion

로그인 셸은 `/bin/zsh`(애플 시스템 zsh)입니다. homebrew가 설치한 zsh를 로그인 셸로 쓰면
`$HOMEBREW_PREFIX/share/zsh/site-functions`가 기본 `fpath`에 들어가지만, 시스템 zsh는 아닙니다.
그래서 `.zshrc`가 `oh-my-zsh.sh` 소싱 **전에** 이 경로를 직접 넣어줍니다.
빠뜨리면 `gh`, `argocd`, `eksctl`, `istioctl`, `k9s` 등의 completion이 조용히 안 먹습니다.

## 관리

**설정은 리포에서 고치고 `./install.sh`로 반영합니다.** 복사 방식이라 방향이 한쪽입니다 —
`~/.zshrc`를 직접 고쳐도 리포에 올라오지 않고, 다음 `install.sh` 때 백업으로 밀려납니다.

```bash
# 설정 수정
vi zsh/zshrc
./install.sh --dry     # 어디가 바뀌는지 확인
./install.sh

# 홈과 리포가 어긋났는지 확인 — "(differs)"로 표시됩니다
./install.sh --dry

# 홈 쪽에서 먼저 고쳐버렸다면 리포로 되가져오기
cp ~/.zshrc zsh/zshrc && git diff

# 패키지 목록 갱신
brew bundle dump --force --file=Brewfile

# 플러그인/테마 업데이트 (install.sh가 알아서 pull 한다)
./install.sh
```

## 주의

- `.gitignore`에 토큰류 패턴이 있지만, 커밋 전 `git diff --cached` 확인 습관을 들이세요.
- `~/.aws`, `~/.kube`, `~/.ssh`, `~/.config/gh`는 의도적으로 추적하지 않습니다.
