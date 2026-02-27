module ApplicationHelper
  # Include Pagy frontend
  include Pagy::Frontend

  # Render a Markdown string as safe HTML.
  # Supports: headings, bold, italic, code, tables, task lists, autolinks, strikethrough.
  # Interactive checkboxes: removes `disabled` from rendered <input type="checkbox"> so they can be toggled via JS.
  def render_markdown(text)
    return "".html_safe if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener noreferrer" }
    )
    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      lax_spacing: true,
      no_intra_emphasis: true,
      space_after_headers: false
    )

    html = markdown.render(text)

    # Make task-list checkboxes interactive (Redcarpet renders them as disabled)
    html = html.gsub(
      '<input type="checkbox" disabled="">',
      '<input type="checkbox" data-action="change->markdown-editor#toggleCheckbox">'
    ).gsub(
      '<input type="checkbox" disabled="" checked="">',
      '<input type="checkbox" checked data-action="change->markdown-editor#toggleCheckbox">'
    )

    html.html_safe
  end
end
