# Story 13: UI/UX Improvements - Lessons Learned

**Date:** 2026-02-22
**Status:** Phase 1 In Progress

---

## Critical Issue: Emoji Usage in UI

### ❌ Problem:

Using emojis (📥, 🎤, 📷, etc.) in Rails views causes rendering issues:

- Emojis display inconsistently across browsers/OS
- Mixed with inline CSS causes text to render as plain code on page
- Not screen-reader friendly
- Unprofessional appearance

### ✅ Solution:

**Use Heroicons (or similar SVG icon library) instead**

### Implementation:

1. Created `app/helpers/heroicons_helper.rb` with common icons
2. Replace all emoji usage:

   ```ruby
   # ❌ Bad:
   <span class="nav-icon">📥</span>

   # ✅ Good:
   <%= heroicon(:inbox, class: "nav-icon", style: "width: 1.25rem; height: 1.25rem;") %>
   ```

### Available Icons:

- `:inbox` — For inbox/documents
- `:clipboard` — For clipboard/notes
- `:device_phone_mobile` — For Telegram/mobile
- `:microphone` — For voice notes
- `:camera` — For photos
- `:document` — For generic documents
- `:tag` — For tags
- `:moon` / `:sun` — For theme toggle
- `:magnifying_glass` — For search
- `:bars_3` — For mobile menu

---

## Design System: Basecamp-Inspired

### Color Palette:

```css
:root {
  /* Primary colors (blue) */
  --color-primary: #2563eb;
  --color-primary-hover: #1d4ed8;

  /* Background (neutral) */
  --color-bg-primary: #ffffff;
  --color-bg-secondary: #f9fafb;
  --color-bg-tertiary: #f3f4f6;

  /* Text (gray scale) */
  --color-text-primary: #111827;
  --color-text-secondary: #6b7280;

  /* Borders (subtle) */
  --color-border: #e5e7eb;
}
```

### Typography:

- **Font**: System font stack (`-apple-system, BlinkMacSystemFont, ...`)
- **Sizes**: 12px (xs), 14px (sm), 16px (base), 18px (lg), 20px (xl), 24px (2xl)
- **Weights**: Normal (400), Medium (500), Semibold (600), Bold (700)

### Spacing System (4px base):

- `--spacing-xs`: 4px
- `--spacing-sm`: 8px
- `--spacing-md`: 16px
- `--spacing-lg`: 24px
- `--spacing-xl`: 32px

### Border Radius:

- `--radius-base`: 6px (buttons, inputs)
- `--radius-lg`: 12px (cards)
- `--radius-full`: 9999px (badges, pills)

---

## Common Patterns

### Card Component:

```erb
<article class="card">
  <div class="card-header">
    <span class="badge badge-secondary">
      <%= heroicon(:device_phone_mobile, style: "width: 1rem; height: 1rem; margin-right: 0.25rem;") %>
      Telegram
    </span>
    <time class="card-time">2 hours ago</time>
  </div>

  <h3 class="card-title">
    <%= link_to document.title, document_path(document) %>
  </h3>

  <p class="card-preview">
    <%= document.preview_text.truncate(150) %>
  </p>

  <div class="card-meta">
    <span class="meta-item">
      <%= heroicon(:clipboard, style: "width: 1rem; height: 1rem;") %>
      3 blocks
    </span>

    <div class="card-tags">
      <%= render document.tags.limit(3) %>
    </div>
  </div>
</article>
```

### Button Variants:

```erb
<%# Primary action %>
<button class="btn btn-primary">
  <%= heroicon(:plus, style: "width: 1.25rem; height: 1.25rem;") %>
  New Note
</button>

<%# Secondary action %>
<button class="btn btn-secondary">
  Cancel
</button>

<%# Ghost (subtle) %>
<button class="btn btn-ghost">
  <%= heroicon(:moon, style: "width: 1.25rem; height: 1.25rem;") %>
</button>
```

---

## Don'ts (Anti-Patterns)

### ❌ Don't use emojis in UI:

```ruby
# Bad:
<span>📥 Inbox</span>
<span>🎤 Voice Note</span>
```

### ❌ Don't use inline styles for layout:

```erb
# Bad:
<div style="display: flex; gap: 16px;">
  ...
</div>

# Good:
<div class="filters-bar">
  ...
</div>
```

### ❌ Don't duplicate CSS in views:

```erb
# Bad:
<style>
  .document-card { background: white; padding: 24px; }
</style>

# Good: Put in design_system.tailwind.css or component-specific file
```

### ❌ Don't hardcode colors:

```erb
# Bad:
<span style="color: #666;">Updated 2h ago</span>

# Good:
<span class="text-secondary">Updated 2h ago</span>
```

---

## File Structure

```
app/
├── assets/stylesheets/
│   ├── application.tailwind.css      # Main CSS file
│   └── design_system.tailwind.css    # Design system variables & components
├── helpers/
│   └── heroicons_helper.rb           # SVG icon helper
├── views/
│   ├── layouts/
│   │   ├── application.html.erb      # Main layout with theme controller
│   │   ├── _sidebar.html.erb         # Sidebar navigation
│   │   └── _header.html.erb          # Header with search
│   └── documents/
│       ├── index.html.erb            # Documents list page
│       └── _card.html.erb            # Document card partial
└── javascript/controllers/
    └── theme_controller.js           # Dark mode toggle
```

---

## Testing Checklist

### Before committing UI changes:

- [ ] No emojis in views (use Heroicons instead)
- [ ] No duplicate CSS in `<style>` tags
- [ ] All colors use CSS variables (no `#hex` in views)
- [ ] Dark mode tested (toggle 🌙 button works)
- [ ] Mobile responsive (test at 375px width)
- [ ] No console errors (check browser DevTools)
- [ ] Accessibility: `aria-label` on icon-only buttons
- [ ] Screen reader friendly (test with VoiceOver)

---

## Resources

- **Heroicons**: https://heroicons.com/ (MIT license, by Tailwind Labs)
- **Basecamp 3 UI**: Reference for clean, functional design
- **Tailwind CSS Variables**: Using CSS vars with Tailwind utilities

---

## Future Improvements (Phase 2)

- [ ] Add remaining Heroicons to helper (50+ icons)
- [ ] Consider switching to `heroicon` gem (https://github.com/bharget/heroicon)
- [ ] Extract component styles to separate files (`_card.css`, `_button.css`)
- [ ] Create Storybook for component documentation
- [ ] Add animation easing curves (for smooth hover effects)

---

**Last updated:** 2026-02-22
**Author:** Relief Pilot
