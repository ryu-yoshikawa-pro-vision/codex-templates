# Plan

## Objective
- Codexが「計画→タスク→行動ログ」の運用を厳密に行うためのテンプレートとAGENTS.mdを改善する。

## Scope
- In: .codex/templates (PLAN/TASKS/REPORT), AGENTS.md, docs/PROJECT_CONTEXT.md, docs/adr/
- Out: 実装コードや外部ツールの追加

## Assumptions
- 初回セットアップのため docs/PROJECT_CONTEXT.md と docs/adr/ を新規作成する。
- 変更はテンプレートと運用規約に限定する。

## Approach
- 現状テンプレート/AGENTS.mdの不足点を整理
- テンプレートに「思考ログ」「追記運用」「行動ログ必須項目」を追加
- AGENTS.md に思考/ログ/タスク追記の強制ルールを明文化
- docs/PROJECT_CONTEXT.md と ADR を追加し運用方針を記録

## Definition of Done
- テンプレートとAGENTS.mdが要件を満たす文言に更新されている
- docs/PROJECT_CONTEXT.md と ADR が作成されている
- TASKS/REPORT が更新され、進捗とログが残っている

## Risks / Unknowns
- 既存運用との整合が必要なため、文言が冗長化する可能性

## Thinking Log
- 依頼内容は「計画→タスク→行動ログ」運用の強制。テンプレートとAGENTS.mdで運用を明文化する。
- 追加要件: PROJECT_CONTEXTは各プロジェクトで変更・開発進行に伴い更新する旨をAGENTS.mdとPROJECT_CONTEXTに明記する。
- README.mdでテンプレートの目的と運用ルール（PROJECT_CONTEXTの更新方針含む）を説明する。
