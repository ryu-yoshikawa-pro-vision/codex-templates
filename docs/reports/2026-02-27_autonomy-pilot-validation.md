# 自律運用パイロット検証（2サイクル）

## 検証目的
- 改修後の運用が `PLAN -> Web検索 -> TASKS -> 実行 -> REPORT` で再現可能かを確認する。
- スキル探索導入と改善提案ガードレールが機能するかを確認する。

## Cycle 1: 調査駆動の運用改善
- シナリオ:
  - 自律調査ループを AGENTS とテンプレートへ反映する。
- 実施:
  - Web調査 Round1/2 を実行（OpenAI公式 docs + cookbook + openai/skills）。
  - 仮説H1-H5と証跡を実装ログへ反映。
  - `.codex/templates/PLAN.md` / `TASKS.md` / `REPORT.md` を更新。
- 判定:
  - PASS（検索ラウンド、仮説更新、証跡ログ、テンプレート反映を確認）
- 証拠:
  - `rg -n "Hypotheses|Research Plan|Evidence Record" .codex/templates/PLAN.md .codex/templates/REPORT.md`

## Cycle 2: スキル探索導入とガードレール
- シナリオ:
  - `skill-installer` で必要スキルを導入し、改善提案の安全運用を定義する。
- 実施:
  - curated 一覧を取得し `openai-docs` を導入。
  - `docs/agent/skill-discovery-workflow.md` と `docs/agent/improvement-guardrails.md` を作成。
  - `AGENTS.md` に governance 節を追加。
- 判定:
  - PASS（スキル導入確認、承認境界定義、ロールバック方針定義）
- 証拠:
  - `python3 .../list-skills.py --format json` => `{'name': 'openai-docs', 'installed': True}`
  - `rg -n "Autonomous research loop|Skills and self-improvement governance" AGENTS.md`

## 結論
- 2サイクルとも PASS。
- 実装後は、調査・実行・改善提案の各プロセスで記録と承認境界が明示され、再現性が向上した。
- 次アクション:
  - 次回セッション開始時に `docs/agent/overrides.md` 読込が実際に運用されるかを確認する。
