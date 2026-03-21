module WikiLinkRenderer
  WIKI_LINK_PATTERN = /\[\[([^\[\]]+)\]\]/

  WIKI_LINK_ICON = <<~SVG.squish.freeze
    <svg class="wiki-link-icon" xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 16 16" fill="currentColor"><path fill-rule="evenodd"
    d="M8.914 6.025a.75.75 0 0 1 1.06 0 3.5 3.5 0 0 1 0 4.95l-2 2a3.5
    3.5 0 0 1-4.95-4.95l1.25-1.25a.75.75 0 0 1 1.06 1.06l-1.25 1.25a2 2
    0 1 0 2.83 2.83l2-2a2 2 0 0 0 0-2.83.75.75 0 0 1 0-1.06Zm-1.06-.05a.75.75
    0 0 1-1.06 0 3.5 3.5 0 0 1 0-4.95l2-2a3.5 3.5 0 0 1 4.95 4.95l-1.25
    1.25a.75.75 0 0 1-1.06-1.06l1.25-1.25a2 2 0 1 0-2.83-2.83l-2 2a2 2 0 0
    0 0 2.83.75.75 0 0 1 0 1.06Z" clip-rule="evenodd"/></svg>
  SVG

  def render_wiki_links(html)
    return "" if html.nil?

    text = html.to_s
    titles = text.scan(WIKI_LINK_PATTERN).flatten.map(&:strip).uniq
    return text.html_safe if titles.empty?

    downcased = titles.map { |t| t.encode(Encoding::UTF_8).gsub(/[A-Z]/) { |c| c.downcase } }
    resolved = Document
      .where("title IN (?) OR LOWER(title) IN (?)", titles, downcased)
      .index_by { |d| d.title.downcase }

    text.gsub(WIKI_LINK_PATTERN) do
      title = ::Regexp.last_match(1).strip
      doc = resolved[title.downcase]

      if doc
        %(<a href="#{document_path(doc)}" class="wiki-link">#{WIKI_LINK_ICON}#{ERB::Util.html_escape(doc.title)}</a>)
      else
        %(<span class="wiki-link--broken">#{ERB::Util.html_escape(title)}</span>)
      end
    end.html_safe
  end
end
