---
id: taxonomy-tags
artifact: tasks
---

## Tasks

### 1. Database — task_tags join table

- [ ] Create migration `CreateTaskTags`
- [ ] Table: `task_tags` with `task_id` (references, FK), `tag_id` (references, FK), timestamps
- [ ] Add unique index on `[task_id, tag_id]`
- [ ] Run migration

### 2. Models

- [ ] Create `app/models/task_tag.rb` — `belongs_to :task`, `belongs_to :tag`, validates uniqueness
- [ ] Update `app/models/task.rb` — add `has_many :task_tags, dependent: :destroy` and `has_many :tags, through: :task_tags`
- [ ] Update `app/models/tag.rb` — add `has_many :task_tags, dependent: :destroy` and `has_many :tasks, through: :task_tags`
- [ ] Add `items_count` helper method to Tag model

### 3. Routes

- [ ] Add `resources :tags, only: [:index, :show], param: :name` to web routes
- [ ] Add tag management API routes for documents: nested `resources :tags, only: [:create, :destroy], param: :name` under `api/documents`
- [ ] Add tag management API routes for tasks: nested `resources :tags, only: [:create, :destroy], param: :name` under `api/tasks` (or add tasks to API first)

### 4. Tags Controller (Web)

- [ ] Create `app/controllers/tags_controller.rb`
- [ ] `index` — list all tags alphabetically, optional search via `params[:q]`
- [ ] `show` — find tag by name, load associated documents and tasks

### 5. Tags Views

- [ ] Create `app/views/tags/index.html.erb` — grid of tag cards with color dot, name, item counts
- [ ] Create `app/views/tags/show.html.erb` — documents section + tasks section
- [ ] Reuse `documents/_card.html.erb` partial for documents
- [ ] Create or reuse task list partial for tasks

### 6. Tags CSS

- [ ] Add styles for tags page: `.tags-grid`, `.tag-card`, `.tag-color-dot`
- [ ] Add styles for tag detail page: `.tag-detail-page`, `.tag-section`
- [ ] Create `app/assets/stylesheets/tags.css` or add to `application.css`
- [ ] Register in `stylesheet_link_tag` if new file

### 7. Sidebar Navigation

- [ ] Add "Tags" link to sidebar navigation
- [ ] Use `heroicon(:tag)` for icon
- [ ] Active state when on `/tags*`

### 8. Tag Input Component — Documents

- [ ] Create `app/javascript/controllers/tag_input_controller.js`
- [ ] Features: text input, autocomplete dropdown, tag pills with remove, add new tag
- [ ] Register in `controllers/index.js`
- [ ] Add tag input section to `documents/edit.html.erb`
- [ ] Create API endpoint `POST /api/documents/:id/tags` — add tag
- [ ] Create API endpoint `DELETE /api/documents/:id/tags/:name` — remove tag
- [ ] Create `app/controllers/api/document_tags_controller.rb`

### 9. Tag Input Component — Tasks

- [ ] Add tag input to `tasks/new.html.erb` and `tasks/edit.html.erb`
- [ ] Reuse `tag_input_controller.js`
- [ ] Create API endpoint `POST /api/tasks/:id/tags` — add tag (requires tasks API)
- [ ] Create API endpoint `DELETE /api/tasks/:id/tags/:name` — remove tag

### 10. Tag Autocomplete API

- [ ] Create `GET /api/tags?q=query` endpoint for autocomplete
- [ ] Returns matching tags with name and color
- [ ] Used by `tag_input_controller.js` for suggestions

### 11. Manual Testing

- [ ] Browse `/tags` — see all tags with counts
- [ ] Click a tag → `/tags/:name` — see documents and tasks
- [ ] Add tag to document in editor → appears on card
- [ ] Remove tag from document in editor → disappears from card
- [ ] Add tag to task in form → appears on task
- [ ] Create new tag by typing in input → tag created
- [ ] Autocomplete shows existing tags while typing
- [ ] Tag link on document card → navigates to `/tags/:name`
- [ ] Sidebar "Tags" link works and shows active state
