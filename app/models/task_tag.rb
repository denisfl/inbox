# frozen_string_literal: true

class TaskTag < ApplicationRecord
  belongs_to :task
  belongs_to :tag

  validates :task_id, uniqueness: { scope: :tag_id }
end
