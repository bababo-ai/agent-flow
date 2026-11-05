---
name: agent-flow-issue
description: >-
  Use this skill when drafting, creating, or reviewing a GitHub Issue for the agent-flow
  (AI automated development) workflow. Loads the project's issue templates in
  .github/ISSUE_TEMPLATE/ (ai-feature.md, ai-bug.md, idea.md), helps write strict
  acceptance criteria (## 驗收條件), picks labels (feature/bug, ai:*), and publishes
  via GitHub CLI (gh issue create).
---

# Agent-Flow Issue 開單小幫手

協助使用者寫出符合 agent-flow 規格的 Issue。**一律以專案的 `.github/ISSUE_TEMPLATE/` 為準**，開單前先讀對應的模板檔，不要憑記憶寫格式。

## 選模板

| 需求情境 | 模板 | 標籤 |
|---|---|---|
| 新功能／功能調整（規格與驗收條件已明確） | `.github/ISSUE_TEMPLATE/ai-feature.md` | `feature` + `ai:*` |
| 修錯誤（含重現步驟、預期與實際結果） | `.github/ISSUE_TEMPLATE/ai-bug.md` | `bug` + `ai:*` |
| 先記下來、細節未定 | `.github/ISSUE_TEMPLATE/idea.md` | 不加任何標籤（不會開工） |

如果專案裡找不到這些模板，告訴使用者尚未安裝 agent-flow，不要自己編格式。

## 硬性規範（開工檢查腳本會驗證）

1. 內文必須有單獨一行、一字不差的 `## 驗收條件`。不能寫成 `## 驗收`、`## 驗收標準`、`**驗收條件**`、`## Acceptance criteria`。
2. 每條驗收條件都要能回答「是」或「否」，並寫出具體的值（狀態碼、畫面文字、欄位）。建議 3～6 條，超過 10 條建議拆單。純程式碼檢查請註明「（讀程式碼確認即可）」。
3. 不要要求修改受保護檔案：`.github/`、`AGENTS.md`、`CLAUDE.md`、`Dockerfile`、compose 檔（會被檢查擋下）。實際清單以專案 `AGENTS.md` 的 AI 協作規則為準。

## 流程

1. **確認類型**：問使用者是新功能、修錯誤，還是待規劃點子，然後讀取對應模板。
2. **依模板逐段收集內容**：標題（一句話說出結果）、背景、要做什麼、不要做什麼、驗收條件，以及選填的使用者驗證與補充。驗收條件要同時涵蓋正面情境與回歸（原本的功能沒壞）。
3. **決定標籤**（非 idea 才需要）：
   - 先用 `gh label list` 查目前有哪些 `ai:*` 和 `model:*` 標籤，只從現有的選，不要自己編。
   - `ai:agy` 走 self-hosted runner，`ai:claude` 走雲端。`model:*` 為選用，使用者沒指定就不加。
4. **預覽並確認**：把完整標題、內文和將加的標籤列給使用者看。**加上 `ai:*` 標籤就會立刻觸發 AI 開工**，所以必須等使用者明確同意才執行。
5. **建立 Issue**：內文先寫到暫存檔，再用 `--body-file`，避免引號、反引號在 shell 裡出問題：
   ```bash
   gh issue create --title "<標題>" --body-file <暫存檔> --label "<標籤，逗號分隔>"
   ```
   建立後把 Issue 連結回給使用者。