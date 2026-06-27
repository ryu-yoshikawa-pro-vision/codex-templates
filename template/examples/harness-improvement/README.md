# Harness Improvement Example

この例は evaluation findings から harness improvement candidate へ変換する方法を示す。

- product implementation と harness improvement を分離する。
- strict workflow が必要な target を分けて扱う。
- rejected / deferred candidate も evidence と owner decision を残す。

## Included examples
- docs / skill improvement: `strictness = normal`
- validator / schema improvement: `strictness = strict`
- unsafe or policy-bypass candidate: `strictness = blocked`

## Files
- `harness-improvement-candidates.json`
- `harness-improvement-review.md`
