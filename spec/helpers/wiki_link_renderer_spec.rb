require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#render_wiki_links" do
    context "with resolved links" do
      let!(:target) { create(:document, title: "Meeting Notes") }

      it "replaces [[Title]] with an <a> tag" do
        html = "Check out [[Meeting Notes]] for details"
        result = helper.render_wiki_links(html)

        expect(result).to include('<a href="')
        expect(result).to include("Meeting Notes</a>")
        expect(result).to include('class="wiki-link"')
        expect(result).not_to include("[[")
      end

      it "links to the correct document path" do
        html = "See [[Meeting Notes]]"
        result = helper.render_wiki_links(html)

        expect(result).to include(document_path(target))
      end
    end

    context "with broken links" do
      it "replaces [[Title]] with a <span> tag for unresolved titles" do
        html = "See [[Nonexistent Note]]"
        result = helper.render_wiki_links(html)

        expect(result).to include('<span class="wiki-link--broken">')
        expect(result).to include("Nonexistent Note</span>")
        expect(result).not_to include("[[")
      end
    end

    context "with case-insensitive matching" do
      let!(:target) { create(:document, title: "Meeting Notes") }

      it "resolves case-insensitively" do
        html = "See [[meeting notes]]"
        result = helper.render_wiki_links(html)

        expect(result).to include('<a href="')
        expect(result).to include('class="wiki-link"')
      end
    end

    context "with multiple links" do
      let!(:doc_a) { create(:document, title: "Alpha") }
      let!(:doc_b) { create(:document, title: "Beta") }

      it "replaces all wiki-links" do
        html = "Links to [[Alpha]] and [[Beta]]"
        result = helper.render_wiki_links(html)

        expect(result).to include(document_path(doc_a))
        expect(result).to include(document_path(doc_b))
        expect(result).not_to include("[[")
      end
    end

    context "with mixed resolved and broken links" do
      let!(:target) { create(:document, title: "Real Doc") }

      it "renders resolved as links and broken as spans" do
        html = "See [[Real Doc]] and [[Ghost Doc]]"
        result = helper.render_wiki_links(html)

        expect(result).to include('<a href="')
        expect(result).to include('<span class="wiki-link--broken">')
      end
    end

    context "with no wiki-links" do
      it "returns the HTML unchanged" do
        html = "<p>No links here</p>"
        result = helper.render_wiki_links(html)

        expect(result).to eq(html)
      end
    end

    context "with nil input" do
      it "returns empty string" do
        expect(helper.render_wiki_links(nil)).to eq("")
      end
    end

    it "returns html_safe string" do
      html = "See [[Something]]"
      result = helper.render_wiki_links(html)

      expect(result).to be_html_safe
    end
  end
end
