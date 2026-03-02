# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Markdown Preview', type: :system, js: true do
  before do
    driven_by(:headless_chrome)
  end

  let!(:document) { create(:document, title: 'Markdown Test') }
  let!(:text_block) do
    create(:block, :text, document: document, position: 0,
           content: { text: "# Heading\n\nSome **bold** text and *italic* text.\n\n- list item 1\n- list item 2" }.to_json)
  end

  describe 'textarea editing' do
    before do
      visit edit_document_path(document)
    end

    it 'displays markdown source in textarea' do
      textarea = find('.simple-editor-textarea')
      expect(textarea.value).to include('# Heading')
      expect(textarea.value).to include('**bold**')
    end

    it 'allows typing in textarea' do
      textarea = find('.simple-editor-textarea')
      textarea.fill_in with: 'New markdown content'

      expect(textarea.value).to eq('New markdown content')
    end

    it 'has monospace font class on textarea' do
      expect(page).to have_css('textarea.simple-editor-textarea')
    end

    it 'shows placeholder when empty' do
      # Create document without text block
      empty_doc = create(:document, title: 'Empty Doc')
      create(:block, :text, document: empty_doc, position: 0,
             content: { text: '' }.to_json)

      visit edit_document_path(empty_doc)

      textarea = find('.simple-editor-textarea')
      expect(textarea['placeholder']).to eq('Write in Markdown…')
    end
  end

  describe 'preview toggle with markdown content' do
    before do
      visit edit_document_path(document)
    end

    it 'switches between edit and preview modes' do
      # Start in edit mode — textarea visible
      expect(page).to have_css('.simple-editor-textarea:not(.hidden)')

      # Click Preview
      click_button 'Preview'

      # Preview should be visible, textarea hidden
      expect(page).to have_css('.simple-editor-preview:not(.hidden)', wait: 5)
      expect(page).to have_button('Edit')

      # Click Edit to go back
      click_button 'Edit'

      # Textarea visible again
      expect(page).to have_css('.simple-editor-textarea:not(.hidden)', wait: 5)
      expect(page).to have_button('Preview')
    end
  end

  describe 'editor UI elements' do
    before do
      visit edit_document_path(document)
    end

    it 'has image upload button' do
      expect(page).to have_css('.simple-editor-upload-btn[title="Attach images"]')
    end

    it 'has file upload button' do
      expect(page).to have_css('.simple-editor-upload-btn[title="Attach files"]')
    end

    it 'has save indicator element' do
      expect(page).to have_css('[data-simple-editor-target="saveIndicator"]')
    end
  end
end
