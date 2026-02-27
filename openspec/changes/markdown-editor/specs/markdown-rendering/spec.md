## ADDED Requirements

### markdown-rendering

Server-side Markdown rendering for text blocks using Redcarpet.

#### Requirement: Render text block content as HTML

Text blocks render their `content["text"]` value as formatted HTML using Redcarpet.

Supported formatting:
- Headings (`#`, `##`, `###`)
- Bold (`**text**`), italic (`*text*`), strikethrough (`~~text~~`)
- Inline code (`` `code` ``), fenced code blocks (` ``` `)
- Unordered lists (`- item`), ordered lists (`1. item`)
- GFM task lists (`- [ ] todo`, `- [x] done`)
- Autolinks (bare URLs become clickable links)
- Tables (GFM-style)
- Hard line breaks (single newline = `<br>`)

#### Scenario: Plain text renders as paragraph
Given a text block with content `"Hello world"`
When the block is rendered
Then the output is `<p>Hello world</p>`

#### Scenario: Markdown headings render as HTML headings
Given a text block with content `"## Section\n\nParagraph text"`
When the block is rendered
Then the output contains `<h2>Section</h2>` and `<p>Paragraph text</p>`

#### Scenario: Task list renders as checkboxes
Given a text block with content `"- [ ] Buy milk\n- [x] Call doctor"`
When the block is rendered
Then the output contains two `<input type="checkbox">` elements
And the first checkbox is unchecked
And the second checkbox is checked

#### Scenario: Links open in new tab
Given a text block with content `"See https://example.com"`
When the block is rendered
Then the link has `target="_blank"` and `rel="noopener"`

#### Requirement: Rendering is XSS-safe

The Redcarpet renderer uses HTML-safe escaping. User content is sanitized before rendering.

#### Scenario: Script tags are escaped
Given a text block with content `"<script>alert(1)</script>"`
When the block is rendered
Then the output does not contain `<script>`
And the content is HTML-escaped
