module ApplicationHelper
  # Render a back-link with arrow_left icon.
  # Uses browser history when available, falls back to the href path.
  #   back_link(tasks_path, "Tasks")
  def back_link(path, label)
    link_to path, class: "back-link", onclick: "history.back(); return false;" do
      heroicon(:arrow_left, style: "width: 16px; height: 16px;") +
        content_tag(:span, label)
    end
  end

  # Render a Markdown string as safe HTML.
  # Supports: headings, bold, italic, code, tables, task lists, autolinks, strikethrough.
  #
  # Options:
  #   interactive_checkboxes: true  — checkboxes trigger markdown-editor#toggleCheckbox (default: false)
  def render_markdown(text, interactive_checkboxes: false)
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

    # Pre-process GFM task lists (Redcarpet doesn't support them natively).
    # Replace checkbox markers with safe text sentinels BEFORE Redcarpet rendering,
    # then swap them for HTML checkboxes AFTER rendering.
    # Preserve leading whitespace for nested list indentation.
    processed = text
      .gsub(/^(\s*)-\s*\[x\] /i, '\1- XCHKX ')
      .gsub(/^(\s*)-\s*\[ \] /,  '\1- OCHKO ')

    html = markdown.render(processed)

    if interactive_checkboxes
      checked_input   = '<input type="checkbox" checked data-action="change->markdown-editor#toggleCheckbox">'
      unchecked_input = '<input type="checkbox" data-action="change->markdown-editor#toggleCheckbox">'
    else
      checked_input   = '<input type="checkbox" checked disabled>'
      unchecked_input = '<input type="checkbox" disabled>'
    end

    # Replace sentinels with checkbox HTML.
    # Add task-list-item class to the parent <li> for flex layout.
    html = html
      .gsub("<li>XCHKX ") { "<li class=\"task-list-item\">#{checked_input} " }
      .gsub("<li>OCHKO ") { "<li class=\"task-list-item\">#{unchecked_input} " }

    html.html_safe
  end
end
