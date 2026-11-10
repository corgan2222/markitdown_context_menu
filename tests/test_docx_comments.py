"""Integration tests using synthetic DOCX packages, never private documents.

Run: python -m unittest discover -s tests -p "test_*.py"
Requires markitdown[docx]>=0.1.8.
"""

import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from zipfile import ZipFile


SPEC = importlib.util.spec_from_file_location(
    "comments_converter", Path(__file__).parents[1] / "src" / "ConvertDocxWithComments.py"
)
converter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(converter)


def write_docx(path, comments=True):
    ns = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    rel = "http://schemas.openxmlformats.org/package/2006/relationships"
    office = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    with ZipFile(path, "w") as z:
        z.writestr("[Content_Types].xml", '''<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="xml" ContentType="application/xml"/>
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/comments.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"/>
</Types>''')
        z.writestr("_rels/.rels", f'<Relationships xmlns="{rel}"><Relationship Id="rId1" Type="{office}/officeDocument" Target="word/document.xml"/></Relationships>')
        marker = '<w:commentReference w:id="0"/>' if comments else ''
        z.writestr("word/document.xml", f'<w:document xmlns:w="{ns}"><w:body><w:p><w:r><w:t>Body: caf\u00e9 and \u4e2d\u6587.</w:t></w:r><w:r>{marker}</w:r></w:p></w:body></w:document>')
        if comments:
            z.writestr("word/_rels/document.xml.rels", f'<Relationships xmlns="{rel}"><Relationship Id="rId2" Type="{office}/comments" Target="comments.xml"/></Relationships>')
            z.writestr("word/comments.xml", f'<w:comments xmlns:w="{ns}"><w:comment w:id="0" w:author="Test Reviewer" w:initials="TR"><w:p><w:r><w:t>Review: na\u00efve \u2014 \u4f60\u597d.</w:t></w:r></w:p></w:comment></w:comments>')


class CommentConversionTests(unittest.TestCase):
    def test_body_comments_and_unicode_are_preserved_without_changing_source(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "review [draft].docx"
            write_docx(path)
            before = path.read_bytes()
            result = converter.convert_with_comments(path)
            self.assertIn("Body: caf\u00e9 and \u4e2d\u6587.", result)
            self.assertIn("Review: na\u00efve \u2014 \u4f60\u597d.", result)
            self.assertIn("Comment [TR1]", result)
            self.assertIn("#comment-0", result)
            self.assertEqual(path.read_bytes(), before)

    def test_document_without_comments_still_converts(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "plain.docx"
            write_docx(path, comments=False)
            self.assertIn("Body:", converter.convert_with_comments(path))

    def test_non_docx_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "requires a .docx"):
            converter.convert_with_comments(Path("file.pdf"))

    def test_old_markitdown_fails_instead_of_silently_dropping_comments(self):
        with patch.object(converter, "version", return_value="0.1.7"):
            with self.assertRaisesRegex(RuntimeError, "0.1.8"):
                converter.convert_with_comments(Path("file.docx"))


if __name__ == "__main__":
    unittest.main()
