import Foundation
import Quartz

pdf_url = Foundation.NSURL.fileURLWithPath_("part2_20.pdf")
pdf_doc = Quartz.PDFDocument.alloc().initWithURL_(pdf_url)

if pdf_doc:
    text = ""
    for i in range(pdf_doc.pageCount()):
        page = pdf_doc.pageAtIndex_(i)
        if page and page.string():
            text += page.string() + "\n"
    print(text)
else:
    print("Failed to load PDF")
