# Plan/Review Guidance Hardening 実行ログ

## 2026-03-18 16:56 (JST)
- Summary:
  - 実装着手前に run を初期化し、source-repo plan/report の保存先を用意した。
  - 合意済み計画を source repo 命名で保持する準備を完了した。
- Completed:
  - run `20260318-165514-JST` 初期化
  - 初回 plan/report の作成
- Commands:
  - `TZ=Asia/Tokyo date '+RUN_ID=%Y%m%d-%H%M%S-JST%nPLAN_TS=%Y-%m-%d_%H%M%S'` => `20260318-165514-JST`
  - `mkdir -p .codex/runs/20260318-165514-JST && cp template/.codex/templates/...` => run template 初期化
- Notes:
  - 実装方針は「既存 2 skills を維持しつつ workflow を強化する」。

## 2026-03-18 17:02 (JST)
- Summary:
  - root/template の plan/review contract、skills/reference、plan template、spec、verify/smoke を更新した。
  - source repo の PROJECT_CONTEXT と履歴へ、今回の workflow expectation 変更を反映した。
- Completed:
  - root 文書更新
  - consumer-facing 文書/skills 更新
  - spec / validator / verify / smoke 更新
  - PROJECT_CONTEXT / history 更新
- Commands:
  - `apply_patch` => 上記ファイル群を更新
  - `sed -n ...` => 更新後の内容確認
- Notes:
  - 4 skill 再編は採らず、2 skills の reference 強化で input の主要示唆を吸収した。

## 2026-03-18 17:10 (JST)
- Summary:
  - validate-spec、template verify、smoke を bash / PowerShell で確認した。
  - 途中で見つかった軽微な検証障害を修正し、最終的に全検証を通過させた。
- Completed:
  - `spec/workflow.yaml` の JSON 修正
  - `template/scripts/verify` の LF 正規化
  - `template/scripts/verify.ps1` の PowerShell codex 判定修正
  - validate / verify / smoke 完了
- Commands:
  - `bash tools/validate-spec.sh` => PASS
  - `powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1` => PASS
  - `bash template/scripts/verify` => PASS=3 FAIL=0 SKIP=1
  - `powershell.exe -ExecutionPolicy Bypass -File template/scripts/verify.ps1` => PASS=1 FAIL=0 SKIP=2
  - `bash tests/smoke/test-template-layout.sh` => PASS
  - `powershell.exe -ExecutionPolicy Bypass -File tests/smoke/Test-TemplateLayout.ps1` => PASS
  - `git diff --stat` => 20 files changed, 275 insertions(+), 64 deletions(-)
- Notes:
  - PowerShell verify の SKIP は `codex` が PowerShell PATH にない現環境起因で、想定どおりの分岐。

## 2026-03-18 17:18 (JST)
- Summary:
  - planning/review reference を inputs 例に近い具体度へ拡張した。
  - reference の具体度を検査できるよう `spec/workflow.yaml`、verify、smoke に追加 phrase を反映した。
- Completed:
  - reference 詳細化
  - spec / verify / smoke の追従
  - PROJECT_CONTEXT / history の追記
- Commands:
  - `apply_patch` => 上記ファイルを更新
  - `sed -n ...` => 反映内容を確認
- Notes:
  - 今回も 2 skills 構成は維持し、reference 側の具体度だけを上げた。

## 2026-03-18 17:20 (JST)
- Summary:
  - 追加変更後の validate-spec、verify、smoke を bash / PowerShell で再実行し、すべて通過した。
  - machine check に使う phrase は PowerShell 互換のため ASCII sentinel に揃えた。
- Completed:
  - 再検証完了
- Commands:
  - `bash tools/validate-spec.sh` => PASS
  - `powershell.exe -ExecutionPolicy Bypass -File tools/validate-spec.ps1` => PASS
  - `bash template/scripts/verify` => PASS=3 FAIL=0 SKIP=1
  - `powershell.exe -ExecutionPolicy Bypass -File template/scripts/verify.ps1` => PASS=1 FAIL=0 SKIP=2
  - `bash tests/smoke/test-template-layout.sh` => PASS
  - `powershell.exe -ExecutionPolicy Bypass -File tests/smoke/Test-TemplateLayout.ps1` => PASS
- Notes:
  - PowerShell verify の SKIP は引き続き `codex` が PowerShell PATH にない現環境起因。
