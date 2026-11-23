import unittest

from design.figcraft.spec_tree import flatten


class FlattenTest(unittest.TestCase):
    def test_flattens_visible_text_and_kinds_in_document_order(self):
        spec = {
            "top": [{"t": "appbar", "v": "Songs", "back": False}],
            "body": [
                {
                    "t": "row",
                    "c": [
                        {"t": "input", "hint": "Search..."},
                        {"t": "chip", "v": "All"},
                    ],
                },
                {"t": "tile", "title": "First Song", "trail": "chevron_right"},
            ],
            "bottom": [{"t": "bottomnav"}],
        }

        self.assertEqual(
            flatten(spec, {"chevron_right"}),
            {
                "texts": [
                    "Songs",
                    "Search...",
                    "All",
                    "First Song",
                    "Home",
                    "Songs",
                    "Bands",
                    "Setlists",
                    "More",
                ],
                "kinds": ["appbar", "input", "chip", "tile"],
            },
        )

    def test_bars_count_what_the_app_draws(self):
        flat = flatten(
            {
                "top": [{"t": "appbar", "v": "Song"}],
                "bottom": [{"t": "actionbar", "title": "Tuner"}, {"t": "actionbar", "primary": "Save", "menu": False}],
            },
            set(),
        )
        self.assertEqual(flat["texts"], ["Song", "Tuner", "Back", "Menu", "Save", "Back"])
        self.assertEqual(flat["kinds"], ["appbar", "iconbtn"])
        self.assertEqual(flatten({"top": [{"t": "appbar", "v": "S", "back": False, "actions": ["add"]}]}, {"add"})["kinds"],
                         ["appbar", "iconbtn"])


if __name__ == "__main__":
    unittest.main()
