#!/usr/bin/env bash
# 把 AI 協作流程裝進一個專案：複製呼叫端的 workflow 與 issue 範本、鎖定共用流程的版本、建好標籤。
# 用法：scripts/install.sh <專案目錄> [--repo <owner/repo>] [--ref <commit>] [--force] [--no-labels]
#   --repo       呼叫端要引用的共用流程 repo，預設是這個 repo 的 origin（fork 的話就是你的 fork）
#   --ref        呼叫端鎖定的共用流程版本：版本號（例如 v0.1.0）或 commit。預設是最新的版本號（還沒有版本號時用 HEAD）
#                呼叫檔一律寫成 commit 編號，有版本號時在後面加註解（例如 @<commit> # v0.1.0）
#   --force      專案裡已經有同名檔案時覆蓋（預設不覆蓋，只列出來）
#   --no-labels  不建標籤
# 只複製檔案、建標籤，不 commit、不 push；secrets 要使用者自己存（見 README.md「安裝到一個專案」）
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
target="" repo_src="" ref="" force=false labels=true
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo_src=$2; shift 2 ;;
    --ref) ref=$2; shift 2 ;;
    --force) force=true; shift ;;
    --no-labels) labels=false; shift ;;
    -*) echo "不認得的參數：$1" >&2; exit 2 ;;
    *) target=$1; shift ;;
  esac
done
[ -n "$target" ] || { sed -n 2,9p "$0" >&2; exit 2; }
[ -d "$target/.git" ] || { echo "$target 不是 git repo" >&2; exit 1; }

if [ -z "$repo_src" ]; then
  url=$(git -C "$here" remote get-url origin 2>/dev/null) || { echo "這個 repo 沒有 origin，用 --repo 指定共用流程的 repo" >&2; exit 1; }
  # https://github.com/owner/repo(.git) 或 git@github.com:owner/repo(.git)
  repo_src=$(sed -E 's#^(https://github\.com/|git@github\.com:)##; s#\.git$##' <<<"$url")
fi
[[ "$repo_src" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "共用流程的 repo 格式不對：${repo_src}（要是 owner/repo）" >&2; exit 1; }

if [ -z "$ref" ]; then
  ref=$(git -C "$here" tag -l 'v*' --sort=-v:refname | head -1)
  [ -n "$ref" ] || ref=HEAD
fi
sha=$(git -C "$here" rev-parse --verify -q "${ref}^{commit}") || { echo "找不到版本 ${ref}（先 git pull --tags 更新這個 repo）" >&2; exit 1; }
tag=$(git -C "$here" tag -l 'v*' --points-at "$sha" --sort=-v:refname | head -1)
# 呼叫端要拿得到這個 commit：確認已經 push（在遠端的分支上，或遠端有這個版本號）
if ! git -C "$here" branch -r --contains "$sha" 2>/dev/null | grep -q . &&
   ! { [ -n "$tag" ] && git -C "$here" ls-remote --exit-code --tags origin "refs/tags/$tag" > /dev/null 2>&1; }; then
  echo "共用流程的 commit ${sha:0:7} 還沒 push 到 GitHub，先 push 再裝（或用 --ref 指定已 push 的版本）" >&2
  exit 1
fi
# 呼叫檔寫 commit 編號（版本號事後可以被移動，commit 不會）；有版本號時加註解，看得出是哪一版，Dependabot 也認得
pin=$sha${tag:+ # $tag}

copy() {
  src=$1 dst=$target/$2
  if [ -e "$dst" ] && [ "$force" != true ]; then
    echo "略過（已存在，加 --force 覆蓋）：$2"; return
  fi
  mkdir -p "$(dirname "$dst")"
  sed -e "s/__AI_DEV_FLOW_REF__/$pin/g" -e "s#__AI_DEV_FLOW_REPO__#$repo_src#g" "$src" > "$dst"
  echo "寫入：$2"
}
copy "$here/templates/workflows/ai-dev.yml" .github/workflows/ai-dev.yml
copy "$here/templates/workflows/ai-review.yml" .github/workflows/ai-review.yml
for f in ai-bug.md ai-feature.md idea.md; do
  copy "$here/templates/ISSUE_TEMPLATE/$f" ".github/ISSUE_TEMPLATE/$f"
done
if [ -d "$here/skills/agent-flow-issue" ]; then
  mkdir -p "$target/.agents/skills/agent-flow-issue"
  cp -r "$here/skills/agent-flow-issue/"* "$target/.agents/skills/agent-flow-issue/"
  echo "寫入 Skill：.agents/skills/agent-flow-issue"
fi
echo "共用流程：${repo_src}@${sha}${tag:+（${tag}）}"
echo "規則段落範本：$here/templates/AGENTS-ai-flow.md（依專案改寫後貼進 AGENTS.md）"

if [ "$labels" = true ]; then
  repo=$(cd "$target" && gh repo view --json nameWithOwner -q .nameWithOwner)
  echo "在 $repo 建標籤（已存在的會更新顏色與說明；其他 AI 服務的 ai:<名稱> 標籤見 docs/providers.md）："
  while IFS='|' read -r name color desc; do
    gh label create "$name" -R "$repo" --color "$color" --description "$desc" --force > /dev/null && echo "  $name"
  done <<'LABELS'
bug|d73a4a|修錯誤：已規劃好、驗收條件寫好了（加上本身不會開工）
feature|a2eeef|新功能：已規劃好、驗收條件寫好了（加上本身不會開工）
ai:claude|5319e7|開工：用 Claude 訂閱（雲端執行）
ai:agy|5319e7|開工：用 agy（Google Antigravity）訂閱（需 self-hosted runner）
model:claude-opus-5-5|c5def5|指定模型：Claude Opus 5.5（選用）
model:claude-sonnet-5-5|c5def5|指定模型：Claude Sonnet 5.5（選用）
model:gemini-2.5-pro|c5def5|指定模型：Gemini 2.5 Pro（選用）
model:gemini-3.8-flash|c5def5|指定模型：Gemini 3.8 Flash（選用）
blocked|b60205|AI 做不出來，等使用者處理
round-1|fbca04|審查／測試後自動修改第 1 輪（workflow 管理）
round-2|fbca04|審查／測試後自動修改第 2 輪（workflow 管理）
round-3|fbca04|審查／測試後自動修改第 3 輪（workflow 管理）
LABELS
fi
