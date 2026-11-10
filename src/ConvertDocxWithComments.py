"""Convert a DOCX body and its comments to a single Markdown stream."""

import argparse
from importlib.metadata import version
from pathlib import Path
import re
import sys

from markitdown import MarkItDown


def convert_with_comments(path: Path) -> str:
    if path.suffix.lower() != ".docx":
        raise ValueError("Including comments requires a .docx file.")
    # Older versions silently ignore style_map, producing incomplete output.
    installed = tuple(int(n) for n in re.findall(r"\d+", version("markitdown"))[:3])
    if installed < (0, 1, 8):
        raise RuntimeError(
            "Including comments requires markitdown 0.1.8 or newer. Update markitdown in Settings. "
            f"If it stays older, markitdown 0.1.8+ may not support Python {sys.version_info[0]}.{sys.version_info[1]} yet."
        )
    result = MarkItDown().convert(str(path), style_map="comment-reference => sup")
    return result.text_content


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    args = parser.parse_args()
    try:
        markdown = convert_with_comments(args.input)
    except Exception as exc:
        parser.exit(1, f"DOCX conversion failed: {exc}\n")
    sys.stdout.write(markdown)


if __name__ == "__main__":
    main()
