# 히스토리 — OMZ 기본값(SAVEHIST=10000)은 CLI를 많이 쓰면 금방 찬다.
HISTSIZE=100000
SAVEHIST=100000

setopt HIST_IGNORE_ALL_DUPS   # 중복 명령은 이전 것을 지우고 최신만 남김
setopt HIST_REDUCE_BLANKS     # 불필요한 공백 제거
setopt HIST_VERIFY            # !! 확장 시 바로 실행 않고 한 번 보여줌
setopt SHARE_HISTORY          # 여러 셸 간 히스토리 실시간 공유
