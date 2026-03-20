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
end
