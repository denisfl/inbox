---
id: pdf-preview
title: PDF Preview in Document Editor
status: proposed
created: 2025-07-18
---

## Problem

When a PDF file is attached to a document (either via Telegram or web upload), the user can only see a download link. To read the PDF, they must download it and open it in a separate application. This breaks the reading flow and adds friction to the document review workflow.

## Solution

Add inline PDF preview capability to the document editor. When a document contains a PDF file block, render the PDF inline using the browser's native `<iframe>` + `<object>` PDF viewer (supported in all modern browsers). Provide a fallback download link for environments where inline PDF rendering is not available (e.g., some mobile browsers).

## Scope

### In Scope

1. **File block partial** (`app/views/blocks/_file.html.erb`) — detect PDF MIME type and render an inline `<iframe>` viewer instead of just a download link
2. **Simple editor preview** (`simple_editor_controller.js` + API preview endpoint) — include PDF embed HTML in the preview response for documents containing PDF file blocks
3. **Styling** — responsive PDF viewer container that fits the editor width, with configurable height
4. **Mobile** — on narrow viewports, show a compact preview with explicit "Open PDF" / "Download" actions

### Out of Scope

- PDF text extraction / OCR (covered by `pdf-ocr` change)
- PDF annotation or editing
- PDF thumbnail generation
- Multi-page navigation controls (rely on browser's native PDF viewer)
- PDF.js integration (use native browser rendering first; PDF.js can be a future enhancement)

## Capabilities

### New Capabilities

- `pdf-inline-preview`: When a document has a PDF file block, display the PDF inline in an embedded viewer within the editor/preview
- `pdf-preview-toggle`: User can expand/collapse the PDF viewer to manage screen space

### Modified Components

- `blocks/_file.html.erb` — add PDF detection branch alongside existing audio detection
- `api/documents_controller.rb#preview` — include PDF embed HTML in preview response
- `documents/edit.html.erb` — render PDF file blocks inline (below audio section, above text)

## Impact

- **Code**: 2 modified files, 0 new files (all changes in existing views/controllers)
- **Dependencies**: none — uses native browser PDF rendering via `<iframe>` / `<object>`
- **Docker**: no changes
- **Performance**: PDF is streamed via Active Storage blob URL, no server-side processing
- **Browser support**: Chrome, Firefox, Safari, Edge all support inline PDF rendering; Android WebView may fall back to download link
