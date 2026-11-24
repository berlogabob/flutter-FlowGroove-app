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

    def test_song_map_nodes_follow_the_app_layout_order(self):
        flat = flatten(
            {
                "body": [
                    {"t": "overview", "sections": [{"letter": "A", "bars": 2}, {"letter": "B", "bars": 1}]},
                    {"t": "zoomwave", "title": "A", "startBar": 3,
                     "parts": [{"letter": "a", "bars": 1}, {"letter": "b", "bars": 2}]},
                    {"t": "row", "c": [{"t": "key", "v": "Chop"}]},
                    {"t": "row", "c": [{"t": "pad", "letter": "A", "label": "Intro", "sub": "2 bars"},
                                       {"t": "pad", "letter": "B", "label": "Verse", "sub": "1 bar"}]},
                ],
                "bottom": [{"t": "transport", "playing": True}],
            },
            set(),
        )
        self.assertEqual(
            flat["texts"],
            ["A", "B", "a", "b", "1 bar", "2 bars", "3", "4", "5", "Chop",
             "Intro", "Verse", "A", "B", "2 bars", "1 bar", "Pause", "Loop", "Click", "Drums", "Count-in"],
        )
        self.assertEqual(flat["kinds"], ["button"])

    def test_overlay_texts_are_marked_as_a_separate_part(self):
        flat = flatten({"body": [{"t": "text", "v": "Back"}],
                        "overlay": [{"x": 0, "y": 500, "node": {"t": "sheet", "c": [{"t": "text", "v": "Sheet"}]}}]}, set())
        self.assertEqual(["Back", "Sheet"], flat["texts"])
        self.assertEqual(1, flat["overlay_from"])
        self.assertNotIn("overlay_from", flatten({"body": [{"t": "text", "v": "Back"}]}, set()))

    def test_blank_values_and_avatar_initials_are_not_texts(self):
        flat = flatten({"body": [{"t": "avatar", "icon": "person"}, {"t": "input", "label": "Search", "v": ""}],
                        "overlay": [{"x": 0, "y": 0, "node": {"t": "text", "v": "R"}}]}, set())
        self.assertEqual(["Search"], flat["texts"])
        # An overlay initial with no avatar on the screen, or a real label, stays.
        self.assertEqual(["R"], flatten({"body": [], "overlay": [{"node": {"t": "text", "v": "R"}}]}, set())["texts"])
        self.assertEqual(["Edit"], flatten({"body": [{"t": "avatar", "icon": "person"}],
                                            "overlay": [{"node": {"t": "text", "v": "Edit"}}]}, set())["texts"])


if __name__ == "__main__":
    unittest.main()
