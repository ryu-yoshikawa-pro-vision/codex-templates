# Change Scope Policy

## 目的

この文書は、`--allowed-files` / `--expected-changed-files` を後段で実装する前提となる変更範囲ポリシーを定義します。Initial implementation A では reviewable な Markdown contract として扱い、runner 実装や validator 実装は行いません。

## Path Normalization

- path は repo root 相対 POSIX path に正規化します。
- Windows path separator は `/` に正規化します。
- absolute path は scope comparison に直接使いません。
- `.` / `..` を含む path は正規化後に repo root 外へ出ないことを確認します。

## Changed Files

- tracked modified files を `changed_files` に含めます。
- untracked files を `changed_files` に含めます。
- deleted files を `changed_files` に含めます。
- renamed files は old path / new path の両方を評価対象にします。
- copied files は copy 先を new file として扱います。
- generated run artifacts under `.codex/runs/` は scope check の対象外にします。
- ただし `.codex/runs/` 配下の artifact は manifest に記録してよいものとします。

## Allowed Files

- `allowed_files` は「変更してよい上限」を表します。
- 初期段階では完全一致を基本にします。
- glob support は後段検討とします。
- `allowed_files` に含まれない source file の変更は scope violation として扱います。
- `.codex/runs/` 配下の generated artifact は scope check 対象外にできますが、source change と混同しません。

## Expected Changed Files

- `expected_changed_files` は「必ず変更されるべきファイル」を表します。
- `allowed_files` とは意味が違います。
- `expected_changed_files` が変更されていない場合、実装漏れの可能性として warning または failure candidate にします。
- `expected_changed_files` は `allowed_files` の subset であることが望ましいです。

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

## Deferred JSON Catalog

- `spec/change-scope-policy.json` は今回追加しません。
- Initial implementation B または TASK-005 の実装時に追加要否を判断します。
- 今回は Markdown doc として方針をレビュー可能にします。
