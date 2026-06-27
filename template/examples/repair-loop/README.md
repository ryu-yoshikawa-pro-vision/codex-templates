# Repair Loop Example

この例は 2 iteration の repair-loop を示す。

- iteration 1 では validation failure が残り、`evaluation.result = partial` になる。
- iteration 2 では修正完了として `evaluation.result = pass` に到達する。
- `evaluation.json` との接続は `iteration-1-evaluation.json` と `iteration-2-evaluation.json` で示す。
- `--max-iterations` は runner auto-loop ではなく workflow bound である。

## Flow
1. review finding と validation gap を入力に triage する。
2. iteration 1 で `must_fix` を修正し、validation を再実行する。
3. 残差があるため `decision = continue` とする。
4. iteration 2 で残差を解消し、`decision = stop_success` とする。

## Files
- `iteration-1-evaluation.json`
- `iteration-2-evaluation.json`
- `repair-summary.md`
