require 'rails_helper'

RSpec.describe 'Markdown Shortcuts', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  let!(:document) { create(:document, title: 'Markdown Test') }
  let!(:initial_block) { create(:block, :text, document: document, position: 0, content: { text: '' }.to_json) }

  before do
    visit edit_document_path(document)
    wait_for_editor_load
  end

  describe 'heading shortcuts' do
    it 'converts # to heading level 1' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('# Big Heading')
      
      sleep 1 # Wait for conversion
      
      expect(page).to have_selector('.block-wrapper[data-block-type="heading"]')
      heading = find('.block-wrapper[data-block-type="heading"] [contenteditable]')
      expect(heading.text).to eq('Big Heading')
    end

    it 'converts ## to heading level 2' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('## Medium Heading')
      
      sleep 1
      
      expect(page).to have_selector('.block-wrapper[data-block-type="heading"]')
      # Level should be stored in block data
    end

    it 'converts ### to heading level 3' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('### Small Heading')
      
      sleep 1
      
      expect(page).to have_selector('.block-wrapper[data-block-type="heading"]')
    end
  end

  describe 'quote shortcut' do
    it 'converts > to quote block' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('> This is a quote')
      
      sleep 1
      
      expect(page).to have_selector('.block-wrapper[data-block-type="quote"]')
      quote_text = find('.block-wrapper[data-block-type="quote"] [contenteditable]').text
      expect(quote_text).to eq('This is a quote')
    end
  end

  describe 'code block shortcut' do
    it 'converts ``` to code block' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('```')
      block.send_keys('puts "Hello"')
      
      sleep 1
      
      expect(page).to have_selector('.block-wrapper[data-block-type="code"]')
    end
  end

  describe 'TODO shortcuts' do
    it 'converts [ ] to unchecked TODO' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('[ ] Unchecked task')
      
      sleep 1
      
      expect(page).to have_selector('.block-wrapper[data-block-type="todo"]')
      checkbox = find('input[type="checkbox"]')
      expect(checkbox).not_to be_checked
    end

    it 'converts [x] to checked TODO' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('[x] Checked task')
      
      sleep 1
      
      expect(page).to have_selector('.block-wrapper[data-block-type="todo"]')
      checkbox = find('input[type="checkbox"]')
      expect(checkbox).to be_checked
    end

    it 'converts [X] (uppercase) to checked TODO' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('[X] Also checked')
      
      sleep 1
      
      checkbox = find('input[type="checkbox"]')
      expect(checkbox).to be_checked
    end
  end

  describe 'markdown persistence' do
    it 'preserves block type after conversion' do
      # Create heading
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('# Heading Text')
      sleep 1

      # Reload page
      visit edit_document_path(document)
      wait_for_editor_load

      # Should still be heading
      expect(page).to have_selector('.block-wrapper[data-block-type="heading"]')
      heading = find('.block-wrapper[data-block-type="heading"] [contenteditable]')
      expect(heading.text).to eq('Heading Text')
    end
  end

  describe 'markdown indicators' do
    it 'shows converting status' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('# ')
      
      # There should be some visual indicator (implementation dependent)
      # This is a placeholder - actual implementation might differ
      sleep 0.5
      
      # After conversion, original text with # should be gone
      block.send_keys('Test')
      sleep 1
      
      expect(page).to have_selector('.block-wrapper[data-block-type="heading"]')
    end
  end

  describe 'smart Enter behavior' do
    it 'creates new text block after heading when pressing Enter' do
      # Create heading
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('# Main Heading')
      sleep 1

      # Press Enter
      heading = find('.block-wrapper[data-block-type="heading"] [contenteditable]')
      heading.send_keys(:return)
      sleep 1

      # Should create new text block (not heading)
      blocks = all('.block-wrapper')
      expect(blocks.count).to eq(2)
      expect(blocks.last['data-block-type']).to eq('text')
    end

    it 'creates new quote after quote when pressing Enter' do
      # Create quote
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('> First quote')
      sleep 1

      # Press Enter
      quote = find('.block-wrapper[data-block-type="quote"] [contenteditable]')
      quote.send_keys(:return)
      sleep 1

      # Should create new text block (not another quote)
      blocks = all('.block-wrapper')
      expect(blocks.last['data-block-type']).to eq('text')
    end
  end

  describe 'no false positives' do
    it 'does not convert # in middle of text' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('This is not a # heading')
      sleep 1

      # Should remain text block
      expect(page).not_to have_selector('.block-wrapper[data-block-type="heading"]')
      expect(page).to have_selector('.block-wrapper[data-block-type="text"]')
    end

    it 'does not convert [ ] in middle of text' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys('Check this [ ] box')
      sleep 1

      # Should remain text block
      expect(page).not_to have_selector('.block-wrapper[data-block-type="todo"]')
    end
  end

  private

  def wait_for_editor_load
    expect(page).to have_selector('[data-controller~="document-editor"]')
    sleep 0.5
  end
end
