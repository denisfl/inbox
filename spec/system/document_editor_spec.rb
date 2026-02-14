# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Document Editor', type: :system do
  before do
    driven_by(:selenium, using: :headless_chrome, screen_size: [1400, 1400])
  end

  let(:document) { create(:document, title: 'Test Document') }
  let!(:text_block) { create(:block, document: document, block_type: 'text', content: { text: 'Initial text' }, position: 0) }

  describe 'viewing the documents list' do
    let!(:document2) { create(:document, title: 'Another Document') }

    it 'displays all documents' do
      visit documents_path

      expect(page).to have_content('Test Document')
      expect(page).to have_content('Another Document')
    end

    it 'shows empty state when no documents exist' do
      Document.destroy_all

      visit documents_path

      expect(page).to have_content('No documents yet')
    end
  end

  describe 'editing a document' do
    before do
      visit edit_document_path(document)
    end

    it 'displays document title and blocks' do
      expect(page).to have_content('Test Document')
      expect(page).to have_content('Initial text')
    end

    it 'allows editing block content inline', js: true do
      text_element = find('.text-block[contenteditable="true"]', text: 'Initial text')
      text_element.click
      text_element.set('Updated text content')

      # Trigger blur to save
      find('body').click

      # Wait for save indicator
      expect(page).to have_content('Saved', wait: 5)

      # Verify block was updated
      text_block.reload
      expect(text_block.content['text']).to eq('Updated text content')
    end

    it 'adds a new block with keyboard shortcut', js: true do
      blocks_container = find('[data-document-editor-target="blocksContainer"]')
      initial_count = blocks_container.all('.block-wrapper').count

      # Send Cmd+Enter (Meta+Enter on Mac)
      find('body').send_keys [:meta, :enter]

      # Wait for new block to appear
      expect(blocks_container).to have_css('.block-wrapper', count: initial_count + 1, wait: 5)

      # Verify new block is text type
      expect(blocks_container).to have_css('.text-block', count: 2)
    end

    it 'deletes a block with delete button', js: true do
      accept_confirm do
        find('.block-delete').click
      end

      # Block should disappear
      expect(page).not_to have_content('Initial text')

      # Verify block was deleted
      expect(document.blocks.count).to eq(0)
    end

    it 'deletes a block with keyboard shortcut', js: true do
      # Focus on the block
      find('.text-block[contenteditable="true"]').click

      accept_confirm do
        find('body').send_keys [:meta, :backspace]
      end

      # Block should disappear
      expect(page).not_to have_content('Initial text')
    end
  end

  describe 'working with different block types', js: true do
    before do
      visit edit_document_path(document)
    end

    it 'creates and edits heading block' do
      create(:block, document: document, block_type: 'heading', content: { text: 'Heading Text', level: 2 }, position: 1)

      visit edit_document_path(document)

      expect(page).to have_css('h2.heading-block', text: 'Heading Text')
    end

    it 'creates and toggles todo block' do
      create(:block, document: document, block_type: 'todo', content: { text: 'Todo item', checked: false }, position: 1)

      visit edit_document_path(document)

      checkbox = find('.todo-block input[type="checkbox"]')
      expect(checkbox).not_to be_checked

      checkbox.click

      # Wait for save
      expect(page).to have_content('Saved', wait: 5)
    end

    it 'creates code block' do
      create(:block, document: document, block_type: 'code', content: { code: 'puts "Hello"', language: 'ruby' }, position: 1)

      visit edit_document_path(document)

      expect(page).to have_css('.code-block code', text: 'puts "Hello"')
    end

    it 'creates quote block' do
      create(:block, document: document, block_type: 'quote', content: { text: 'Famous quote' }, position: 1)

      visit edit_document_path(document)

      expect(page).to have_css('.quote-block', text: 'Famous quote')
    end

    it 'creates link block' do
      create(:block, document: document, block_type: 'link', content: { url: 'https://example.com', title: 'Example' }, position: 1)

      visit edit_document_path(document)

      expect(page).to have_css('.link-block input[value="https://example.com"]')
    end
  end

  describe 'auto-save functionality', js: true do
    before do
      visit edit_document_path(document)
    end

    it 'shows saving indicator when editing' do
      text_element = find('.text-block[contenteditable="true"]', text: 'Initial text')
      text_element.click
      text_element.set('New text')

      # Should show "Saving..." indicator
      expect(page).to have_css('[data-document-editor-target="saveIndicator"]', text: /Saving/, wait: 2)
    end

    it 'shows saved indicator after save completes' do
      text_element = find('.text-block[contenteditable="true"]', text: 'Initial text')
      text_element.click
      text_element.set('New text')

      find('body').click # Blur to trigger save

      # Should show "✓ Saved" indicator
      expect(page).to have_content('Saved', wait: 5)
    end
  end

  describe 'responsive design' do
    it 'displays properly on mobile viewport' do
      resize_window_to(390, 844) # iPhone 14 Pro

      visit edit_document_path(document)

      expect(page).to have_content('Test Document')
      expect(page).to have_css('.block-wrapper')
    end
  end
end
