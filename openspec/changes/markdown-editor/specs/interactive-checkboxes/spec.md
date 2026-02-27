## ADDED Requirements

### interactive-checkboxes

Task list checkboxes rendered from Markdown `- [ ]` / `- [x]` syntax are interactive and persist state.

#### Requirement: Checkboxes are clickable

Checkboxes rendered from GFM task list syntax (`- [ ]` / `- [x]`) in text blocks are not `disabled`. Clicking a checkbox toggles its checked state.

#### Scenario: Click unchecked checkbox
Given a text block with content `"- [ ] Buy milk\n- [ ] Call doctor"`
When the block is rendered
And the user clicks the first checkbox
Then the checkbox becomes checked
And the block content is updated to `"- [x] Buy milk\n- [ ] Call doctor"`
And the updated content is saved via PATCH

#### Scenario: Uncheck a checked checkbox
Given a text block with content `"- [x] Done task\n- [ ] Pending task"`
When the user clicks the first (checked) checkbox
Then the checkbox becomes unchecked
And the block content is updated to `"- [ ] Done task\n- [ ] Pending task"`
And the updated content is saved via PATCH

#### Requirement: Checkbox toggle is persisted

After toggling a checkbox, the change is saved immediately via `PATCH /api/blocks/:id`. On page reload, the checkbox reflects the saved state.

#### Scenario: Checkbox state persists after reload
Given the user toggled a checkbox to checked
And the PATCH request succeeded
When the user reloads the page
Then the checkbox is rendered as checked
