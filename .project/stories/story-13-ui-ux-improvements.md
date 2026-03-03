# Story 13: UI/UX Improvements & Progressive Web App

**Priority:** P1 (High)  
**Complexity:** High  
**Estimated Effort:** 3-4 days  
**Dependencies:** Story 11 (Whisper Transcription)  
**Status:** Phase 1 In Progress (80% complete)

---

## Design Philosophy: Basecamp-Inspired

### Core Principles
1. **Warm & Approachable** - Use warm color palette (tans, greens, yellows)
2. **Functional Over Fancy** - Clarity and usability first, decorations second
3. **Boxy & Grounded** - Less rounded corners, thicker borders, minimal shadows
4. **Content-Focused** - UI chrome supports content, doesn't compete with it
5. **❌ No Emojis** - Use Heroicons (SVG) for all icons

### Color Palette (Basecamp-style)
```css
/* Light Mode */
--color-primary: #D4A574;      /* Warm tan/beige */
--color-secondary: #70B77E;    /* Basecamp green */
--color-accent: #E5CC7B;       /* Warm yellow */
--color-danger: #D74E4E;       /* Muted red */

--color-bg-primary: #ffffff;
--color-bg-secondary: #FAF9F7;  /* Slightly warm white */
--color-text-primary: #292524;  /* Stone-800 */

/* Dark Mode */
--color-primary: #E5CC7B;      /* Bright yellow */
--color-bg-primary: #1C1917;   /* Stone-900 */
--color-bg-secondary: #292524; /* Stone-800 */
```

### Typography
- **Font:** Helvetica Neue, Helvetica, Arial (Basecamp uses Helvetica)
- **Line Height:** 1.6 (more generous spacing)

### Component Style
- **Borders:** 2-3px thick (visible separation)
- **Border Radius:** 4-8px max (less rounded, more boxy)
- **Shadows:** Minimal (0-0.08 opacity max)
- **Hover Effects:** No lift/transform, just shadow/border changes
- **Active States:** Solid color backgrounds (not subtle gray)

---

## User Story

As a user, I want a modern, intuitive, and mobile-friendly interface so that I can easily view, search, and manage my notes from any device.

---

## Current State Analysis

### ✅ Completed (Phase 1)
- ✅ Design system with CSS variables
- ✅ Dark mode with localStorage persistence
- ✅ Sidebar navigation with filters (Views: All, Telegram, Voice, Photos)
- ✅ Tags section in sidebar
- ✅ Header with search bar
- ✅ Enhanced document cards with previews
- ✅ Type badges (Telegram, Voice, Photo, File)
- ✅ Filtering system (source, type, tag)
- ✅ Sorting system (5 options: updated, created, title)
- ✅ Responsive layout (mobile/desktop)
- ✅ All emojis replaced with Heroicons
- ✅ Basecamp-inspired warm color palette
- ✅ Thicker borders, less rounded corners

### ❌ Remaining Work

**Phase 1 Final:**
- [ ] Manual testing in browser
- [ ] Accessibility audit (keyboard navigation, aria-labels)
- [ ] Check color contrast (AAA compliance)

**Phase 2:**
- [ ] Pagination (kaminari gem, 20 per page)
- [ ] Infinite scroll option
- [ ] PWA manifest
- [ ] Service Worker (offline support)
- [ ] Mobile bottom navigation
- [ ] Lazy loading for images

---

## Design Guidelines

### ❌ Don't Use Emojis
**Rule:** Never use emoji characters (📱, 🎤, 📷, etc.) in the UI

**Reason:**
- Inconsistent rendering across platforms
- Not themeable (can't change color with CSS)
- Accessibility issues (screen readers pronounce incorrectly)
- Not professional in production apps

**Solution:** Use Heroicons
```erb
<%# Bad %>
<span>📱 Telegram</span>

<%# Good %>
<%= heroicon(:device_phone_mobile, class: 'icon-sm') %> Telegram
```

**Available Icons:** document, clipboard, device_phone_mobile, microphone, camera, inbox, tag, moon, sun, magnifying_glass, bars_3

**Adding New Icons:**
1. Find icon at https://heroicons.com/
2. Copy SVG path data
3. Add to `HEROICONS` hash in `app/helpers/heroicons_helper.rb`
4. Use: `<%= heroicon(:new_icon_name) %>`

---

## Acceptance Criteria

### ✅ Visual Design Improvements

**1. Modern Design System:**
- [ ] Define color palette:
  ```css
  --primary: #2563eb;      /* Blue */
  --secondary: #10b981;    /* Green */
  --accent: #f59e0b;       /* Amber */
  --danger: #ef4444;       /* Red */
  --bg-primary: #ffffff;
  --bg-secondary: #f9fafb;
  --text-primary: #111827;
  --text-secondary: #6b7280;
  --border: #e5e7eb;
  ```
- [ ] Typography scale (Inter or system font)
- [ ] Spacing system (4px base unit)
- [ ] Shadow utilities
- [ ] Border radius consistency

**2. Dark Mode:**
- [ ] CSS variables for theme switching
- [ ] Toggle button in header
- [ ] Persist preference in localStorage
- [ ] Respect system preference (`prefers-color-scheme`)
- [ ] Smooth transition animations

**3. Enhanced Empty State:**
```html
<div class="empty-state">
  <svg><!-- Illustration --></svg>
  <h3>Welcome to Inbox!</h3>
  <p>Start capturing your thoughts via Telegram bot</p>
  <div class="empty-actions">
    <a href="https://t.me/your_bot_name" class="btn btn-primary">
      📱 Open Telegram Bot
    </a>
    <button class="btn btn-secondary">
      📖 View Tutorial
    </button>
  </div>
</div>
```

---

### ✅ Navigation & Filtering

**1. Sidebar Navigation:**
```html
<nav class="sidebar">
  <div class="nav-header">
    <h1>📥 Inbox</h1>
    <button class="new-note-btn">+ New</button>
  </div>
  
  <div class="nav-section">
    <h3>Views</h3>
    <a href="/" class="active">All Notes</a>
    <a href="/?source=telegram">From Telegram</a>
    <a href="/?type=voice">Voice Notes</a>
    <a href="/?type=photo">Photos</a>
  </div>
  
  <div class="nav-section">
    <h3>Tags</h3>
    <!-- Dynamic tag list -->
  </div>
  
  <div class="nav-section">
    <h3>Settings</h3>
    <button class="theme-toggle">🌙 Dark Mode</button>
    <a href="/settings">⚙️ Settings</a>
  </div>
</nav>
```

**2. Filters & Sorting:**
- [ ] Filter by source (Telegram, API)
- [ ] Filter by content type (text, voice, photo, document)
- [ ] Filter by tag
- [ ] Filter by date range
- [ ] Sort by: Created (newest/oldest), Updated, Title (A-Z)
- [ ] URL parameters for bookmarkable filters (`?source=telegram&sort=created_desc`)

**3. Search Enhancements:**
- [ ] Search autocomplete (recent searches)
- [ ] Search suggestions (tags, keywords)
- [ ] Search filters (in sidebar)
- [ ] Highlight search matches in results
- [ ] Search history (localStorage)

---

### ✅ Enhanced Document Cards

**1. Rich Previews:**
```html
<div class="document-card">
  <!-- Header -->
  <div class="card-header">
    <span class="source-badge">📱 Telegram</span>
    <span class="type-badge">🎤 Voice</span>
    <time>2 hours ago</time>
  </div>
  
  <!-- Title -->
  <h2 class="card-title">
    <a href="/documents/123">Привет, это тестовое сообщение...</a>
  </h2>
  
  <!-- Preview -->
  <div class="card-preview">
    <!-- For text: first 200 chars -->
    <!-- For voice: waveform icon + duration -->
    <!-- For photo: thumbnail -->
    <!-- For document: file icon + size -->
  </div>
  
  <!-- Meta -->
  <div class="card-meta">
    <span class="block-count">3 blocks</span>
    <div class="tags">
      <span class="tag">work</span>
      <span class="tag">ideas</span>
    </div>
  </div>
  
  <!-- Actions -->
  <div class="card-actions">
    <button class="btn-icon" title="Share">🔗</button>
    <button class="btn-icon" title="Archive">📦</button>
    <button class="btn-icon" title="Delete">🗑️</button>
  </div>
</div>
```

**2. Content Type Indicators:**
- [ ] Voice notes: 🎤 icon + waveform animation + duration
- [ ] Photos: Thumbnail (lazy-loaded)
- [ ] Documents: File icon + filename + size
- [ ] Text-only: First 200 characters preview

**3. Interactive Elements:**
- [ ] Hover effects (subtle scale/shadow)
- [ ] Click anywhere on card to open
- [ ] Swipe left for quick actions (mobile)
- [ ] Long-press for context menu (mobile)

---

### ✅ Mobile Optimizations

**1. Touch-Friendly:**
- [ ] Larger tap targets (min 44x44px)
- [ ] Bottom navigation bar (thumb-reachable)
- [ ] Floating action button (FAB) for new note
- [ ] Pull-to-refresh gesture
- [ ] Swipe gestures (delete, archive)

**2. Responsive Improvements:**
```css
/* Mobile first */
.document-card {
  padding: 16px;
  gap: 12px;
}

/* Tablet */
@media (min-width: 768px) {
  .container {
    display: grid;
    grid-template-columns: 240px 1fr;
  }
  .sidebar {
    display: block;
  }
}

/* Desktop */
@media (min-width: 1024px) {
  .documents-list {
    grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
  }
}
```

**3. Mobile-Specific Features:**
- [ ] Bottom sheet for filters/actions
- [ ] Sticky search bar
- [ ] Hide navbar on scroll down, show on scroll up
- [ ] Safe area insets (iPhone notch)

---

### ✅ Progressive Web App (PWA)

**1. Enable PWA Manifest:**
```json
// public/manifest.json
{
  "name": "Inbox - Block Notes",
  "short_name": "Inbox",
  "description": "Capture and organize your thoughts from Telegram",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#2563eb",
  "orientation": "portrait",
  "icons": [
    {
      "src": "/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    },
    {
      "src": "/icon-maskable-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable"
    }
  ]
}
```

**2. Service Worker:**
```javascript
// app/javascript/serviceworker.js
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open('inbox-v1').then((cache) => {
      return cache.addAll([
        '/',
        '/assets/application.css',
        '/assets/application.js'
      ]);
    })
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      return response || fetch(event.request);
    })
  );
});
```

**3. Install Prompt:**
- [ ] Detect if PWA is installable
- [ ] Show install banner (dismissible)
- [ ] Track install events (analytics)
- [ ] Update notification for new versions

**4. Offline Support:**
- [ ] Cache static assets
- [ ] Cache API responses (documents list)
- [ ] Show offline indicator
- [ ] Queue actions when offline (sync when back online)
- [ ] "Offline mode" badge

---

### ✅ Performance Optimizations

**1. Lazy Loading:**
```ruby
<!-- app/views/documents/index.html.erb -->
<%= image_tag block.image, loading: "lazy", class: "block-image" %>
```

**2. Infinite Scroll:**
- [ ] Load 20 documents initially
- [ ] Load more on scroll (Intersection Observer)
- [ ] Show loading spinner
- [ ] "Load More" button fallback

**3. Image Optimization:**
- [ ] ActiveStorage variants (thumbnails)
- [ ] WebP format with fallback
- [ ] Responsive images (`srcset`)
- [ ] Blur-up placeholder technique

**4. Turbo Frames:**
```ruby
<!-- Wrap search results in Turbo Frame -->
<turbo-frame id="search-results">
  <%= render @documents %>
</turbo-frame>
```

---

### ✅ Accessibility (A11y)

- [ ] ARIA labels for all interactive elements
- [ ] Keyboard navigation (Tab, Arrow keys)
- [ ] Focus indicators (visible outline)
- [ ] Screen reader support
- [ ] Color contrast AAA compliance
- [ ] Alt text for all images
- [ ] Skip to content link
- [ ] ARIA live regions for search results

---

### ✅ Additional Features

**1. Quick Actions:**
- [ ] Keyboard shortcuts (Cmd+K for search, Cmd+N for new)
- [ ] Bulk actions (select multiple, archive/delete)
- [ ] Context menu (right-click)

**2. Document Detail Page:**
- [ ] Breadcrumb navigation
- [ ] Block-by-block editing (contenteditable)
- [ ] Drag-and-drop reorder blocks
- [ ] Audio player for voice notes (with playback speed)
- [ ] Image lightbox/zoom
- [ ] Share button (copy link, export as markdown)

**3. Settings Page:**
- [ ] Theme preference
- [ ] Notification settings
- [ ] Export data (JSON, Markdown)
- [ ] Import from file
- [ ] Account settings (Telegram ID, API token)
- [ ] Privacy settings (auto-delete after X days)

**4. Animations:**
- [ ] Fade-in on page load
- [ ] Slide-in for search results
- [ ] Smooth page transitions (View Transitions API)
- [ ] Loading skeletons (instead of spinners)
- [ ] Micro-interactions (button hover, card expand)

---

## Design System Components

**Typography:**
```css
.text-xs { font-size: 0.75rem; }
.text-sm { font-size: 0.875rem; }
.text-base { font-size: 1rem; }
.text-lg { font-size: 1.125rem; }
.text-xl { font-size: 1.25rem; }
.text-2xl { font-size: 1.5rem; }
.text-3xl { font-size: 1.875rem; }
```

**Buttons:**
```css
.btn {
  padding: 0.5rem 1rem;
  border-radius: 0.375rem;
  font-weight: 500;
  transition: all 0.2s;
}

.btn-primary { background: var(--primary); color: white; }
.btn-secondary { background: var(--bg-secondary); color: var(--text-primary); }
.btn-icon { padding: 0.5rem; border-radius: 50%; }
```

**Cards:**
```css
.card {
  background: var(--bg-primary);
  border: 1px solid var(--border);
  border-radius: 0.5rem;
  padding: 1rem;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  transition: transform 0.2s, box-shadow 0.2s;
}

.card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}
```

---

## UI Mockups (ASCII)

### Document List (Desktop):
```
┌─────────────────────────────────────────────────────────────────┐
│  📥 Inbox                                      🌙  ⚙️  👤        │
├──────────┬──────────────────────────────────────────────────────┤
│          │  🔍 Search documents and blocks...         Filter ▼  │
│ All Notes│  ─────────────────────────────────────────────────   │
│ Telegram │  ┌──────────────────┐ ┌──────────────────┐          │
│ Voice    │  │ 📱 Telegram 🎤   │ │ 📱 Telegram 📷   │          │
│ Photos   │  │ 2 hours ago      │ │ 1 day ago        │          │
│          │  │                  │ │                  │          │
│ Tags     │  │ Привет, это...   │ │ [Photo Preview]  │          │
│ #work    │  │                  │ │                  │          │
│ #ideas   │  │ 3 blocks         │ │ 2 blocks         │          │
│          │  │ #voice #test     │ │ #photo           │          │
│ Settings │  └──────────────────┘ └──────────────────┘          │
│ 🌙 Dark  │                                                       │
│ ⚙️       │  Load More (18 remaining)                            │
└──────────┴──────────────────────────────────────────────────────┘
```

### Mobile View:
```
┌────────────────────┐
│ 📥 Inbox  🔍 ☰     │
├────────────────────┤
│ Search...          │
├────────────────────┤
│ ┌────────────────┐ │
│ │ 📱 Telegram 🎤 │ │
│ │ 2 hours ago    │ │
│ │                │ │
│ │ Привет, это... │ │
│ │                │ │
│ │ 3 blocks       │ │
│ └────────────────┘ │
│                    │
│ ┌────────────────┐ │
│ │ 📱 Telegram 📷 │ │
│ │ 1 day ago      │ │
│ │                │ │
│ │ [Photo]        │ │
│ │                │ │
│ │ 2 blocks       │ │
│ └────────────────┘ │
│                    │
│      + FAB         │
└────────────────────┘
```

---

## Testing Checklist

- [ ] Lighthouse score: Performance >90, Accessibility >95, Best Practices >90, SEO >90
- [ ] PWA installable on iOS/Android
- [ ] Dark mode works on all pages
- [ ] Keyboard navigation functional
- [ ] Screen reader announces changes
- [ ] Touch gestures work on mobile
- [ ] Offline mode shows appropriate UI
- [ ] Images lazy-load correctly
- [ ] Infinite scroll doesn't break back button
- [ ] All filters preserve state in URL
- [ ] Responsive on 320px width (smallest phones)

---

## Documentation Deliverables

- [ ] Design system guide (`docs/design-system.md`)
- [ ] Component library (Storybook or similar)
- [ ] PWA installation guide for users
- [ ] Accessibility testing report
- [ ] Browser compatibility matrix

---

## Success Criteria

✅ Lighthouse score >90 in all categories  
✅ PWA installable with offline support  
✅ Dark mode toggle functional  
✅ Mobile-first responsive design  
✅ Keyboard navigation complete  
✅ Search autocomplete working  
✅ Document cards show rich previews  
✅ Lazy loading images functional  
✅ Page load time <2s on 3G

---

## Notes

- Use Tailwind CSS or vanilla CSS (no heavy frameworks)
- Test on real Raspberry Pi 5 (performance matters)
- Consider ViewComponent for reusable UI elements
- Follow Material Design or Apple HIG guidelines
- Prioritize performance over fancy animations

---

## Future Enhancements (Not in Scope)

- Rich text editor (WYSIWYG)
- Collaboration features
- Real-time sync
- Desktop app (Electron)
- Browser extension
