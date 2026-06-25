#!/usr/bin/env python3
"""Render upstream markdown release notes as an appdata <release> block.

Reads the notes on stdin and writes the block to stdout, matching the markup the
existing entries use: section headings ("### Title") become <p><em>Title</em></p>
and bullet lists ("- item") become <ul><li>item</li></ul>, all indented to sit
inside <releases> and with XML-special characters escaped.

Usage: render_release.py <version> <date> [details-url]   (notes on stdin)
"""
import sys
from xml.sax.saxutils import escape

version, date = sys.argv[1], sys.argv[2]
details_url = sys.argv[3] if len(sys.argv) > 3 else ""

lines = [f'<release version="{version}" date="{date}">']
if details_url:
    lines.append(f"  <url type=\"details\">{escape(details_url)}</url>")
lines.append("  <description>")
in_list = False


def close_list():
    global in_list
    if in_list:
        lines.append("    </ul>")
        in_list = False


for raw in sys.stdin:
    text = raw.strip()
    if not text:
        continue
    if text.startswith("#"):  # "### Heading" -> <p><em>Heading</em></p>
        close_list()
        title = escape(text.lstrip("#").strip())
        lines.append(f"    <p><em>{title}</em></p>")
    elif text.startswith(("- ", "* ")):  # "- bullet" -> <li>bullet</li>
        if not in_list:
            lines.append("    <ul>")
            in_list = True
        lines.append(f"      <li>{escape(text[2:].strip())}</li>")
    else:  # any other prose line -> its own paragraph
        close_list()
        lines.append(f"    <p>{escape(text)}</p>")

close_list()
lines += ["  </description>", "</release>"]

if "<li>" not in "".join(lines) and "<p>" not in "".join(lines[2:-2]):
    sys.exit("no release notes to render")

print("\n".join(lines))
