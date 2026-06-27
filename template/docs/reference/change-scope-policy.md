# Change Scope Policy

## 目的

この文書は、TASK-006B で `codex-task` に追加された `--allowed-files` / `--expected-changed-files` baseline enforcement の変更範囲ポリシーを定義します。

- `template/docs/reference/change-scope-policy.md` は consumer-facing reference です。
- `spec/change-scope-policy.json` は source repo 側の source-of-truth catalog であり、validator の検証対象です。
- 後続の runner implementation は、JSON catalog とこの Markdown contract の両方に従います。

## Path Normalization

- path は repo root 相対 POSIX path に正規化します。
- Windows path separator は `/` に正規化します。
- absolute path は scope comparison に直接使いません。
- `.` / `..` を含む path は正規化後に repo root 外へ出ないことを確認します。
- match mode は exact path のみです。
- glob support は deferred のままです。
- baseline では scope options を使うとき `--run-id` と `--record-run-manifest` を必須にします。

## Changed Files

- tracked modified files を `changed_files` に含めます。
- untracked files を `changed_files` に含めます。
- deleted files を `changed_files` に含めます。
- renamed files は old path / new path の両方を評価対象にします。
- copied files は copy 先を new file として扱います。
- generated run artifacts under `.codex/runs/` は scope check の対象外にします。
- `.codex/runs/` 配下の generated artifact は `changed_files` に混ぜません。
- ただし `.codex/runs/` 配下の artifact は manifest に記録してよいものとします。
- `changed_files` は repo-relative POSIX path の配列として `run.json` に記録します。

## Clean Git Precondition

- `--require-clean-git` は Codex 実行前の source dirty を検出します。
- tracked modified、added、untracked、deleted、renamed、copied を dirty source changes として扱います。
- `.codex/runs/` は generated artifact として clean git 判定から除外します。
- dirty の場合は Codex を実行しません。
- dirty failure では `changed_files` に pre-existing source changes を記録してよいものとします。

## Allowed Files

- `allowed_files` は「変更してよい上限」を表します。
- baseline では完全一致を基本にします。
- glob support は後段検討とします。
- `allowed_files` に含まれない source file の変更は scope violation として扱います。
- `.codex/runs/` 配下の generated artifact は scope check 対象外にできますが、source change と混同しません。

## Expected Changed Files

- `expected_changed_files` は「必ず変更されるべきファイル」を表します。
- `allowed_files` とは意味が違います。
- `expected_changed_files` が変更されていない場合、baseline runner では failure として扱います。
- `expected_changed_files` は `allowed_files` の subset であることが望ましいです。
- `--require-evaluation` や `--require-clean-git` を併用しても、`.codex/runs/` の generated artifact は source scope に混ぜません。

## Deleted / Renamed / Copied

### deleted

- 削除も変更として扱います。
- `allowed_files` に含まれていない file の削除は scope violation です。

### renamed

- old path と new path の両方を評価対象にします。
- rename 先が `allowed_files` に含まれない場合は scope violation candidate です。

### copied

- copy 先を new file として扱います。
- copy 先が `allowed_files` に含まれない場合は scope violation candidate です。

## JSON Catalog

- `spec/change-scope-policy.json` は source repo の validator 対象です。
- Markdown doc は consumer-facing reference、JSON catalog は source repo の source-of-truth です。
- validator は catalog type、schema version、path normalization、changed file kinds、artifact exclusion、`allowed_files` / `expected_changed_files` の意味差分を確認します。
- TASK-006B baseline では runner enforcement と changed files collection を有効化しました。
- glob matching は deferred のままです。
