## ADDED Requirements

### markdown-editing

Editing experience for text blocks using a Markdown textarea with preview toggle.

#### Requirement: Double-click to edit

Double-clicking on a rendered text block switches it to edit mode, revealing a `<textarea>` with the raw Markdown content.

#### Scenario: Enter edit mode
Given a text block rendered as HTML
When the user double-clicks the block
Then a textarea appears containing the raw Markdown source
And the rendered preview is hidden

#### Requirement: Preview toggle

A "Preview" button in edit mode renders the current textarea content as Markdown HTML without saving.

#### Scenario: Toggle preview in edit mode
Given a text block is in edit mode with content `"**bold**"`
When the user clicks "Preview"
Then the textarea is hidden
And the rendered preview shows `<strong>bold</strong>`
And a back button allows returning to the textarea

#### Requirement: Save on blur

When the user clicks away from the textarea, the block content is saved via `PATCH /api/blocks/:id` with the updated `content["text"]`.

#### Scenario: Save on blur
Given a text block is in edit mode
And the user has typed `"## New heading\n\nSome text"`
When the user clicks outside the edit area
Then a PATCH request is sent to `/api/blocks/:id`
And the request body contains `{ "block": { "content": { "text": "## New heading\n\nSome text" } } }`
And the block switches back to view mode showing the rendered Markdown

#### Requirement: Cancel edit

A "Cancel" button discards changes and returns to view mode without saving.

#### Scenario: Cancel edit
Given a text block is in edit mode
And the user has made changes to the textarea
When the user clicks "Cancel"
Then no PATCH request is sent
And the block returns to view mode with the original content
