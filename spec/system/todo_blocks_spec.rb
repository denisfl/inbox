# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tasks Page', type: :system, js: true do
  before do
    driven_by(:headless_chrome)
  end

  describe 'viewing tasks' do
    let!(:task1) { create(:task, title: 'Buy groceries', due_date: Date.current) }
    let!(:task2) { create(:task, title: 'Write report', due_date: Date.current + 1.day) }
    let!(:completed_task) { create(:task, :completed, title: 'Done task') }

    it 'displays tasks on the page' do
      visit tasks_path(filter: 'all')

      expect(page).to have_content('Buy groceries')
      expect(page).to have_content('Write report')
    end

    it 'shows filter tabs' do
      visit tasks_path

      expect(page).to have_content('Today')
      expect(page).to have_content('Upcoming')
      expect(page).to have_content('Inbox')
      expect(page).to have_content('All')
      expect(page).to have_content('Completed')
    end

    it 'has New Task button' do
      visit tasks_path

      expect(page).to have_link('New Task')
    end

    it 'has quick add form' do
      visit tasks_path

      expect(page).to have_field(placeholder: 'Add task...')
    end
  end

  describe 'task toggle' do
    let!(:task) { create(:task, title: 'Toggle me', due_date: Date.current) }

    it 'shows task checkbox' do
      visit tasks_path(filter: 'today')

      expect(page).to have_css('.task-checkbox-btn')
    end
  end

  describe 'navigation' do
    it 'navigates to new task page' do
      visit tasks_path

      click_link 'New Task'

      expect(page).to have_current_path(new_task_path)
    end
  end

  describe 'empty state' do
    it 'shows empty state when no tasks exist' do
      Task.destroy_all
      visit tasks_path(filter: 'today')

      expect(page).to have_content('No tasks for today')
    end
  end
end
