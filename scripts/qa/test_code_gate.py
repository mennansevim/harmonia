#!/usr/bin/env python3
import importlib.util
import json
import pathlib
import subprocess
import unittest

HERE = pathlib.Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("code_gate", HERE / "code_gate.py")
code_gate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(code_gate)


class CodeGateTest(unittest.TestCase):
    def test_counts_and_names_a_real_failure_without_counting_skips(self):
        output = "\n".join(
            json.dumps(event)
            for event in [
                {"type": "testStart", "testID": 7, "test": {"name": "fails safely"}},
                {"type": "error", "testID": 7, "error": "expected true"},
                {"type": "testDone", "testID": 7, "result": "error"},
                {"type": "testDone", "testID": 8, "result": "success"},
                {"type": "testDone", "testID": 9, "result": "success", "skipped": True},
                {"type": "testDone", "testID": 10, "result": "error", "hidden": True},
            ]
        )

        self.assertEqual(code_gate.count_tests(output), (1, 1, 1))
        self.assertEqual(
            code_gate.test_failures(output),
            [{"name": "fails safely", "errors": ["expected true"]}],
        )

    def test_diagnostic_tail_is_bounded_and_redacts_repo_path(self):
        completed = subprocess.CompletedProcess(
            [], 1, stdout="\n".join(f"line {i}" for i in range(20)), stderr=str(code_gate.ROOT)
        )
        tail = code_gate.process_tail(completed, limit=3)

        self.assertEqual(len(tail), 3)
        self.assertNotIn(str(code_gate.ROOT), " ".join(tail))

    def test_bad_machine_lines_do_not_hide_valid_events(self):
        output = "not json\n{bad\n" + json.dumps(
            {"type": "testDone", "testID": 1, "result": "success"}
        )
        self.assertEqual(code_gate.count_tests(output), (1, 0, 0))
        self.assertEqual(code_gate.test_failures(output), [])


if __name__ == "__main__":
    unittest.main()
