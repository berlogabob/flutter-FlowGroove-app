import unittest

from design.figcraft.spec_tree import flatten


class FlattenTest(unittest.TestCase):
    def test_flattens_visible_text_and_kinds_in_document_order(self):
        spec = {
            "top": [{"t": "appbar", "v": "Songs"}],
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


if __name__ == "__main__":
    unittest.main()
