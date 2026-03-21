# frozen_string_literal: true

# rake links:extract_all — run DocumentLinkExtractor on every document to build/rebuild the link graph

namespace :links do
  desc "Extract wiki-links from all documents and rebuild the link graph"
  task extract_all: :environment do
    total = Document.count
    puts "Extracting wiki-links from #{total} documents..."

    Document.find_each.with_index do |doc, index|
      DocumentLinkExtractor.new(doc).call
      print "." if ((index + 1) % 10).zero?
    end

    link_count = DocumentLink.count
    puts "\nDone. #{link_count} links extracted from #{total} documents."
  end
end
