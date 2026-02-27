# スキル探索・導入ワークフロー

## 目的
- `skill-installer` を使って、依頼に対して必要なスキルを継続的に探索・導入できる状態にする。

## 運用方針
- 一次情報は `openai/skills` と OpenAI公式ドキュメントを優先する。
- スキル導入は「候補列挙 -> 評価 -> 導入 -> 再起動確認」の順で実施する。
- 導入判断は run の `REPORT.md` に理由付きで記録する。

## 実行手順
1. 候補列挙（curated）
   - `python3 ~/.codex/skills/.system/skill-installer/scripts/list-skills.py`
2. 必要に応じて experimental 列挙
   - `python3 ~/.codex/skills/.system/skill-installer/scripts/list-skills.py --path skills/.experimental`
3. 評価（MUST/SHOULD）
   - MUST: 依頼スコープに直接寄与する
   - MUST: 信頼できる出典・実行手順がある
   - SHOULD: 既存スキルと重複しない
4. 導入
   - `python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py --repo openai/skills --path skills/.curated/<skill-name>`
5. 導入確認
   - `python3 ~/.codex/skills/.system/skill-installer/scripts/list-skills.py --format json`
   - Codex を再起動してスキル認識を反映する。

## 評価ログテンプレート
- Skill: 
- Source: 
- Use Case: 
- Decision: `Adopt` / `Hold` / `Reject`
- Reason:
- Follow-up:

## 今回の導入結果
- Skill: `openai-docs`
- Decision: `Adopt`
- Reason: OpenAI公式ドキュメント参照の精度向上に直結し、反復Web調査フロー（R1/R2）と相性が良い。
- Follow-up: Codex再起動後に新スキルが利用可能かを次回セッションで確認する。
