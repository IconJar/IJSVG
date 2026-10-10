"""Importer regression checks: python3 -m unittest discover -s Scripts -p 'test_*.py'."""
import tempfile
import unittest
from pathlib import Path

from import_mdn_svg import documents, exclusion, normalize


class MDNImportTests(unittest.TestCase):
    def test_nested_svg_is_not_split(self):
        xml = '<svg><svg><circle r="10"/></svg></svg>'
        self.assertEqual(documents(xml), ([xml], None))

    def test_sibling_documents_remain_separate(self):
        self.assertEqual(documents('<svg/>\n<svg><path/></svg>'),
                         (['<svg/>', '<svg><path/></svg>'], None))

    def test_html_context_and_incomplete_fragments_are_reported(self):
        for code in ['<div><svg/></div>', '<svg><circle/>', '<circle r="5"/>']:
            self.assertIsNotNone(documents(code)[1])

    def test_css_and_namespaces_are_preserved(self):
        xml, changes = normalize('<svg><use xlink:href="#p"/></svg>',
                                 'path {fill: red}', Path('/tmp/index.md'))
        self.assertIn('xmlns:xlink=', xml)
        self.assertIn('path {fill: red}', xml)
        self.assertIsNone(exclusion(xml, False))
        self.assertEqual(len(changes), 3)

    def test_local_images_are_embedded_and_external_images_are_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'example.png').write_bytes(b'fixture bytes')
            xml, changes = normalize('<svg><image href="example.png"/></svg>', '', root / 'index.md')
            self.assertIn('data:image/png;base64,', xml)
            self.assertIsNone(exclusion(xml, False))
            self.assertIn('Embedded local asset: example.png', changes)
        self.assertIsNotNone(exclusion('<svg><image href="https://example.org/a.png"/></svg>', False))

    def test_static_fragment_urls_do_not_count_as_external_resources(self):
        self.assertIsNone(exclusion('<svg><rect fill="url(\'#paint\')"/></svg>', False))
        self.assertIsNotNone(exclusion('<svg><style>rect {fill: url(https://example.org/a)}</style></svg>', False))

    def test_animation_and_script_are_explicit(self):
        self.assertIn('Animation', exclusion('<svg><animate/></svg>', False))
        self.assertIn('JavaScript', exclusion('<svg/>', True))
        self.assertIn('Scripted', exclusion('<svg onload="run()"/>', False))

    def test_definition_only_and_move_only_examples_are_not_visual_passes(self):
        for xml in ['<svg><defs><circle r="4"/></defs></svg>', '<svg><path d="M10 10"/></svg>']:
            self.assertIn('non-painting', exclusion(xml, False))
        self.assertIsNone(exclusion('<svg><defs><circle id="c" r="4"/></defs><use href="#c"/></svg>', False))


if __name__ == '__main__':
    unittest.main()
