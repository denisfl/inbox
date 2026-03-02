# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Document Editor', type: :system, js: true do
  before do
    driven_by(:headless_chrome)
  end

  let(:document) { create(:document, title: 'Test Document') }
  let!(:text_block) do
    create(:block, document: document, block_type: 'text',
           content: { text: 'Initial text content' }.to_json, position: 0)
  end

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

    it 'navigates to document editor on click' do
      visit documents_path

      click_link 'Test Document'

      expect(page).to have_current_path(edit_document_path(document))
    end
  end

  describe 'simple editor' do
    before do
      visit edit_document_path(document)
    end

    it 'displays document title' do
      expect(page).to have_css('h1.simple-editor-title', text: 'Test Document')
    end

    it 'displays text content in textarea' do
      textarea = find('.simple-editor-textarea')
      expect(textarea.value).to eq('Initial text content')
    end

    it 'has Back link' do
      expect(page).to have_link('Back')
    end

    it 'has Preview button' do
      expect(page).to have_button('Preview')
    end

    it 'has delete button' do
      expect(page).to have_css('.simple-editor-delete-btn')
    end

    it 'connects simple-editor Stimulus controller' do
      expect(page).to have_css('[data-controller~="simple-editor"]')
    end
  end

  describe 'title editing' do
    before do
      visit edit_document_path(document)
    end

    it 'has contenteditable title' do
      title = find('h1.simple-editor-title')
      expect(title['contenteditable']).to eq('true')
    end
  end

  describe 'preview toggle' do
    before do
      visit edit_document_path(document)
    end

    it 'toggles to preview mode' do
      click_button 'Preview'

      expect(page).to have_css('.simple-editor-preview:not(.hidden)', wait: 5)
      expect(page).to have_button('Edit')
    end

    it 'toggles back to edit mode' do
      click_button 'Preview'
      expect(page).to have_button('Edit', wait: 5)

      click_button 'Edit'

      expect(page).to have_css('.simple-editor-textarea:not(.hidden)', wait: 5)
      expect(page).to have_button('Preview')
    end
  end

  describe 'auto-save functionality' do
    before do
      visit edit_document_path(document)
    end

    it 'shows save indicator after editing' do
      textarea = find('.simple-editor-textarea')
      textarea.fill_in with: 'Updated text content'

      # Should show save indicator (saving or saved)
      expect(page).to have_css('.save-indicator', text: /sav/i, wait: 5)
    end
  end

  describe 'navigation' do
    it 'Back link returns to documents list' do
      visit edit_document_path(document)

      click_link 'Back'

      expect(page).to have_current_path(documents_path)
    end
  end

  describe 'tags section' do
    before do
      visit edit_document_path(document)
    end

    it 'shows tag input' do
      expect(page).to have_css('[data-controller~="tag-input"]')
      expect(page).to have_field(placeholder: 'Add tag…')
    end
  end
end
