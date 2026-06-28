# Change Scope Policy

## 目的

この文書は、`codex-task` の変更範囲 enforcement と expectation handling を定義します。

- `template/docs/reference/change-scope-policy.md` は consumer-facing reference です。
- `spec/change-scope-policy.json` は source repo 側の source-of-truth catalog であり、validator の検証対象です。
- 後続の runner implementation は、JSON catalog とこの Markdown contract の両方に従います。

## Path Normalization

- path は repo root 相対 POSIX path に正規化します。
- Windows path separator は `/` に正規化します。
- absolute path は scope comparison に直接使いません。
- absolute path を scope input として受け取ってはいけません。
- `.` / `..` を含む path は正規化後に repo root 外へ出ないことを確認します。
- directory 指定では trailing slash の有無を同一扱いにします。
- scope option を使うとき `--run-id` と `--record-run-manifest` を必須にします。

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
- 完全一致で評価します。
- `allowed_files` に含まれない source file の変更は scope violation として扱います。
- `.codex/runs/` 配下の generated artifact は scope check 対象外にできますが、source change と混同しません。

## Allowed Directories

- `allowed_dirs` は「この directory 配下なら変更してよい」を表します。
- path は repo root 相対 POSIX path に正規化します。
- `template/docs/reference` と `template/docs/reference/` は同じ意味です。
- `allowed_dirs` 自体の prefix 一致ではなく、directory boundary で判定します。
- 許可条件は `changed_path == allowed_dir` または `changed_path starts with allowed_dir + "/"` です。

## Allowed Globs

- `allowed_globs` は限定的な glob pattern を使った allow list です。
- special token は `*`、`**`、`?` のみです。
- `*` は `/` をまたがない 0 文字以上を表します。
- `?` は `/` をまたがない 1 文字を表します。
- `**` は `/` をまたぐ 0 文字以上を表します。
- brace expansion、extglob、character class を前提にしません。これらは special syntax として解釈しません。
- `../*` や `/absolute/path/*` のような repo 外参照は無効です。

## Scope precedence

- 変更ファイルが以下のいずれかに一致すれば許可します。
  1. `allowed_files` に完全一致
  2. `allowed_dirs` 配下に一致
  3. `allowed_globs` に一致
- いずれにも一致しない source file の変更は scope violation です。

## Expected Changed Files

- `expected_changed_files` は「必ず変更されるべきファイル」を表します。
- `allowed_files` とは意味が違います。
- `expected_changed_files` が変更されていない場合の既定動作は `fail` です。
- `expected_changed_files` は `allowed_files` の subset であることが望ましいです。
- `--require-evaluation` や `--require-clean-git` を併用しても、`.codex/runs/` の generated artifact は source scope に混ぜません。

### expected_missing behavior

- `--expected-missing fail`
  - 未変更 expected file を failure として扱います。
  - non-zero exit で終了します。
- `--expected-missing warn`
  - 未変更 expected file を warning として記録します。
  - stdout/stderr に warning を出します。
  - `run.json` がある場合は `validation.warnings` に記録します。
  - exit code は成功扱いのままです。

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
- validator は catalog type、schema version、path normalization、changed file kinds、artifact exclusion、`allowed_files` / `allowed_dirs` / `allowed_globs` / `expected_changed_files` の意味差分を確認します。
- current baseline では runner enforcement、changed files collection、limited glob matching を有効化しています。
