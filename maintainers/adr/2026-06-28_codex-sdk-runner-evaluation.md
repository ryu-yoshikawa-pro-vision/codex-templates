# ADR: Codex SDK runner evaluation

## Status
Deferred for implementation; approved for evaluation

## Context
このリポジトリは consumer repo へ配布する Codex 運用テンプレートの source repository である。現状の runner baseline は `template/scripts/codex-task.sh` と `template/scripts/codex-task.ps1` であり、`codex-safe` preflight を通した非対話実行、preset 選択、report JSON、JSONL log、run manifest、evaluation validation、scope check を担っている。SDK runner はこれらの責務をすぐ置き換える前提ではなく、将来的な runner 改善候補として評価する。

## Current runner baseline
現在の `codex-task` baseline は少なくとも次を責務として持つ。

- preflight
- codex exec invocation
- preset selection: safe / readonly / auto-net
- runtime selection: host / docker-sandbox
- output-last-message capture
- report JSON generation
- JSONL log generation
- run_id handling
- run manifest generation
- evaluation template generation
- evaluation schema validation
- require-evaluation
- require-clean-git
- require-run-id
- allowed_files / expected_changed_files scope check
- verify-command execution
- primary_failure_category copy from evaluation.json

加えて、`run.json` は aggregate manifest、`evaluation.json` は failure interpretation の source of truth、`codex-task` report JSON は単発実行の低レベル事実という責務分離を維持している。

## Problem
今後 runner 機能を強化する場合、`codex-task` wrapper に機能を足し続けるべきか、SDK runner を experimental に評価すべきかの判断軸が必要である。判断軸なしに個別機能を追加すると、wrapper 版と SDK 版で責務が重複し、run artifacts の source-of-truth が崩れる。

## Decision
- SDK runner is not adopted into the core template yet.
- SDK runner may be evaluated as a source-repo-only experimental path.
- `codex-task` remains the canonical runner baseline.
- No consumer-facing template change is made in this PR.

## Non-goals
- Implementing a SDK runner
- Replacing `codex-task`
- Changing `codex-safe` behavior
- Changing safety rules
- Changing approval or sandbox policy
- Adding SDK runner to `template/`
- Generating `run.json` through SDK runner
- Generating `evaluation.json` automatically
- Running repair-loop automatically
- Using SDK runner in CI as a required path
- Integrating OpenAI Agents SDK as a required dependency

## Evaluation criteria
評価は、baseline との parity を前提に次の観点で行う。

### Safety
- `safe` / `readonly` / `auto-net` と同等以上の安全境界を再現できるか
- `danger-full-access` や dangerous bypass を必要としないか
- delete / rename / git mutation を禁止できるか
- network access を明示 opt-in にできるか
- hook / execpolicy / wrapper safety と矛盾しないか

### Artifacts
- output file
- report JSON
- JSONL log
- `run.json`
- `evaluation.json`
- validation commands
- changed_files
- scope_violation
- primary_failure_category

上記を、既存 `codex-task` と同等以上の fidelity で記録できるかを評価する。

### Validation
- output schema validation
- evaluation schema validation
- verify-command
- require-evaluation
- require-clean-git
- require-run-id
- failure handling

### Scope control
- allowed_files
- expected_changed_files
- untracked files
- deleted files
- renamed files
- generated files under `.codex/runs/`
- path normalization

### Portability
- Windows PowerShell
- WSL
- Linux bash
- GitHub Actions Ubuntu runner
- consumer repo with minimal setup

### Consumer distribution
- `template/` に入れるべきか
- source repo examples に留めるべきか
- consumer repo に追加依存を要求するか
- OpenAI SDK / Codex SDK の version drift に耐えられるか

## Required parity with codex-task
採用判断の前提として、少なくとも次の parity table を満たす必要がある。

| Area | codex-task baseline | SDK runner requirement | Required before adoption |
| --- | --- | --- | --- |
| Safety preset | `safe` / `readonly` / `auto-net` preset を preflight と profile 選択に接続する | 同等の mode と opt-in network path を要検証 | Yes |
| Dangerous bypass prevention | dangerous bypass、危険 config、危険 add-dir を wrapper / policy で拒否する | bypass 不要で同等以上の防御を未確認 | Yes |
| Output capture | `--output-last-message` を file へ保存する | 同等の deterministic output capture を要検証 | Yes |
| Report JSON | 単発実行の machine-readable report JSON を出力する | 低レベル report artifact の形式と owner を要検証 | Yes |
| JSONL log | preflight、exec、validation の event log を残す | structured event log を残せるか未確認 | Yes |
| run.json | aggregate manifest を更新する | manifest 更新責務を壊さないことを要検証 | Yes |
| evaluation.json validation | schema validation と `run_id` 一致確認、summary copy を行う | 同等の validation gate を要検証 | Yes |
| clean git precondition | `--require-clean-git` で source dirty を検出する | `.codex/runs/` 除外込みで再現できるか要検証 | Yes |
| run id precondition | `--require-run-id` で自動採番せず明示要求する | 同等の precondition を維持できるか要検証 | Yes |
| scope check | `allowed_files` / `expected_changed_files` と changed files を評価する | deleted / renamed / untracked を含め再現できるか要検証 | Yes |
| verify command | verify command の実行と status 記録を行う | 同等の verification orchestration を要検証 | Yes |
| Windows support | PowerShell wrapper を提供する | Windows native support を未確認 | Yes |
| Bash support | bash wrapper を提供する | Linux / WSL bash path を未確認 | Yes |

## Safety requirements
- `safe` / `readonly` / `auto-net` 相当の境界が baseline 以上であること。
- dangerous bypass、`danger-full-access`、危険な sandbox downgrade を必要としないこと。
- delete / rename / git mutation の禁止と、network opt-in の明示性が既存方針と矛盾しないこと。
- hook、execpolicy、wrapper の多層防御と衝突せず、補完できること。

## Artifact requirements
- output file、report JSON、JSONL log、`run.json`、`evaluation.json` の責務分離を壊さないこと。
- `evaluation.json` を failure interpretation の source of truth として維持すること。
- `run.json.primary_failure_category` は valid な `evaluation.json.primary_failure_category` からの summary copy に留めること。
- changed files、scope violation、validation commands を観測事実として残せること。

## Validation requirements
- output schema validation、evaluation schema validation、verify-command を同等以上に実施できること。
- `--require-evaluation`、`--require-clean-git`、`--require-run-id` の precondition を維持できること。
- validation failure と runner failure を区別して report / manifest に記録できること。

## Scope-control requirements
- `allowed_files` と `expected_changed_files` の意味差分を維持すること。
- untracked、deleted、renamed、copied files を baseline と同様に扱えること。
- `.codex/runs/` 配下の generated artifacts を source scope から除外しつつ manifest evidence には残せること。
- path normalization を repo-relative POSIX path に揃え、Windows path separator 差異を吸収できること。

## Portability requirements
- Windows PowerShell、WSL、Linux bash、GitHub Actions Ubuntu runner で同じ contract を満たすこと。
- consumer repo の最小セットアップでも再現可能な install / runtime 要件に留めること。
- OS ごとに別 contract を要求しないこと。

## Consumer distribution requirements
- `template/` に入れる前に、source repo example で安定検証できること。
- consumer repo に重い追加依存、複雑な credential handling、脆い version pin を強制しないこと。
- SDK / API version drift に対して保守負荷が許容範囲であること。
- consumer-facing quickstart や harness docs を変更せずとも説明責任を果たせる評価結果を先に揃えること。

## Adoption conditions
- `codex-task` と同等以上の safety boundary を示せる。
- run artifacts の責務分離を壊さない。
- Windows / WSL / Linux で同じ contract を満たす。
- consumer repo の導入負荷が許容範囲である。
- SDK runner が `codex-task` の重複実装ではなく明確な価値を持つ。
- CI で source repo example を安定検証できる。
- fallback / rollback path がある。

明確な価値の例:
- より正確な structured event capture
- より安定した tool execution control
- subagent orchestration の明確な改善
- run manifest / evaluation artifact の一貫性向上
- wrapper では難しい情報取得

## Rejection conditions
- dangerous bypass が必要
- `safe` / `readonly` / `auto-net` の境界が弱くなる
- scope check が `codex-task` より弱い
- Windows support が不安定
- consumer repo に重い依存を強制する
- run artifacts の source-of-truth が曖昧になる
- `codex-task` と二重管理になるだけ
- 既存 wrapper より明確な価値がない

## Experimental-only conditions
- SDK API や Codex SDK の仕様が変わりやすい
- consumer repo に配布するには設定負荷が高い
- 一部 OS でしか安定しない
- artifact contract の一部しか満たせない
- subagent orchestration など限定用途だけ価値がある

## Comparison matrix
`codex-task` baseline と SDK runner 候補の役割差分は次の通り。

| Dimension | codex-task baseline today | SDK runner experimental target | Core-template decision gate |
| --- | --- | --- | --- |
| Ownership | canonical runner baseline | source-repo-only evaluation path | baseline を置き換えない |
| Safety boundary | wrapper + preflight + profiles + execpolicy | 同等以上を示せるか評価 | safety downgrade なし |
| Artifact contract | report JSON / JSONL / run.json / evaluation.json 分離 | 分離を保ったまま追加価値を示す | source-of-truth を崩さない |
| Validation | schema / verify / clean-git / run-id gate | 同等の gate を再現する | required parity 達成 |
| Scope control | `allowed_files` / `expected_changed_files` baseline enforcement | file-kind 差分まで追えるか評価 | scope weaker なら不採用 |
| Distribution | consumer-facing template に既に含まれる | source repo example に限定 | adoption 条件充足まで配布しない |

## Risks
- SDK 側の event / sandbox surface が不安定だと、baseline contract を満たす前に version drift 対応コストが増える。
- 低レベル report と aggregate manifest の owner が曖昧になると、`run.json` と `evaluation.json` の責務分離が崩れる。
- Windows support が弱いまま進めると、consumer repo 配布条件を満たせない。

## Rollback plan
- 本 ADR は source-repo-only の評価方針であり、consumer-facing template を変更しない。
- SDK runner evaluation が不十分または不適切と判明した場合は、source repo example を継続停止し、`codex-task` baseline をそのまま維持する。
- 将来 experimental implementation を追加しても、adoption 条件を満たせなければ core template へ統合せず、example と ADR 更新だけで rollback できるようにする。

## Follow-up work
- source repo example を使って、SDK runner 候補ごとに `contract-checklist.md` を埋める。
- gap は harness improvement candidates として記録し、`codex-task` へ責務を戻すべきか、SDK path を深掘りすべきかを分離して判断する。
- adoption 条件を満たす evidence が揃った場合のみ、consumer-facing change を含む別計画と別 PR を起こす。
