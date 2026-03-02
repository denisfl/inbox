# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Keyboard Shortcuts', type: :system, js: true do
  before do
    driven_by(:headless_chrome)
  end

  describe 'vim-like global shortcuts' do
    let!(:document) { create(:document, title: 'Test Document') }

    context 'on index page' do
      before { visit documents_path }

      it 'g + n creates new note' do
        find('body').send_keys('g')
        sleep 0.2
        find('body').send_keys('n')

        # /new creates a document and redirects to its edit page
        expect(page).to have_css('.simple-editor-container', wait: 5)
      end

      it 'sequence timeout resets after 1 second' do
        find('body').send_keys('g')

        sleep 1.2

        find('body').send_keys('n')

        # Should NOT redirect to /new
        expect(page).to have_current_path(documents_path)
      end
    end

    context 'on dashboard' do
      before { visit root_path }

      it 'g + n creates new note from dashboard' do
        find('body').send_keys('g')
        sleep 0.2
        find('body').send_keys('n')

        # /new creates a document and redirects to its edit page
        expect(page).to have_css('.simple-editor-container', wait: 5)
      end
    end
  end

  describe 'keyboard controller connection' do
    it 'keyboard controller is connected to body' do
      visit root_path

      expect(page).to have_css('body[data-controller~="keyboard"]')
    end
  end
end
