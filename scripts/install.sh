#!/usr/bin/env bash
# 把 AI 協作流程裝進一個專案：複製呼叫端的 workflow 與 issue 範本、鎖定共用流程的版本、寫入規則段落、建好標籤。
# 用法：scripts/install.sh <專案目錄> [--repo <owner/repo>] [--ref <版本號>] [--force] [--no-labels] [--no-rules]
#   --repo       呼叫端要引用的共用流程 repo，預設是這個 repo 的 origin（fork 的話就是你的 fork）
#   --ref        呼叫端鎖定的共用流程版本號（例如 v0.1.0），預設是最新的版本號
#                也可以給 commit，但那個 commit 必須已經有版本號；沒有任何版本號時會報錯
#                呼叫檔一律寫成版本號（例如 @v0.1.0）；版本號可以被移動，確保這個 repo 的寫入權限只有信任的人
#   --force      專案裡已經有同名檔案時覆蓋（預設不覆蓋，只列出來）
#   --no-labels  不建標籤
#   --no-rules   不把規則段落寫進專案的 AGENTS.md
# 只複製檔案、寫規則段落、建標籤，不 commit、不 push；secrets 要使用者自己存（見 README.md「安裝到一個專案」）
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
target="" repo_src="" ref="" force=false labels=true rules=true
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo_src=$2; shift 2 ;;
    --ref) ref=$2; shift 2 ;;
    --force) force=true; shift ;;
    --no-labels) labels=false; shift ;;
    --no-rules) rules=false; shift ;;
    -*) echo "不認得的參數：$1" >&2; exit 2 ;;
    *) target=$1; shift ;;
  esac
done
[ -n "$target" ] || { sed -n 2,10p "$0" >&2; exit 2; }
[ -d "$target/.git" ] || { echo "$target 不是 git repo" >&2; exit 1; }

if [ -z "$repo_src" ]; then
  url=$(git -C "$here" remote get-url origin 2>/dev/null) || { echo "這個 repo 沒有 origin，用 --repo 指定共用流程的 repo" >&2; exit 1; }
  # https://github.com/owner/repo(.git) 或 git@github.com:owner/repo(.git)
  repo_src=$(sed -E 's#^(https://github\.com/|git@github\.com:)##; s#\.git$##' <<<"$url")
fi
[[ "$repo_src" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "共用流程的 repo 格式不對：${repo_src}（要是 owner/repo）" >&2; exit 1; }

if [ -z "$ref" ]; then
  ref=$(git -C "$here" tag -l 'v*' --sort=-v:refname | head -1)
  [ -n "$ref" ] || { echo "這個 repo 還沒有版本號（v*），先打 tag 並 push 再裝" >&2; exit 1; }
fi
sha=$(git -C "$here" rev-parse --verify -q "${ref}^{commit}") || { echo "找不到版本 ${ref}（先 git pull --tags 更新這個 repo）" >&2; exit 1; }
tag=$(git -C "$here" tag -l 'v*' --points-at "$sha" --sort=-v:refname | head -1)
[ -n "$tag" ] || { echo "commit ${sha:0:7} 沒有版本號（v*），不能綁定；先打 tag，或用 --ref 指定一個版本號" >&2; exit 1; }
# 呼叫端要拿得到這個版本：確認版本號已經 push 到遠端
git -C "$here" ls-remote --exit-code --tags origin "refs/tags/$tag" > /dev/null 2>&1 \
  || { echo "版本號 ${tag} 還沒 push 到 GitHub，先 git push origin ${tag} 再裝" >&2; exit 1; }
# 呼叫檔直接寫版本號
pin=$tag

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
  # 先清掉舊的再複製，避免舊版留下的檔案（例如以前的 templates/）殘留
  rm -rf "$target/.agents/skills/agent-flow-issue"
  mkdir -p "$target/.agents/skills/agent-flow-issue"
  cp -r "$here/skills/agent-flow-issue/"* "$target/.agents/skills/agent-flow-issue/"
  echo "寫入 Skill：.agents/skills/agent-flow-issue"
fi
echo "共用流程：${repo_src}@${tag}（commit ${sha:0:7}）"

# 把規則段落寫進專案的 AGENTS.md（沒有就看 CLAUDE.md，都沒有就建立 AGENTS.md）
# 用標記包起來：重跑時整段更新，標記以外的內容不動
if [ "$rules" = true ]; then
  rules_dst=""
  for f in AGENTS.md CLAUDE.md; do
    [ -f "$target/$f" ] && { rules_dst="$target/$f"; break; }
  done
  [ -n "$rules_dst" ] || rules_dst="$target/AGENTS.md"

  block=$(mktemp)
  {
    echo "<!-- agent-flow:begin ${tag} -->"
    sed -e "s/__AI_DEV_FLOW_REF__/$pin/g" "$here/templates/AGENTS-ai-flow.md"
    echo "<!-- agent-flow:end -->"
  } > "$block"

  if [ -f "$rules_dst" ] && grep -q '<!-- agent-flow:begin' "$rules_dst" && grep -q '<!-- agent-flow:end -->' "$rules_dst"; then
    tmp=$(mktemp)
    awk -v blk="$block" '
      /<!-- agent-flow:begin/ { while ((getline line < blk) > 0) print line; skip=1; next }
      /<!-- agent-flow:end -->/ { skip=0; next }
      !skip { print }
    ' "$rules_dst" > "$tmp"
    cat "$tmp" > "$rules_dst"; rm -f "$tmp"
    echo "更新規則段落：${rules_dst#"$target"/}"
  else
    { [ -s "$rules_dst" ] && echo; cat "$block"; } >> "$rules_dst"
    echo "寫入規則段落：${rules_dst#"$target"/}"
  fi
  rm -f "$block"
  echo "（AGENTS.md／CLAUDE.md 是受保護檔案，要直接 commit 到預設分支，不能走 AI 開 PR）"
fi

if [ "$labels" = true ]; then
  repo=$(cd "$target" && gh repo view --json nameWithOwner -q .nameWithOwner)
  echo "在 $repo 建標籤（已存在的會更新顏色與說明；其他 AI 服務的 ai:<名稱> 標籤見 docs/providers.md）："
  while IFS='|' read -r name color desc; do
    gh label create "$name" -R "$repo" --color "$color" --description "$desc" --force > /dev/null && echo "  $name"
  done <<'LABELS'
bug|d73a4a|Bug fix: planned with clear acceptance criteria (does not trigger AI alone)
feature|a2eeef|New feature: planned with clear acceptance criteria (does not trigger AI alone)
draft|cfd3d7|Draft issue: work in progress, blocks AI triggers even if ai:* is set
idea|cfd3d7|Idea issue: brainstorming phase, blocks AI triggers even if ai:* is set
ai:claude|5319e7|Trigger AI: run via Claude Code subscription (cloud runner)
ai:agy|5319e7|Trigger AI: run via agy (Google Antigravity) subscription (self-hosted runner)
model:claude-opus-5-5|c5def5|Specify model: Claude Opus 5.5 (optional)
model:claude-sonnet-5-5|c5def5|Specify model: Claude Sonnet 5.5 (optional)
model:gemini-2.5-pro|c5def5|Specify model: Gemini 2.5 Pro (optional)
model:gemini-3.8-flash|c5def5|Specify model: Gemini 3.8 Flash (optional)
effort:low|bfdadc|Specify agy reasoning effort: low (optional)
effort:medium|bfdadc|Specify agy reasoning effort: medium (optional)
effort:high|bfdadc|Specify agy reasoning effort: high (optional)
effort:xhigh|bfdadc|Specify agy reasoning effort: xhigh (optional)
blocked|b60205|AI unable to proceed, waiting for human intervention
round-1|fbca04|Auto-revision round 1 after review/tests (managed by workflow)
round-2|fbca04|Auto-revision round 2 after review/tests (managed by workflow)
round-3|fbca04|Auto-revision round 3 after review/tests (managed by workflow)
LABELS
fi
