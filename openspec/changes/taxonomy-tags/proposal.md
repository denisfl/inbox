---
id: taxonomy-tags
title: Unified Taxonomy — Tags for Documents and Tasks
status: proposed
created: 2025-07-18
---

## Problem

Tags already exist for documents (`tags`, `document_tags` tables), but tasks have no tag support. There is no dedicated tag management page, and no way to view all items (documents + tasks) associated with a tag. This limits cross-referencing and organization capabilities.

## Solution

Extend the existing tag system to support tasks, add a tag management/browse page, and provide a unified view of all items tagged with a given tag.

## Scope

### In Scope

1. **Task tags** — Add `task_tags` join table, update Task model with `has_many :tags, through: :task_tags`
2. **Tag page** (`/tags`) — Browse all tags with item counts (documents + tasks), search/filter
3. **Tag detail page** (`/tags/:name`) — Show all documents and tasks with this tag, grouped by type
4. **Tag input in task forms** — Add tag selector to task create/edit forms (similar to how documents get tags via Telegram/API)
5. **Tag input in document editor** — Add tag management to `/documents/:id/edit` (add/remove tags)
6. **Tag autocomplete** — When typing a tag name, suggest existing tags
7. **Tag colors** — Tags table already has `color` column; allow setting/displaying colors

### Out of Scope

- Hierarchical tags / tag categories (flat namespace only)
- Tag-based permissions or visibility rules
- Tag-based notifications
- Bulk tag operations (tag multiple items at once)
- Tag rename/merge (can be added later)

## Current State

### Existing Infrastructure

| Component | Status |
|-----------|--------|
| `tags` table | ✅ Exists: `name`, `color`, timestamps, unique index on `name` |
| `document_tags` join table | ✅ Exists: `document_id`, `tag_id`, unique compound index |
| `Tag` model | ✅ Exists: `has_many :documents, through: :document_tags`, scopes `popular`, `alphabetical` |
| `DocumentTag` model | ✅ Exists: validates uniqueness |
| Document card tags | ✅ Shows tags on document cards, links to `root_path(tag: tag.name)` |
| Documents filter by tag | ✅ `params[:tag]` filter in DocumentsController |
| Tasks tag support | ❌ Missing — no `task_tags` table, no associations |
| Tag management page | ❌ Missing — no `/tags` route or controller |
| Tag input in forms | ❌ Missing — tags only set via Telegram/API |

### New Components

| Component | Description |
|-----------|-------------|
| `task_tags` table | Join table: `task_id`, `tag_id`, unique compound index |
| `TaskTag` model | `belongs_to :task`, `belongs_to :tag` |
| Task model update | `has_many :task_tags`, `has_many :tags, through: :task_tags` |
| Tag model update | `has_many :task_tags`, `has_many :tasks, through: :task_tags` |
| `TagsController` | `index` (browse tags), `show` (tag detail with items) |
| Tag routes | `resources :tags, only: [:index, :show], param: :name` |
| Tag input component | Stimulus controller for tag autocomplete + add/remove |
| `/tags` page | Grid of tag cards with counts |
| `/tags/:name` page | Documents + tasks with this tag |

## Capabilities

### New Capabilities

- `task-tags`: Assign tags to tasks
- `tag-browse`: Browse all tags at `/tags` with item counts
- `tag-detail`: View all documents and tasks for a specific tag at `/tags/:name`
- `tag-input`: Add/remove tags from documents and tasks via UI
- `tag-autocomplete`: Type-ahead suggestion of existing tags

### Modified Components

- `Tag` model — add task associations
- `Task` model — add tag associations
- Task forms (`tasks/new`, `tasks/edit`) — add tag input
- Document editor (`documents/edit`) — add tag management
- Sidebar navigation — add "Tags" link
- Dashboard — optionally show popular tags

## Data Model

```
tags (existing)
├── id
├── name (unique, lowercase)
├── color (optional)
├── created_at
└── updated_at

document_tags (existing)
├── id
├── document_id → documents
├── tag_id → tags
└── unique [document_id, tag_id]

task_tags (NEW)
├── id
├── task_id → tasks
├── tag_id → tags
├── created_at
├── updated_at
└── unique [task_id, tag_id]
```

## Impact

- **Code**: 1 new model, 1 new controller, 2 new views, 3 modified models, 2 modified views, 1 new Stimulus controller
- **Database**: 1 new table (`task_tags`), 0 changes to existing tables
- **Dependencies**: none
- **Routes**: 2 new routes (`/tags`, `/tags/:name`)
