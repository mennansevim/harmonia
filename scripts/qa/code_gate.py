#!/usr/bin/env python3
"""Runs format, analyze and the full test suite, then records real counts in
qa/reports/code_gate.json for the dashboard. Exits non-zero if any step fails.
"""
import datetime
import json
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]


def run(command):
    started = time.monotonic()
    completed = subprocess.run(
        command,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return completed, round(time.monotonic() - started, 2)


def count_tests(machine_output):
    passed = failed = skipped = 0
    for line in machine_output.splitlines():
        if not line.startswith(("{", "[")):
            continue
        try:
            events = json.loads(line)
        except ValueError:
            continue
        for event in events if isinstance(events, list) else [events]:
            if not isinstance(event, dict) or event.get("type") != "testDone":
                continue
            if event.get("hidden"):
                continue
            if event.get("skipped"):
                skipped += 1
            elif event.get("result") == "success":
                passed += 1
            else:
                failed += 1
    return passed, failed, skipped


def _safe_text(value, limit=600):
    """Keeps local QA diagnostics bounded and removes the private repo path."""
    text = str(value).replace(str(ROOT), "<repo>").strip()
    return text[:limit]


def test_failures(machine_output, limit=10):
    """Extracts bounded failing test names/errors from Flutter machine output."""
    names = {}
    errors = {}
    failures = []
    for line in machine_output.splitlines():
        if not line.startswith(("{", "[")):
            continue
        try:
            events = json.loads(line)
        except ValueError:
            continue
        for event in events if isinstance(events, list) else [events]:
            if not isinstance(event, dict):
                continue
            test_id = event.get("testID")
            if event.get("type") == "testStart" and test_id is not None:
                test = event.get("test") or {}
                names[test_id] = _safe_text(test.get("name", "unknown"), 240)
            elif event.get("type") == "error" and test_id is not None:
                errors.setdefault(test_id, []).append(_safe_text(event.get("error", "")))
            elif (
                event.get("type") == "testDone"
                and event.get("result") != "success"
                and not event.get("skipped")
                and not event.get("hidden")
            ):
                failures.append(
                    {
                        "name": names.get(test_id, "unknown"),
                        "errors": errors.get(test_id, [])[:3],
                    }
                )
                if len(failures) >= limit:
                    return failures
    return failures


def process_tail(completed, limit=12):
    """Retains enough non-machine output to identify a runner/tool crash."""
    lines = []
    for stream in (completed.stderr, completed.stdout):
        for line in stream.splitlines():
            if line.strip() and not line.startswith(("{", "[")):
                lines.append(_safe_text(line))
    return lines[-limit:]


def main():
    fmt, fmt_seconds = run(
        "dart format --output=none --set-exit-if-changed "
        "lib test tool integration_test".split()
    )
    analyze, analyze_seconds = run("flutter analyze --no-pub".split())
    tests, test_seconds = run(
        "flutter test --no-pub --concurrency 4 --machine".split()
    )
    passed, failed, skipped = count_tests(tests.stdout)
    steps = {
        "format": {"exitCode": fmt.returncode, "seconds": fmt_seconds},
        "analyze": {"exitCode": analyze.returncode, "seconds": analyze_seconds},
        "tests": {"exitCode": tests.returncode, "seconds": test_seconds},
    }
    failed_step = next(
        (name for name, step in steps.items() if step["exitCode"] != 0), None
    )
    result = {
        "ts": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
        "status": "passed" if failed_step is None else "failed",
        "failedStep": failed_step,
        "format": "temiz" if fmt.returncode == 0 else "HATA",
        "analyze": "temiz" if analyze.returncode == 0 else "HATA",
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "steps": steps,
        "testFailures": test_failures(tests.stdout),
        "diagnosticTail": process_tail(
            {"format": fmt, "analyze": analyze, "tests": tests}.get(failed_step, tests)
        )
        if failed_step
        else [],
    }
    out = ROOT / "qa" / "reports" / "code_gate.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(result)
    return 0 if failed_step is None else 1


if __name__ == "__main__":
    raise SystemExit(main())
