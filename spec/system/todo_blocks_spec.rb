require 'rails_helper'

RSpec.describe 'TODO Blocks', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  let!(:document) { create(:document, title: 'TODO Test Document') }
  let!(:initial_block) { create(:block, :text, document: document, position: 0, content: { text: 'Initial block' }.to_json) }

  before do
    visit edit_document_path(document)
    wait_for_editor_load
  end

  describe 'creating TODO blocks' do
    it 'creates TODO with markdown shortcut [ ] ' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys(:control, 'a') # Select all
      block.send_keys('[ ] New TODO')

      # Should convert to TODO block
      sleep 1 # Wait for conversion
      expect(page).to have_selector('.block-wrapper[data-block-type="todo"]')
      
      checkbox = find('input[type="checkbox"]')
      expect(checkbox).not_to be_checked
    end

    it 'creates checked TODO with [x] shortcut' do
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys(:control, 'a')
      block.send_keys('[x] Completed TODO')

      sleep 1
      expect(page).to have_selector('.block-wrapper[data-block-type="todo"]')
      
      checkbox = find('input[type="checkbox"]')
      expect(checkbox).to be_checked
    end

    it 'creates new TODO with Enter key' do
      # First create a TODO
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys(:control, 'a')
      block.send_keys('[ ] First TODO')
      sleep 1

      # Now press Enter to create second TODO
      todo_span = find('.block-wrapper[data-block-type="todo"] span[contenteditable]')
      todo_span.click
      todo_span.send_keys(:return)

      # Should create a new empty TODO block
      sleep 1
      todos = all('.block-wrapper[data-block-type="todo"]')
      expect(todos.count).to eq(2)
      
      # Second TODO should be empty
      second_todo = todos.last.find('span[contenteditable]')
      expect(second_todo.text).to be_empty
    end

    it 'creates multiple TODOs rapidly without errors' do
      # Create initial TODO
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys(:control, 'a')
      block.send_keys('[ ] First')
      sleep 1

      # Rapidly press Enter 5 times
      todo_span = find('.block-wrapper[data-block-type="todo"] span[contenteditable]', match: :first)
      todo_span.click
      
      5.times do
        todo_span.send_keys(:return)
        sleep 0.1 # Very short delay to simulate rapid typing
      end

      # Wait for all requests to complete
      sleep 2

      # Should have 6 TODO blocks total (1 initial + 5 new)
      todos = all('.block-wrapper[data-block-type="todo"]')
      expect(todos.count).to eq(6), "Expected 6 TODOs but got #{todos.count}"

      # No JavaScript errors
      errors = page.driver.browser.logs.get(:browser)
                 .select { |log| log.level == 'SEVERE' }
                 .map(&:message)
      
      expect(errors).to be_empty, "JavaScript errors: #{errors.join("\n")}"
    end
  end

  describe 'TODO interactions' do
    let!(:todo_block) do
      create(:block, :todo, 
             document: document, 
             position: 1,
             content: { text: 'Test TODO', checked: false }.to_json)
    end

    before do
      visit edit_document_path(document)
      wait_for_editor_load
    end

    it 'toggles TODO checkbox' do
      checkbox = find('.block-wrapper[data-block-type="todo"] input[type="checkbox"]')
      
      expect(checkbox).not_to be_checked
      
      checkbox.click
      sleep 0.5 # Wait for AJAX save
      
      expect(checkbox).to be_checked
      
      # Verify saved to server
      todo_block.reload
      expect(todo_block.content_hash['checked']).to be true
    end

    it 'updates TODO text' do
      todo_span = find('.block-wrapper[data-block-type="todo"] span[contenteditable]')
      todo_span.click
      todo_span.send_keys(' - updated')
      
      sleep 1 # Wait for debounced autosave
      
      # Verify saved
      todo_block.reload
      expect(todo_block.content_hash['text']).to include('updated')
    end

    it 'focuses new TODO after Enter' do
      todo_span = find('.block-wrapper[data-block-type="todo"] span[contenteditable]')
      todo_span.click
      todo_span.send_keys(:return)
      
      sleep 1
      
      # Active element should be the new TODO span
      active_element = page.evaluate_script('document.activeElement.tagName')
      expect(active_element).to eq('SPAN')
      
      active_contenteditable = page.evaluate_script(
        'document.activeElement.hasAttribute("contenteditable")'
      )
      expect(active_contenteditable).to be true
    end
  end

  describe 'TODO deletion' do
    let!(:todo_block) do
      create(:block, :todo,
             document: document,
             position: 1,
             content: { text: 'Delete me', checked: false }.to_json)
    end

    before do
      visit edit_document_path(document)
      wait_for_editor_load
    end

    it 'deletes TODO block' do
      todo_wrapper = find('.block-wrapper[data-block-type="todo"]')
      delete_button = todo_wrapper.find('.block-delete', visible: false)
      
      # Hover to show delete button
      todo_wrapper.hover
      
      # Click delete (need to confirm)
      accept_confirm { delete_button.click }
      
      sleep 0.5
      
      expect(page).not_to have_selector('.block-wrapper[data-block-type="todo"]')
    end
  end

  describe 'TODO persistence across page reload' do
    it 'saves TODO state and restores after reload' do
      # Create TODO
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys(:control, 'a')
      block.send_keys('[ ] Persistent TODO')
      sleep 1

      # Check it
      checkbox = find('input[type="checkbox"]')
      checkbox.click
      sleep 1 # Wait for save

      # Reload page
      visit edit_document_path(document)
      wait_for_editor_load

      # Should still be checked
      reloaded_checkbox = find('input[type="checkbox"]')
      expect(reloaded_checkbox).to be_checked
      
      todo_text = find('.block-wrapper[data-block-type="todo"] span[contenteditable]').text
      expect(todo_text).to eq('Persistent TODO')
    end
  end

  describe 'TODO with empty text' do
    it 'allows creating TODO with empty text' do
      # This tests the fix for race condition where empty TODOs caused issues
      block = find('.block-content [contenteditable]', match: :first)
      block.click
      block.send_keys(:control, 'a')
      block.send_keys('[ ] ')
      sleep 1

      # Press Enter immediately (empty text)
      todo_span = find('.block-wrapper[data-block-type="todo"] span[contenteditable]')
      todo_span.click
      todo_span.send_keys(:return)
      
      sleep 1
      
      # Should create new empty TODO without error
      todos = all('.block-wrapper[data-block-type="todo"]')
      expect(todos.count).to eq(2)
    end
  end

  private

  def wait_for_editor_load
    expect(page).to have_selector('[data-controller~="document-editor"]')
    sleep 0.5
  end
end
