---
name: agent-flow-issue
description: >-
  Use this skill when drafting, creating, or reviewing a GitHub Issue for the agent-flow
  (AI automated development) workflow. Guides the user by directly loading the repository's
  official templates in templates/ISSUE_TEMPLATE/ (ai-feature.md, ai-bug.md, idea.md),
  formulating strict acceptance criteria (## 驗收條件), selecting proper labels (feature/bug,
  ai:claude/ai:agy), and publishing via GitHub CLI (gh issue create).
---

# Agent-Flow Issue 開單小幫手

這項技能專門用來協助使用者撰寫並在 GitHub 上建立符合 **`agent-flow`** 規格的高品質 Issue。

**本技能嚴格以專案的 [`templates/ISSUE_TEMPLATE/`](../../templates/ISSUE_TEMPLATE/) 作為唯一標準模板！**

---

## 📂 模板對照（依據專案官方 `templates/`）

在開單前，必須先判斷使用者需求的成熟度與類型，直接採用對應的模板：

| 需求情境 | 使用模板 | 適用標籤 | 說明 |
|---|---|---|---|
| **新功能 / 功能調整** | [`templates/ai-feature.md`](templates/ai-feature.md) | `feature` + `ai:claude` 或 `ai:agy` | 規格與驗收條件已明確，準備讓 AI 開工 |
| **修復錯誤 / Bug** | [`templates/ai-bug.md`](templates/ai-bug.md) | `bug` + `ai:claude` 或 `ai:agy` | 包含重現步驟、預期與實際結果、驗收條件 |
| **先記下來 / 待規劃** | [`templates/idea.md`](templates/idea.md) | *(不帶任何標籤)* | 只有概念，細節未定。**不加 `ai:*` 標籤，不會開工** |

*(若在專案環境中，亦可直接參照專案根目錄的 `templates/ISSUE_TEMPLATE/` 或 `.github/ISSUE_TEMPLATE/`)*

---

## 🎯 核心原則與自動化硬性規範

1. **嚴格的標題格式（由開工檢查腳本驗證）**：
   * 內文**必須包含單獨一行、一字不差**的 `## 驗收條件`。
   * ❌ **絕對不能寫成**：`## 驗收`、`## 驗收標準`、`**驗收條件**`、`## Acceptance criteria`。
2. **驗收條件品質標準**：
   * 每一條都要能回答「是」或「否」。
   * 寫出具體的值（狀態碼、介面特定文字、欄位等）。
   * 建議條數控制在 **3～6 條**；超過 10 條建議拆單。
   * 純代碼檢查請註明「（讀程式碼確認即可）」。
3. **禁止要求的保護檔案**：
   * ❌ 禁止要求修改 `.github/`、`AGENTS.md`、`CLAUDE.md`、`Dockerfile`、`compose` 檔（會被安全性固定檢查擋下）。

---

## 📋 開單步驟流程

### 步驟 1：確認模板與類型
詢問使用者這是一張 **新功能 (`ai-feature.md`)**、**修錯誤 (`ai-bug.md`)**，還是 **待規劃點子 (`idea.md`)**？
讀取並對齊 `templates/ISSUE_TEMPLATE/` 中的對應檔案。

### 步驟 2：引導填寫各區塊
依據模板要求收集內容：
1. **標題**：一句話說出結果（例：「文章列表超出頁碼範圍時回傳 404」）。
2. **`## 背景`**：
   * Feature：為什麼要做、誰會受益。
   * Bug：在哪裡、做了什麼、看到什麼、應該看到什麼。
3. **`## 要做什麼`**：明確預期成果，相關檔案路徑。
4. **`## 不要做什麼`**：明確界定不要動的地方（防止 AI 過度修改）。
5. **`## 驗收條件`**：3～6 條具體、客觀驗收項目（必須包含正面與回歸測試）。
6. **`## 使用者驗證`**（選填）：人工需要驗證的項目（例如外觀截圖、實機操作）。
7. **`## 補充`**（選填）：限制條件、相關 Issue/PR。

### 步驟 3：決定執行的 AI 標籤
* **`ai:agy`**：Google Antigravity 訂閱版（走本機 Self-hosted Runner，完全免 API Key）。
  * 可選模型：`model:gemini-2.5-pro`、`model:gemini-3.8-flash`
* **`ai:claude`**：Claude 官方訂閱版（GitHub 雲端全自動執行）。
  * 可選模型：`model:claude-opus-5-5`、`model:claude-sonnet-5-5`

### 步驟 4：確認並發布開工
確認使用者同意預覽後，執行命令開立 Issue：
```bash
gh issue create \
  --title "<標題>" \
  --body "<依照模板填寫的 Markdown 內文>" \
  --label "<feature 或 bug>,<ai:claude 或 ai:agy>"
```
建立成功後，回傳 Issue 連結給使用者。
