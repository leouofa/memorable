# Memorable Seeds
puts "Seeding Memorable..."

Memory.destroy_all

m1 = Memory.create!(
  title: "User Profile & Context Preferences",
  pinned: true,
  pinned_position: 1,
  body: <<~MARKDOWN
    # Core User Context & Preferences

    - **User**: Senior Full-Stack Software Architect
    - **Primary Stack**: Ruby on Rails 8, Hotwire (Turbo 8 + Stimulus), PostgreSQL, Tailwind CSS v4
    - **Coding Style Guidelines**:
      - Prefer concise, idiomatic implementations.
      - Ensure comprehensive test coverage (unit, integration, and system).
      - Maintain clean separation of concerns and local-first data ownership.
      - Never compromise privacy or leak user memory context externally.
  MARKDOWN
)

m2 = Memory.create!(
  title: "API Conventions & Architecture Decisions",
  pinned: true,
  pinned_position: 2,
  body: <<~MARKDOWN
    # ADR: RESTful API & JSON Spec Guidelines

    ### Endpoints Convention:
    - Base path: `/api/v1`
    - Standard response payloads include pagination metadata:
      ```json
      {
        "memories": [...],
        "meta": { "limit": 50, "offset": 0, "total_count": 4 }
      }
      ```
    - Use Redcarpet GFM for server-side Markdown parsing.
    - ActiveStorage attachments served via direct download or inline redirects.
  MARKDOWN
)

m3 = Memory.create!(
  title: "Development Environment Setup Notes",
  pinned: false,
  body: <<~MARKDOWN
    # Local Dev Quickstart Checklist

    1. Verify Ruby version: `ruby -v` (>= 3.4.4)
    2. Ensure PostgreSQL service is active: `pg_isready`
    3. Run database migrations: `bin/rails db:prepare`
    4. Compile Tailwind styles and launch Puma: `bin/dev`
  MARKDOWN
)

m4 = Memory.create!(
  title: "Key Shortcuts & Productivity Bindings",
  pinned: false,
  body: <<~MARKDOWN
    # Essential Productivity Shortcuts

    | Shortcut | Action | Scope |
    | :--- | :--- | :--- |
    | `⌘ \\` / `Ctrl + \\` | Toggle Sidebar (Collapsed / Expanded) | Global |
    | `⌘ S` / `Ctrl + S` | Save Markdown in Editor | Edit / Split View |
    | `Click Nav Link` | Auto-close Sidebar Drawer | Mobile View (< 768px) |
  MARKDOWN
)

puts "Seeded #{Memory.count} memories (#{Memory.where(pinned: true).count} pinned) successfully!"
