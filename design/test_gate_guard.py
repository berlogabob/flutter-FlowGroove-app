import unittest

from design.gate_guard import violations


class GateGuardTests(unittest.TestCase):
    def test_higher_ratchet_is_rejected(self):
        self.assertTrue(violations({"design/ratchets.json": '{"k4": 3}'}, {"design/ratchets.json": '{"k4": 4}'}))

    def test_removed_parity_line_is_rejected(self):
        self.assertTrue(violations({"design/parity_lock.txt": "a\nb\n"}, {"design/parity_lock.txt": "a\n"}))

    def test_added_stable_layout_allow_line_is_rejected(self):
        self.assertTrue(violations({"design/stable_layout_allow.txt": "a\n"}, {"design/stable_layout_allow.txt": "a\nb\n"}))

    def test_fewer_test_expectations_are_rejected(self):
        path = "test/sample_test.dart"
        self.assertTrue(violations({path: "expect(a, b);\nexpectLater(a, b);"}, {path: "expect(a, b);"}))

    def test_clean_input_has_no_violations(self):
        self.assertEqual([], violations({"lib/a.dart": "same"}, {"lib/a.dart": "same"}))


if __name__ == "__main__":
    unittest.main()
