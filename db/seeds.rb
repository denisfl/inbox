# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

return if Rails.env.production?

puts "Seeding development data..."

# ── Tags ────────────────────────────────────────────────────────────────────
tags = {}
[
  { name: "project",  color: "#3b82f6" },
  { name: "idea",     color: "#8b5cf6" },
  { name: "learning", color: "#10b981" },
  { name: "health",   color: "#ef4444" },
  { name: "finance",  color: "#f59e0b" },
  { name: "travel",   color: "#06b6d4" },
  { name: "recipe",   color: "#f97316" },
  { name: "book",     color: "#6366f1" },
  { name: "work",     color: "#64748b" }
].each do |attrs|
  tags[attrs[:name]] = Tag.find_or_create_by!(name: attrs[:name]) do |t|
    t.color = attrs[:color]
  end
end
puts "  Tags: #{Tag.count}"

# ── Documents ───────────────────────────────────────────────────────────────
documents_data = [
  {
    title: "Weekly meal prep plan",
    content: "## Sunday prep\n\n- Roast chicken + vegetables\n- Cook rice in bulk\n- Prep salad containers\n- Make overnight oats for Mon–Wed\n\n## Shopping list\n\n- Chicken thighs (1 kg)\n- Sweet potatoes\n- Broccoli, spinach\n- Greek yogurt\n- Rolled oats\n- Mixed berries",
    source: "telegram",
    document_type: "note",
    tags: %w[recipe health],
    pinned: true,
    created_at: 3.days.ago
  },
  {
    title: "Raspberry Pi home server setup notes",
    content: "## Hardware\n\nRaspberry Pi 5, 8 GB RAM, 256 GB NVMe via HAT.\n\n## Software stack\n\n- Docker Compose for orchestration\n- WireGuard VPN tunnel to cloud VPS\n- nginx reverse proxy with Let's Encrypt\n- SQLite for the database\n\n## Performance\n\n- Idle CPU: ~3%\n- RAM usage: ~1.2 GB with all containers\n- Cold boot to healthy: ~90 seconds\n\n## Lessons learned\n\n1. Always use `docker compose up -d` with health checks\n2. SQLite WAL mode is essential for concurrent reads\n3. pnpm is significantly faster than npm on ARM",
    source: "web",
    document_type: "note",
    tags: %w[project learning],
    pinned: true,
    created_at: 1.week.ago
  },
  {
    title: "Voice note: Book recommendation from podcast",
    content: "Heard about \"Designing Data-Intensive Applications\" by Martin Kleppmann on the podcast today. Everyone says it's the best book for understanding distributed systems, consensus algorithms, and database internals. Should buy it this week.",
    source: "telegram",
    document_type: "note",
    tags: %w[book idea],
    created_at: 2.days.ago
  },
  {
    title: "Investment portfolio review Q3",
    content: "## Current allocation\n\n| Asset | % | Target |\n|-------|---|--------|\n| Index funds | 60% | 60% |\n| Bonds | 25% | 25% |\n| Cash | 15% | 15% |\n\n## Actions\n\n- Rebalance bond allocation (slightly over)\n- Review expense ratios on ETFs\n- Set up automatic monthly contribution\n\n## Notes\n\n- Market volatility is normal, stay the course\n- Dollar-cost averaging working well",
    source: "web",
    document_type: "note",
    tags: %w[finance],
    created_at: 5.days.ago
  },
  {
    title: "Trip planning: Iceland in September",
    content: "## Route (Ring Road, 10 days)\n\n1. Reykjavik → Golden Circle (2 days)\n2. South Coast → Vik (2 days)\n3. Glacier lagoon → East fjords (2 days)\n4. North → Akureyri (2 days)\n5. Snæfellsnes → Reykjavik (2 days)\n\n## Budget estimate\n\n- Flights: ~$800\n- Campervan rental: ~$1500\n- Fuel: ~$300\n- Food: ~$500\n- Activities: ~$400\n\n**Total: ~$3500**\n\n## Must-see\n\n- Northern lights (if lucky!)\n- Jökulsárlón glacier lagoon\n- Seljalandsfoss waterfall\n- Whale watching in Húsavík",
    source: "telegram",
    document_type: "note",
    tags: %w[travel],
    pinned: false,
    created_at: 4.days.ago
  },
  {
    title: "Docker Compose tips",
    content: "## Useful commands\n\n```bash\n# Rebuild without cache\ndocker compose build --no-cache\n\n# View logs for specific service\ndocker compose logs web --tail=50 -f\n\n# Execute command in running container\ndocker compose exec web rails console\n\n# Resource usage\ndocker stats --no-stream\n```\n\n## Best practices\n\n- Always use health checks\n- Pin image versions\n- Use `.env` files for secrets\n- Separate dev and prod configs",
    source: "web",
    document_type: "note",
    tags: %w[project learning],
    created_at: 6.days.ago
  },
  {
    title: "Morning routine experiment",
    content: "Trying a new morning routine for 30 days:\n\n1. Wake up at 6:30\n2. No phone for first 30 min\n3. 10 min meditation (Headspace)\n4. 20 min exercise (bodyweight)\n5. Cold shower\n6. Journaling (5 min)\n7. Breakfast + coffee\n\n**Day 7 update:** Feeling more focused. The no-phone rule is the hardest part but makes the biggest difference. Cold shower is actually growing on me.",
    source: "telegram",
    document_type: "note",
    tags: %w[health idea],
    created_at: 1.day.ago
  },
  {
    title: "API design notes",
    content: "## RESTful conventions\n\n- Use nouns, not verbs: `/documents` not `/getDocuments`\n- Plural resources: `/tasks` not `/task`\n- Nested only when relationship is strong: `/documents/:id/tags`\n- Use HTTP status codes correctly (201 for create, 204 for delete)\n\n## Pagination\n\n- Offset-based for simple UIs\n- Cursor-based for infinite scroll\n- Always return total count in response headers",
    source: "web",
    document_type: "note",
    tags: %w[learning work],
    created_at: 8.days.ago
  }
]

documents_data.each do |attrs|
  tag_names = attrs.delete(:tags)
  doc = Document.find_or_create_by!(title: attrs[:title]) do |d|
    d.assign_attributes(attrs.except(:tags))
  end
  tag_names&.each do |name|
    doc.tags << tags[name] unless doc.tags.include?(tags[name])
  end

  # Create a text block with the content
  if doc.blocks.empty? && doc.content.present?
    doc.blocks.create!(
      block_type: "text",
      content: { "text" => doc.content }.to_json,
      position: 0
    )
  end
end
puts "  Documents: #{Document.count}"

# ── Tasks ───────────────────────────────────────────────────────────────────
tasks_data = [
  { title: "Buy groceries for meal prep",     due_date: Date.current,             priority: "high",   tags: %w[health] },
  { title: "Review pull request #42",         due_date: Date.current,             priority: "high",   tags: %w[work] },
  { title: "Book dentist appointment",        due_date: 3.days.from_now.to_date,  priority: "mid",    tags: %w[health] },
  { title: "Read DDIA chapter 5",             due_date: 5.days.from_now.to_date,  priority: "mid",    tags: %w[book learning] },
  { title: "Backup Raspberry Pi SD card",     due_date: 7.days.from_now.to_date,  priority: "low",    tags: %w[project] },
  { title: "Send birthday card to Mom",       due_date: Date.current + 10,        priority: "high",   tags: [] },
  { title: "Research Iceland campervan rentals", due_date: 14.days.from_now.to_date, priority: "mid", tags: %w[travel] },
  { title: "Update resume",                   due_date: nil,                       priority: "low",    tags: %w[work] },
  { title: "Try sourdough bread recipe",      due_date: nil,                       priority: "low",    tags: %w[recipe idea] },
  { title: "Set up automated backups",        due_date: 2.days.from_now.to_date,  priority: "mid",    tags: %w[project] },
  { title: "Morning meditation — daily",      due_date: Date.current,             priority: "pinned", tags: %w[health], recurrence_rule: "daily" },
  # Completed tasks
  { title: "Set up CI pipeline",              due_date: 3.days.ago.to_date,       priority: "high",   tags: %w[project work], completed: true, completed_at: 2.days.ago },
  { title: "Fix Pagy migration",             due_date: 2.days.ago.to_date,       priority: "high",   tags: %w[project], completed: true, completed_at: 1.day.ago }
]

tasks_data.each do |attrs|
  tag_names = attrs.delete(:tags)
  Task.find_or_create_by!(title: attrs[:title]) do |t|
    t.assign_attributes(attrs)
  end.tap do |task|
    tag_names&.each do |name|
      task.tags << tags[name] unless task.tags.include?(tags[name])
    end
  end
end
puts "  Tasks: #{Task.count} (#{Task.active.count} active, #{Task.completed.count} completed)"

# ── Calendar Events ─────────────────────────────────────────────────────────
events_data = [
  { title: "Team standup",          starts_at: Time.current.change(hour: 10, min: 0),  ends_at: Time.current.change(hour: 10, min: 15), color: "9",  tags: %w[work] },
  { title: "Lunch with Alex",       starts_at: Time.current.change(hour: 12, min: 30), ends_at: Time.current.change(hour: 13, min: 30), color: "5",  tags: [] },
  { title: "Code review session",   starts_at: (Date.current + 1).to_time.change(hour: 14),      ends_at: (Date.current + 1).to_time.change(hour: 15),     color: "9",  tags: %w[work project] },
  { title: "Dentist appointment",   starts_at: (Date.current + 3).to_time.change(hour: 9, min: 30), ends_at: (Date.current + 3).to_time.change(hour: 10, min: 30), color: "4",  tags: %w[health] },
  { title: "Flight to Reykjavik",   starts_at: (Date.current + 60).to_time.change(hour: 7),      ends_at: (Date.current + 60).to_time.change(hour: 12),     color: "7",  all_day: false, tags: %w[travel] },
  { title: "Iceland trip",          starts_at: (Date.current + 60).to_time,                       ends_at: (Date.current + 70).to_time,                      color: "2",  all_day: true, tags: %w[travel] },
  { title: "Project deadline",      starts_at: (Date.current + 14).to_time.change(hour: 17),     ends_at: (Date.current + 14).to_time.change(hour: 18),    color: "11", tags: %w[work project] }
]

events_data.each do |attrs|
  tag_names = attrs.delete(:tags)
  CalendarEvent.find_or_create_by!(title: attrs[:title], starts_at: attrs[:starts_at]) do |e|
    e.assign_attributes(attrs.merge(
      source: "manual",
      status: "confirmed",
      google_event_id: nil
    ))
  end.tap do |event|
    tag_names&.each do |name|
      event.tags << tags[name] unless event.tags.include?(tags[name])
    end
  end
end
puts "  Calendar events: #{CalendarEvent.count}"

puts "\nSeed data loaded!"
puts "   Documents: #{Document.count} | Tasks: #{Task.count} | Events: #{CalendarEvent.count} | Tags: #{Tag.count}"
