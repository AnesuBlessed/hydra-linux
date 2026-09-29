#!/usr/bin/env python3
"""Syntax-check every QML file with qmllint.

Workaround: qmllint 1.0 crashes with exit 255 on Quickshell's `IpcHandler`
functions that carry TypeScript-style annotations, e.g.

    function handleCommand(cmd: string, target: string): void { ... }

The annotations are valid Quickshell and worth keeping, so instead of stripping
them from the source we lint a preprocessed copy with them removed. Only
`function` declaration lines are touched; ordinary QML bindings such as
`onClicked: {` are left exactly as they are.

Anything else that fails is a real syntax error and still fails the build.
"""
import os
import re
import subprocess
import sys
import tempfile

# `function name(a: T, b: T): R {` on a single line, or ending in `{`.
FUNC_RE = re.compile(r"^(\s*function\s+[A-Za-z_]\w*\s*\()(.*?)(\)\s*)(:\s*[A-Za-z_]\w*\s*)?(\{?\s*)$")
# `: type` pairs inside the parameter list.
PARAM_RE = re.compile(r"([A-Za-z_]\w*)\s*:\s*[A-Za-z_][\w<>\[\]|.]*")


def strip_annotations(line: str) -> str:
    m = FUNC_RE.match(line)
    if not m:
        return line
    head, params, close, ret, tail = m.groups()
    # Only rewrite if there is actually an annotation to remove.
    if not ret and ":" not in params:
        return line
    params = PARAM_RE.sub(r"\1", params)
    return head + params + close + tail


def main() -> int:
    qs_dir = sys.argv[1] if len(sys.argv) > 1 else ".config/hypr/scripts/quickshell"

    files = []
    for root, dirs, names in os.walk(qs_dir):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        files.extend(os.path.join(root, n) for n in names if n.endswith(".qml"))
    files.sort()

    if not files:
        print(f"no QML files found under {qs_dir}", file=sys.stderr)
        return 1

    status = 0
    with tempfile.TemporaryDirectory() as tmp:
        for path in files:
            with open(path, encoding="utf-8") as fh:
                lines = fh.read().split("\n")
            patched = "\n".join(strip_annotations(l) for l in lines) + "\n"

            target = os.path.join(tmp, os.path.basename(path))
            with open(target, "w", encoding="utf-8") as fh:
                fh.write(patched)

            result = subprocess.run(
                ["qmllint", "-I", qs_dir, target],
                capture_output=True, text=True,
            )
            if result.returncode != 0:
                print(f"::error file={path}::qmllint exit {result.returncode}")
                for stream in (result.stdout, result.stderr):
                    if stream.strip():
                        print(stream.strip())
                status = 1

    if status == 0:
        print(f"qmllint: {len(files)} QML file(s) OK")
    return status


if __name__ == "__main__":
    sys.exit(main())
