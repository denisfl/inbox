---
id: simplified-editor
title: Simplified Document Editor
status: implementing
created: 2026-02-27
---

## Problem

The block-based editor is complex with 8 block types, drag-and-drop, keyboard shortcuts, and multiple interaction patterns. Users struggle with:
- Too many block types to remember
- Block switching (text → heading → todo) is friction
- The editor feels like a CMS, not a notepad

## Solution

Replace the multi-block editor with a single Markdown textarea per document. The document has one text block. The editor is a simple textarea with:
- Full-width Markdown input
- Auto-save with debounce
- File/image upload with Markdown link insertion
- Preview toggle (textarea ↔ rendered HTML)

## Scope

- `app/views/documents/edit.html.erb` — full rewrite
- `app/javascript/controllers/simple_editor_controller.js` — NEW
- `app/javascript/controllers/index.js` — register new controller
- `app/controllers/api/documents_controller.rb` — add upload endpoint
- `config/routes.rb` — add upload route
- Keep all block-related code for Telegram/API compatibility

## Out of scope

- Block model changes — blocks still exist in DB, just hidden from UI
- Telegram ingestion — still creates blocks as before
- API — still works as before
