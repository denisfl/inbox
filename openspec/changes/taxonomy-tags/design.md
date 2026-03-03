---
id: taxonomy-tags
artifact: design
---

## Architecture

### Data Layer

#### Migration: `create_task_tags`

```ruby
class CreateTaskTags < ActiveRecord::Migration[8.1]
  def change
    create_table :task_tags do |t|
      t.references :task, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      t.timestamps
    end

    add_index :task_tags, [:task_id, :tag_id], unique: true
  end
end
```

#### Model Changes

```ruby
# app/models/task_tag.rb (NEW)
class TaskTag < ApplicationRecord
  belongs_to :task
  belongs_to :tag
  validates :task_id, uniqueness: { scope: :tag_id }
end

# app/models/task.rb (ADD)
has_many :task_tags, dependent: :destroy
has_many :tags, through: :task_tags

# app/models/tag.rb (ADD)
has_many :task_tags, dependent: :destroy
has_many :tasks, through: :task_tags

def items_count
  document_tags.count + task_tags.count
end
```

### Routes

```ruby
# config/routes.rb
resources :tags, only: [:index, :show], param: :name
```

### Controller

```ruby
# app/controllers/tags_controller.rb
class TagsController < ApplicationController
  def index
    @tags = Tag.alphabetical
    if params[:q].present?
      @tags = @tags.where("name LIKE ?", "%#{params[:q].strip.downcase}%")
    end
  end

  def show
    @tag = Tag.find_by!(name: params[:name].downcase)
    @documents = @tag.documents.includes(:blocks, :tags).order(updated_at: :desc)
    @tasks = @tag.tasks.order(completed: :asc, priority: :desc, position: :asc)
  end
end
```

### Views

#### `/tags` — Tag Index

Grid of tag cards, each showing:

- Tag name (colored dot from `tag.color`)
- Count: "X documents, Y tasks"
- Click → `/tags/:name`

```erb
<%# app/views/tags/index.html.erb %>
<div class="tags-page">
  <header class="tags-header">
    <h1>Tags</h1>
    <!-- Search input -->
  </header>

  <div class="tags-grid">
    <% @tags.each do |tag| %>
      <%= link_to tag_path(tag.name), class: "tag-card" do %>
        <span class="tag-color-dot" style="background:<%= tag.color || 'var(--color-text-tertiary)' %>"></span>
        <span class="tag-name"><%= tag.name %></span>
        <span class="tag-count">
          <%= tag.documents.count %> docs · <%= tag.tasks.count %> tasks
        </span>
      <% end %>
    <% end %>
  </div>
</div>
```

#### `/tags/:name` — Tag Detail

Two sections: Documents and Tasks, each rendered as existing cards/list items.

```erb
<%# app/views/tags/show.html.erb %>
<div class="tag-detail-page">
  <header class="tag-detail-header">
    <%= back_link(tags_path, "Tags") %>
    <h1>
      <span class="tag-color-dot" style="background:<%= @tag.color || 'var(--color-text-tertiary)' %>"></span>
      #<%= @tag.name %>
    </h1>
  </header>

  <% if @documents.any? %>
    <section class="tag-section">
      <h2>Documents (<%= @documents.count %>)</h2>
      <div class="documents-grid">
        <%= render partial: "documents/card", collection: @documents, as: :document %>
      </div>
    </section>
  <% end %>

  <% if @tasks.any? %>
    <section class="tag-section">
      <h2>Tasks (<%= @tasks.count %>)</h2>
      <div class="task-list">
        <% @tasks.each do |task| %>
          <!-- render task item -->
        <% end %>
      </div>
    </section>
  <% end %>
</div>
```

### Tag Input Component

A Stimulus controller (`tag-input`) for adding/removing tags:

```
┌─────────────────────────────────────────┐
│ Tags: [work] [project] [___________|▼] │
│                          ┌───────────┐  │
│                          │ work      │  │
│                          │ personal  │  │
│                          │ urgent    │  │
│                          └───────────┘  │
└─────────────────────────────────────────┘
```

- Text input with autocomplete dropdown
- Existing tags shown as pills with × remove button
- Enter/click to add tag (creates if new)
- API endpoint: `POST /api/documents/:id/tags` and `DELETE /api/documents/:id/tags/:name`
- Same for tasks: `POST /api/tasks/:id/tags` and `DELETE /api/tasks/:id/tags/:name`

### API Endpoints for Tag Management

```ruby
# In api/documents routes:
resources :tags, only: [:create, :destroy], param: :name

# api/documents/:id/tags
class Api::DocumentTagsController < Api::BaseController
  def create
    tag = Tag.find_or_create_by!(name: params[:name].downcase.strip)
    @document.tags << tag unless @document.tags.include?(tag)
    render json: { tag: { name: tag.name, color: tag.color } }, status: :created
  end

  def destroy
    tag = Tag.find_by!(name: params[:name])
    @document.tags.delete(tag)
    head :no_content
  end
end
```

### Sidebar Navigation

Add "Tags" link to sidebar (between existing nav items):

```erb
<%= link_to tags_path, class: "sidebar-nav-link #{current_page?(tags_path) ? 'active' : ''}" do %>
  <%= heroicon(:tag, style: "width:18px;height:18px") %>
  <span>Tags</span>
<% end %>
```

### CSS

Reuse existing design system variables. New styles:

- `.tags-grid` — CSS grid for tag cards (similar to documents grid)
- `.tag-card` — Card with color dot, name, count
- `.tag-color-dot` — Small colored circle (8×8px)
- `.tag-input-wrapper` — Container for tag input component
- `.tag-pill` — Existing tag displayed as pill with remove button
- `.tag-autocomplete` — Dropdown for tag suggestions
