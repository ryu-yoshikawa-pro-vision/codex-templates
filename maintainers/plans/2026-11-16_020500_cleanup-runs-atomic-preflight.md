# cleanup-runs の全候補事前検証

## 目的

`codex-templates` の既存 `validate-bash` CI が `tests/integration/test-cleanup-runs.sh` で失敗した。Dependabot設定PR #27 の差分とは無関係な既存cleanup実装の問題として、修正を独立PRに分ける。

## 確認済みの事実

- 2026-11-16 02:00 JST、PR #27 のhead `ec71d4df4b85073d7424f8821a7592c3e117462f` で Bash job が `Run cleanup-runs test` に失敗し、PowerShell job は成功した。
- hosted log はテストstepのexit code 1のみを示し、失敗assertionは出力されていない。
- 既存テストは古い有効candidate、新しい有効candidate、後続のsymlink candidateを同じcleanup invocationに含め、symlink拒否後も新しいcandidateが残ることを確認する。
- 実装はcandidateごとに安全性確認後すぐ削除するため、`find`順序により拒否対象に到達する前に一部の有効candidateを削除し得る。失敗原因の最終的な証拠は修正後の既存CIで確認する。

## 実装範囲

- 全candidateのsymlink/reparse-pointとrepo-root containmentを削除前に検証する。
- 1件でも危険なcandidateがあれば、削除処理を開始せず失敗する。
- Dependabot設定、workflow、既存テスト仕様の変更は含めない。PR #27とは別branch/PRとする。

## 検証

- `bash -n template/scripts/cleanup-runs.sh`
- `git diff --check`
- 削除系integration testはローカルでは実行しない。PR CIの既存Bash/PowerShell検証で確認する。

## リスクと戻し方

- unsafe candidateが混在する場合に有効candidateの部分的なcleanupを中止する。これは全体停止によるfail-safe動作である。
- 問題があれば本branchの実装diffを修正し、必要ならbranch上のコード変更を戻す。既定branchとPR #27には直接変更を加えない。
