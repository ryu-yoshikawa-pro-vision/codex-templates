#!/usr/bin/env python3
"""Best-effort PreToolUse guard for destructive operations.

This hook is intentionally supplementary. The primary safety boundary remains
the wrapper-managed sandbox, approval policy, and execpolicy rules.
"""

from __future__ import annotations

import json
import re
import sys
from typing import Any, Iterable


DENY_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"(^|[\s;&|])rm\s+(-[^\s]*[rf][^\s]*\s+)?", re.I), "rm deletion is forbidden"),
    (re.compile(r"(^|[\s;&|])(del|erase|rmdir|unlink)\b", re.I), "file deletion is forbidden"),
    (re.compile(r"\bRemove-Item\b", re.I), "Remove-Item is forbidden"),
    (re.compile(r"\b(Move-Item|Rename-Item)\b[^\n\r]*(\s-Force\b|\s-force\b)", re.I), "forced move/rename is forbidden"),
    (re.compile(r"(^|[\s;&|])mv\s+-f\b", re.I), "forced move is forbidden"),
    (re.compile(r"\bfind\b[^\n\r]*\s-delete\b", re.I), "find -delete is forbidden"),
    (re.compile(r"\brsync\b[^\n\r]*\s--delete\b", re.I), "rsync --delete is forbidden"),
    (re.compile(r"\brobocopy\b[^\n\r]*(\s/MIR\b|\s/mir\b)", re.I), "robocopy /MIR is forbidden"),
    (re.compile(r"\bgit\s+(add|commit|push|rm)\b", re.I), "git staging, commit, push, and rm are forbidden"),
    (re.compile(r"\bgit\s+reset\s+--hard\b", re.I), "git reset --hard is forbidden"),
    (re.compile(r"\bgit\s+clean\s+-[^\s]*[fdx][^\s]*\b", re.I), "git clean is forbidden"),
    (re.compile(r"\bdocker\s+(system|volume|network|image)\s+prune\b", re.I), "docker prune is forbidden"),
    (re.compile(r"\bterraform\s+(apply|destroy)\b", re.I), "terraform apply/destroy is forbidden"),
    (re.compile(r"\bkubectl\s+(apply|delete)\b", re.I), "kubectl apply/delete is forbidden"),
    (re.compile(r"\bhelm\s+uninstall\b", re.I), "helm uninstall is forbidden"),
    (re.compile(r"\baws\s+s3\s+rm\b", re.I), "aws s3 rm is forbidden"),
    (re.compile(r"\baz\s+group\s+delete\b", re.I), "az group delete is forbidden"),
    (re.compile(r"\bgcloud\s+projects\s+delete\b", re.I), "gcloud projects delete is forbidden"),
    (re.compile(r"\b(curl|wget)\b[^\n\r|]*\|\s*(bash|sh)\b", re.I), "remote script piping is forbidden"),
    (re.compile(r"\b(iwr|irm|Invoke-WebRequest|Invoke-RestMethod)\b[^\n\r|]*\|\s*(iex|Invoke-Expression)\b", re.I), "PowerShell remote script execution is forbidden"),
    (re.compile(r"^\*\*\* Delete File:", re.M), "patch file deletion is forbidden"),
    (re.compile(r"^(rename from|rename to|deleted file mode)\b", re.M), "patch rename/delete is forbidden"),
]


TEXT_KEYS = {
    "command",
    "cmd",
    "args",
    "arguments",
    "input",
    "patch",
    "content",
    "text",
    "script",
}


def iter_text(value: Any, key: str = "") -> Iterable[str]:
    if isinstance(value, str):
        if not key or key in TEXT_KEYS:
            yield value
        return
    if isinstance(value, list):
        if key in {"args", "arguments", "command", "cmd"} and all(isinstance(item, str) for item in value):
            yield " ".join(value)
        for item in value:
            yield from iter_text(item, key)
        return
    if isinstance(value, dict):
        for child_key, child_value in value.items():
            yield from iter_text(child_value, str(child_key))


def tool_name(payload: dict[str, Any]) -> str:
    for key in ("tool_name", "tool", "name"):
        value = payload.get(key)
        if isinstance(value, str):
            return value
    return "unknown"


def block(reason: str, tool: str) -> None:
    print(json.dumps({"decision": "block", "reason": reason, "tool": tool}, ensure_ascii=False))


def allow() -> None:
    print(json.dumps({"decision": "allow"}, ensure_ascii=False))


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        block(f"Unable to parse hook payload: {exc}", "unknown")
        return 0

    if not isinstance(payload, dict):
        allow()
        return 0

    tool = tool_name(payload)
    for text in iter_text(payload):
        for pattern, reason in DENY_PATTERNS:
            if pattern.search(text):
                block(reason, tool)
                return 0

    allow()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
