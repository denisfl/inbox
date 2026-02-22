require 'rails_helper'

RSpec.describe 'Keyboard Shortcuts', type: :system, js: true do
  before do
    driven_by(:selenium_chrome_headless)
  end

  describe 'vim-like global shortcuts' do
    let!(:document) { create(:document, title: 'Test Document') }

    context 'on index page' do
      before { visit root_path }

      it 'g + n creates new note' do
        # Press 'g' then 'n' within 1 second
        find('body').send_keys('g')
        sleep 0.1
        find('body').send_keys('n')

        # Should redirect to /new
        expect(page).to have_current_path('/new')
      end

      it 'g + s opens search popup' do
        # Press 'g' then 's'
        find('body').send_keys('g')
        sleep 0.1
        find('body').send_keys('s')

        # Search popup should be visible
        expect(page).to have_selector('[data-search-target="popup"]', visible: true)
        
        # Search input should be focused
        expect(page).to have_selector('[data-search-target="input"]:focus')
      end

      it 'Escape closes search popup' do
        # Open search first
        find('body').send_keys('g')
        sleep 0.1
        find('body').send_keys('s')

        expect(page).to have_selector('[data-search-target="popup"]', visible: true)

        # Press Escape
        find('[data-search-target="input"]').send_keys(:escape)

        # Popup should be hidden
        expect(page).to have_selector('[data-search-target="popup"]', visible: false)
      end

      it 'sequence timeout resets after 1 second' do
        # Press 'g'
        find('body').send_keys('g')
        
        # Wait more than 1 second
        sleep 1.1
        
        # Press 'n' (should not trigger g+n)
        find('body').send_keys('n')

        # Should NOT redirect to /new
        expect(page).to have_current_path(root_path)
      end
    end

    context 'on edit page (contenteditable)' do
      before do
        visit edit_document_path(document)
        wait_for_editor_load
      end

      it 'g + n works even while editing' do
        # Focus on a block
        block = find('.block-content [contenteditable]', match: :first)
        block.click
        block.send_keys('Typing some text')

        # Press g + n (should still work)
        find('body').send_keys('g')
        sleep 0.1
        find('body').send_keys('n')

        # Should redirect to /new
        expect(page).to have_current_path('/new')
      end

      it 'g + s opens search while editing' do
        block = find('.block-content [contenteditable]', match: :first)
        block.click

        find('body').send_keys('g')
        sleep 0.1
        find('body').send_keys('s')

        expect(page).to have_selector('[data-search-target="popup"]', visible: true)
      end
    end

    context 'in form inputs' do
      before do
        # Create a page with an input field (search box)
        visit root_path
        find('body').send_keys('g')
        sleep 0.1
        find('body').send_keys('s')
      end

      it 'ignores shortcuts when typing in input' do
        input = find('[data-search-target="input"]')
        input.set('g')
        sleep 0.1
        input.send_keys('n')

        # Should stay in search input, not redirect
        expect(page).to have_current_path(root_path)
        expect(input.value).to eq('gn')
      end
    end
  end

  describe 'keyboard controller connection' do
    it 'logs connection in console' do
      visit root_path

      # Check console logs (if possible with Capybara)
      # This is tricky - might need JS execution to verify
      script = <<~JS
        return typeof window.Stimulus !== 'undefined' && 
               window.Stimulus.controllers.some(c => c.identifier === 'keyboard')
      JS

      controller_loaded = page.evaluate_script(script)
      expect(controller_loaded).to be true
    end
  end

  private

  def wait_for_editor_load
    # Wait for Stimulus controller to connect
    expect(page).to have_selector('[data-controller~="document-editor"]')
    sleep 0.5 # Give JS time to initialize
  end
end
