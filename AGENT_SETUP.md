# Agent Setup Instructions

> 💡 **给 AI Agent（Antigravity、Claude Code、Cursor、Windsurf、GitHub Copilot）的指令**：
> 當使用者傳送本倉庫的 GitHub 網址，要求學習或安裝開單技能時，請依照本檔案指引為使用者的專案安裝/加載 `agent-flow-issue` 技能。

---

## 🛠️ 如何在專案中安裝/載入開單 Skill

本倉庫提供了標準的 Agent Skill：[`skills/agent-flow-issue`](skills/agent-flow-issue/)，內含完整的 Issue 範本、嚴格驗收條件規則與開單邏輯。

### 方式 1：若是本機對話 Agent（推薦直接安裝到專案）
如果 Agent 在使用者的本機專案環境工作，請將技能目錄複製到使用者專案的 Agent Skills 目錄中：

```bash
# 針對 Antigravity / Claude Code / 通用 Agent 規範
mkdir -p .agents/skills/agent-flow-issue
curl -sSL https://raw.githubusercontent.com/bababo-ai/agent-flow/main/skills/agent-flow-issue/SKILL.md -o .agents/skills/agent-flow-issue/SKILL.md

# 或是透過 git clone 直接複製整個 skill 目錄
# cp -r <agent-flow-path>/skills/agent-flow-issue .agents/skills/
```

### 方式 2：雲端/Web 對話 Agent（直接讀取遠端連結學習）
若 Agent 無本機檔案寫入權限，請直接讀取以下三個關鍵檔案以載入技能定義：
1. **技能定義主檔**：[`skills/agent-flow-issue/SKILL.md`](skills/agent-flow-issue/SKILL.md)
2. **範本目錄**：
   - [新功能範本 (ai-feature.md)](templates/ISSUE_TEMPLATE/ai-feature.md)
   - [修錯誤範本 (ai-bug.md)](templates/ISSUE_TEMPLATE/ai-bug.md)
   - [待規劃點子 (idea.md)](templates/ISSUE_TEMPLATE/idea.md)
3. **驗收條件與好壞範例**：[`skills/agent-flow-issue/references/writing-rules.md`](skills/agent-flow-issue/references/writing-rules.md)

---

## 📋 Agent 核心行為準則與開單流程

當使用者要求「幫我開一張 issue」或提出需求時，Agent 必須嚴格遵循以下流程：

### 步驟 1：選擇對應範本
- **新功能**：使用 `ai-feature.md` 格式，標籤：`feature`
- **修錯誤**：使用 `ai-bug.md` 格式，標籤：`bug`
- **靈感/未定案**：使用 `idea.md` 格式，無標籤（不開工）

### 步驟 2：硬性檢核（開工守衛條件）
- **一字不差的標題**：內文必須包含獨立一行的 `## 驗收條件`（❌ 絕對不可寫成 `## 驗收標準`、`## 驗收` 或 `**驗收條件**`）。
- **實質內容**：底下必須列出 3～6 條具體、客觀、可判斷是非（Pass/Fail）的驗收項目。
- **保護檔案**：需求中**嚴禁**要求修改 `.github/`、`AGENTS.md`、`CLAUDE.md`、`Dockerfile`、`compose.yml`（Workflow 會自動攔截）。

### 步驟 3：決定 AI 服務標籤
- 雲端 Claude 訂閱：`ai:claude`（可搭配 `model:claude-sonnet-5-5` 或 `model:claude-opus-5-5`）
- 本機 Antigravity (agy) 訂閱：`ai:agy`（可搭配 `model:gemini-3.8-flash`、`model:gemini-2.5-pro`，與 `effort:medium` 等）

### 步驟 4：確認並使用 `gh issue create` 發布
確認預覽內容後，執行指令開立 Issue：
```bash
gh issue create \
  --title "<標題>" \
  --body "<填寫完畢的 Markdown 內文>" \
  --label "<feature 或 bug>,<ai:claude 或 ai:agy>"
```
