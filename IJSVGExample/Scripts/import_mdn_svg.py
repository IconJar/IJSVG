#!/usr/bin/env python3
"""Import MDN SVG examples from a pinned checkout, excluding foreignObject.

Usage: python3 Scripts/import_mdn_svg.py /path/to/mdn/content
Only the standard library is needed. Tests never access the network.
"""
import argparse
import base64
import hashlib
import json
import mimetypes
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1] / "IJSVGExampleTests"
FENCES = re.compile(r"^```([^\n]*)\n(.*?)^```\s*$", re.M | re.S)
SVG = re.compile(r"</?svg\b[^>]*>", re.I)
FOREIGN_OBJECT = re.compile(r"<(?:[\w.-]+:)?foreignObject\b", re.I)


def documents(code):
    """Keep nested SVGs intact, splitting only top-level documents."""
    depth, start, end = 0, 0, 0
    result = []
    for match in SVG.finditer(code):
        closing = match[0].startswith("</")
        if not closing and depth == 0:
            if code[end:match.start()].strip():
                return [], "HTML wrapper or incomplete SVG fragment"
            start = match.start()
        depth += -1 if closing else 1
        if match[0].endswith("/>"):
            depth -= 1
        if depth == 0:
            result.append(code[start:match.end()])
            end = match.end()
    if depth or not result or code[end:].strip():
        return [], "HTML wrapper or incomplete SVG fragment"
    return result, None


def normalize(xml, css, page, asset_root=None):
    changes = []
    # Local images are embedded so both engines see identical offline data.
    def asset(match):
        value = match[2]
        if value.startswith(("#", "data:")):
            return match[0]
        path = (page.parent / value).resolve()
        if path.is_relative_to((asset_root or page.parent).resolve()) and path.is_file() and path.suffix.lower() in {".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg"}:
            data = base64.b64encode(path.read_bytes()).decode()
            changes.append("Embedded local asset: " + value)
            return match[1] + "data:" + mimetypes.guess_type(path)[0] + ";base64," + data + match[3]
        return match[0]
    xml = re.sub(r'''((?:href|src)\s*=\s*["'])([^"']+)(["'])''', asset, xml)
    if "xmlns=" not in SVG.search(xml)[0]:
        xml = xml.replace("<svg", '<svg xmlns="http://www.w3.org/2000/svg"', 1)
        changes.append("Added SVG namespace")
    if "xlink:" in xml and "xmlns:xlink=" not in xml:
        xml = xml.replace("<svg", '<svg xmlns:xlink="http://www.w3.org/1999/xlink"', 1)
        changes.append("Added xlink namespace")
    if css:
        end = xml.index(">") + 1
        xml = xml[:end] + "<style><![CDATA[\n" + css + "\n]]></style>" + xml[end:]
        changes.append("Included CSS from the enclosing live sample")
    return xml, changes


def exclusion(xml, javascript):
    if javascript:
        return "Live sample requires JavaScript; static SVG comparison cannot reproduce its behavior"
    if re.search(r"<(?:animate\w*|set|discard)\b|@keyframes|\banimation\s*:", xml, re.I):
        return "Animation requires a separately defined timeline expectation"
    if re.search(r"<script\b|\son\w+\s*=", xml, re.I):
        return "Scripted or interactive SVG"
    if re.search(r'''(?:href|src)\s*=\s*["'](?!#|data:)[^"']+''', xml):
        return "External resource not embedded in the MDN source checkout"
    if re.search(r'''url\(\s*["']?(?!#|data:)[^\s)"']''', xml) or "@import" in xml:
        return "External CSS resource"
    if "{{" in xml:
        return "Unexpanded MDN template in source"
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as error:
        return "Not standalone XML: " + str(error)
    def paints(node):
        tag = node.tag.split('}')[-1]
        if tag in {'defs', 'symbol', 'clipPath', 'mask', 'marker', 'pattern', 'filter', 'style', 'metadata'}:
            return False
        if tag == 'path':
            return bool(re.search(r'[LlHhVvCcSsQqTtAaZz]', node.get('d', '')))
        if tag in {'rect', 'circle', 'ellipse', 'line', 'polyline', 'polygon', 'text', 'use', 'image'}:
            return True
        return any(paints(child) for child in node)
    if not paints(root):
        return "Definition-only or non-painting snippet; no visual comparison to assert"
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checkout", type=Path)
    args = parser.parse_args()
    checkout = args.checkout.resolve()
    revision = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output(["git", "-C", str(checkout), "status", "--porcelain", "--",
                                     "files/en-us/web/svg"], text=True)
    if dirty:
        raise SystemExit("MDN source has local changes; use a clean, pinned checkout")
    source = checkout / "files/en-us/web/svg"
    pages, examples, cases = [], [], []
    for page in sorted(source.rglob("index.md")):
        if page.parent.name.lower() == "foreignobject":
            continue
        text = page.read_text()
        slug = re.search(r"^slug: (.+)$", text, re.M)[1]
        page_id = str(page.parent.relative_to(source))
        blocks = list(FENCES.finditer(text))
        headings = list(re.finditer(r"^(#{2,6}) (.+)$", text, re.M))
        # EmbedLiveSample references a heading and includes that heading's subtree.
        groups = []
        for embed in re.finditer(r'''EmbedLiveSample\(\s*["']([^"']+)["']''', text):
            name = embed[1].lower().replace(" ", "_")
            for heading in headings:
                if heading[2].lower().replace(" ", "_") == name:
                    end = next((h.start() for h in headings if h.start() > heading.start() and len(h[1]) <= len(heading[1])), len(text))
                    groups.append((heading.start(), end))
                    break
        page_cases = []
        for index, block in enumerate(blocks, 1):
            if FOREIGN_OBJECT.search(block[2]):
                continue
            language = block[1].split()[0] if block[1].strip() else "plain"
            entry = {"id": f"{page_id}/block-{index}", "language": language,
                     "info": block[1], "source": block[2], "line": text[:block.start()].count("\n") + 1,
                     "url": "https://developer.mozilla.org/en-US/docs/" + slug,
                     "sourcePath": str(page.relative_to(checkout))}
            examples.append(entry)
            if language not in {"html", "html-nolint", "xml", "svg"}:
                continue
            code = re.sub(r"<!--.*?-->|<\?xml.*?\?>|<!DOCTYPE[^>]*>", "", block[2], flags=re.S).strip()
            docs, reason = documents(code)
            group = next(((a, b) for a, b in groups if a <= block.start() < b), None)
            companions = [b for b in blocks if group and group[0] <= b.start() < group[1]]
            css = "\n".join(b[2] for b in companions if b[1].split()[0] == "css")
            javascript = any(b[1].split()[0] in {"js", "javascript"} for b in companions)
            if not docs:
                docs = [None]
            for number, document in enumerate(docs, 1):
                case_id = re.sub(r"[^a-zA-Z0-9]", "_", f"{page_id}_block_{index}_{number}")
                case = {"id": case_id, "example": entry["id"], "url": entry["url"]}
                if document:
                    xml, changes = normalize(document, css, page, checkout)
                    case.update(svg=xml, adaptations=changes, sha256=hashlib.sha256(xml.encode()).hexdigest())
                    reason = exclusion(xml, javascript)
                if reason:
                    case["skip"] = reason
                cases.append(case)
                page_cases.append(case_id)
        pages.append({"path": page_id, "url": "https://developer.mozilla.org/en-US/docs/" + slug,
                      "blocks": len(blocks), "cases": page_cases})
    assets = []
    for asset in sorted(source.rglob('*.svg')):
        code = asset.read_text()
        if FOREIGN_OBJECT.search(code):
            continue
        case_id = 'asset_' + re.sub(r'[^a-zA-Z0-9]', '_', str(asset.relative_to(source)))
        source_path = str(asset.relative_to(checkout))
        url = f'https://github.com/mdn/content/blob/{revision}/{source_path}'
        entry = {'id': case_id, 'language': 'svg', 'source': code, 'line': 1,
                 'url': url, 'sourcePath': source_path}
        assets.append(entry)
        xml = re.sub(r'<\?xml.*?\?>|<!DOCTYPE[^>]*>', '', code, flags=re.S).strip()
        xml, changes = normalize(xml, '', asset, checkout)
        case = {'id': case_id, 'example': case_id, 'url': url, 'svg': xml,
                'adaptations': changes, 'sha256': hashlib.sha256(xml.encode()).hexdigest()}
        reason = exclusion(xml, False)
        if reason:
            case['skip'] = reason
        cases.append(case)
    if not cases:
        raise SystemExit("No MDN SVG cases found; check the sparse checkout")
    corpus = {"schemaVersion": 1, "repository": "https://github.com/mdn/content", "revision": revision,
              "pages": pages, "examples": examples, "assets": assets, "cases": cases}
    output = ROOT / "MDN"
    output.mkdir(exist_ok=True)
    (output / "corpus.json").write_text(json.dumps(corpus, indent=2, ensure_ascii=False) + "\n")
    policies = json.loads((output / "expectations.json").read_text())
    comparisons = [case for case in cases
                   if not (policies.get(case["id"], {}).get("excludeComparison") and
                           policies[case["id"]].get("sha256") == case.get("sha256"))]
    methods = "// Generated by Scripts/import_mdn_svg.py. Do not edit.\n"
    for case in comparisons:
        methods += '- (void)test_' + case["id"] + '\n{\n    [self compareCase:@"' + case["id"] + '"];\n}\n\n'
    (ROOT / "IJSVGMDNGeneratedTests.inc").write_text(methods.rstrip() + "\n")
    print(f"{len(pages)} pages, {len(examples)} fenced examples, {len(cases)} cases, "
          f"{sum('skip' not in c for c in comparisons)} static comparisons, "
          f"{len(cases) - len(comparisons)} verified WebKit exclusions")


if __name__ == "__main__":
    main()
