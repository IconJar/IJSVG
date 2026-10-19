#
#  test_import_mdn_svg.py
#  IJSVGExample
#
#  Created by Curtis Hard on 10/10/2026.
#  Copyright © 2026 Curtis Hard. All rights reserved.
#

"""Importer regression checks: python3 -m unittest discover -s Scripts -p 'test_*.py'."""
import tempfile
import unittest
from pathlib import Path

from import_mdn_svg import aspect_ratio_fragment, documents, embedded_svg, exclusion, normalize, pattern_fragment, standalone_fragment


class MDNImportTests(unittest.TestCase):
    def test_pattern_variants_reuse_the_complete_example_context(self):
        prefix = 'tutorials/svg_from_scratch/patterns/block-'
        source = '<svg><defs><linearGradient id="Gradient1"/><linearGradient id="Gradient2"/><pattern id="Pattern"><rect width="50"/></pattern></defs><rect fill="url(#Pattern)" width="200" height="200"/></svg>'
        variant = '<pattern id="Pattern" patternContentUnits="objectBoundingBox"><circle r=".1" fill="url(#Gradient1)"/></pattern>'
        xml = pattern_fragment(variant, prefix + '2', {prefix + '1': source})
        self.assertIn(variant, xml)
        self.assertIn('<linearGradient id="Gradient2"/>', xml)
        self.assertIn('<rect fill="url(#Pattern)" width="200" height="200"/>', xml)
        self.assertNotIn('<rect width="50"/>', xml)
        self.assertIsNone(pattern_fragment(variant, prefix + '2', {}))
        self.assertIsNone(pattern_fragment(variant, 'unknown', {prefix + '1': source}))
        self.assertIsNone(pattern_fragment('<pattern', prefix + '2', {prefix + '1': source}))
        self.assertIsNone(pattern_fragment(variant, prefix + '2', {prefix + '1': source.replace('Gradient2', 'missing')}))

    def test_reviewed_embedded_svg_preserves_namespaces_styles_and_geometry(self):
        source = '<html xmlns:svg="http://www.w3.org/2000/svg"><body><svg:svg width="300" height="200"><svg:circle cx="150" cy="100" r="50" fill="red"/></svg:svg></body></html>'
        xml = embedded_svg(source, 'guides/namespaces_crash_course/block-4')
        self.assertIn('xmlns="http://www.w3.org/2000/svg"', xml)
        self.assertIn('cx="150"', xml)
        self.assertIn('fill="red"', xml)
        self.assertEqual(documents(xml), ([xml], None))
        source = '<html><svg><style>rect.example {fill: red}</style><rect class="example" width="10" height="10"/></svg></html>'
        xml = embedded_svg(source, 'reference/attribute/class/block-1')
        self.assertIn('rect.example {fill: red}', xml)
        self.assertIn('class="example"', xml)
        self.assertIsNone(exclusion(xml, False))

    def test_embedded_svg_requires_reviewed_static_complete_context(self):
        known = 'guides/svg_in_html/block-1'
        self.assertIsNone(embedded_svg('<html><svg/></html>', 'unknown'))
        for source in ['<html><svg>', '<html/>', '<html><svg/><svg/></html>',
                       '<html onload="run()"><svg/></html>',
                       '<html><script>run()</script><svg/></html>']:
            self.assertIsNone(embedded_svg(source, known))

    def test_reviewed_anchor_fragment_preserves_link_and_geometry(self):
        code = '<a href="https://example.com/"><circle cx="50" cy="50" r="40"/></a>'
        xml = standalone_fragment(code, 'guides/linking/block-1')
        self.assertIn(code, xml)
        self.assertIn('viewBox="0 0 100 100"', xml)
        self.assertIsNone(exclusion(xml, False))
        self.assertIsNone(standalone_fragment(code, 'unknown'))

    def test_download_examples_split_only_the_reviewed_html_divider(self):
        first = '<svg><a href="data:image/svg+xml,example"><text>Display</text></a></svg>'
        second = '<svg><a href="data:image/svg+xml,example" download="heart.svg"><text>Download</text></a></svg>'
        code = first + '<hr />' + second
        self.assertEqual(documents(code, 'reference/attribute/download/block-2'), ([first, second], None))
        self.assertIsNotNone(documents(code)[1])
        self.assertIsNotNone(documents('<div>' + code + '</div>', 'reference/attribute/download/block-2')[1])

    def test_navigation_links_do_not_require_external_rendering_resources(self):
        for href in ['href', 'xlink:href']:
            xml = (f'<svg xmlns:xlink="http://www.w3.org/1999/xlink">'
                   f'<a {href}="https://example.org/"><circle r="5"/></a></svg>')
            self.assertIsNone(exclusion(xml, False))
        xml = '<svg><a href="https://example.org"><image href="missing.png"/></a></svg>'
        self.assertIn('External resource', exclusion(xml, False))

    def test_css_namespace_urls_are_identifiers_but_paint_urls_are_resources(self):
        css = '@namespace svg url("http://www.w3.org/2000/svg");'
        xml = '<svg><style>' + css + '</style><circle r="5"/></svg>'
        self.assertIsNone(exclusion(xml, False))
        for extra in ['circle {fill: url(https://example.org/paint)}', '@import "external.css";']:
            self.assertIn('External CSS', exclusion(xml.replace('</style>', extra + '</style>'), False))

    def test_aspect_ratio_fragments_retain_definitions_css_and_nested_viewports(self):
        prefix = 'reference/attribute/preserveaspectratio/block-'
        sources = {prefix + '3': '<svg viewBox="-1 -1 202 40"><defs><path id="smiley" d="M0 0L10 10"/></defs>',
                   prefix + '7': '</svg>', prefix + '8': 'path {fill: yellow}'}
        code = '<svg width="60" height="30" preserveAspectRatio="xMinYMid meet"><use href="#smiley"/></svg>'
        xml, css = aspect_ratio_fragment(code, prefix + '5', sources)
        self.assertIn(code, xml)
        self.assertIn('id="smiley"', xml)
        self.assertIn('viewBox="-1 -1 202 40"', xml)
        self.assertEqual(css, sources[prefix + '8'])
        self.assertIsNone(exclusion(xml, False))
        for missing in sources:
            self.assertIsNone(aspect_ratio_fragment(code, prefix + '5',
                                                    {k: v for k, v in sources.items() if k != missing}))
        self.assertIsNone(aspect_ratio_fragment('<svg>', prefix + '5', sources))
        self.assertIsNone(aspect_ratio_fragment(code, prefix + '3', sources))
        self.assertIsNone(aspect_ratio_fragment(code, 'other/block-5', sources))

    def test_reviewed_drawing_fragments_preserve_geometry_and_viewport(self):
        code = '<path d="M20,230 Q40,205 50,230 T90,230" fill="none" stroke="blue"/>'
        xml = standalone_fragment(code, 'tutorials/svg_from_scratch/basic_shapes/block-8')
        self.assertIn(code, xml)
        self.assertIn('viewBox="0 0 200 250"', xml)
        self.assertIsNone(exclusion(xml, False))

    def test_fragment_adaptation_does_not_accept_unreviewed_or_incomplete_context(self):
        known = 'tutorials/svg_from_scratch/basic_shapes/block-2'
        self.assertIsNone(standalone_fragment('<rect width="10"/>', 'unknown'))
        for code in ['<rect', '<div><rect/></div>', '<defs><rect/></defs>', '<script/>']:
            self.assertIsNone(standalone_fragment(code, known))

    def test_fragment_adaptation_retains_script_and_resource_exclusions(self):
        known = 'tutorials/svg_from_scratch/basic_shapes/block-2'
        for code in ['<rect width="10" onclick="run()"/>',
                     '<rect width="10" fill="url(https://example.org/paint)"/>']:
            self.assertIsNotNone(exclusion(standalone_fragment(code, known), False))

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

    def test_flower_stylesheet_is_embedded_without_ignoring_other_resources(self):
        source = '<svg><link href="style8.css"/><circle r="10"/></svg>'
        page = Path('/tmp/svg_and_css/index.md')
        css = 'circle {fill: var(--petal)}'
        xml, changes = normalize(source, css, page)
        self.assertNotIn('<link', xml)
        self.assertIn(css, xml)
        self.assertIsNone(exclusion(xml, False))
        self.assertTrue(any('style8.css' in change for change in changes))
        for document, stylesheet, location in [
            (source, '', page),
            (source, css, Path('/tmp/other/index.md')),
            (source.replace('style8.css', 'other.css'), css, page),
        ]:
            normalized, _ = normalize(document, stylesheet, location)
            self.assertIsNotNone(exclusion(normalized, False))

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
