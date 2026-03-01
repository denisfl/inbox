# frozen_string_literal: true

class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string  :title,           null: false
      t.text    :description
      t.date    :due_date
      t.time    :due_time
      t.string  :priority,        null: false, default: "mid"
      t.boolean :completed,       null: false, default: false
      t.datetime :completed_at
      t.integer :position,        null: false, default: 0
      t.string  :recurrence_rule
      t.references :document,     foreign_key: true

      t.timestamps
    end

    add_index :tasks, [:completed, :due_date]
    add_index :tasks, [:completed, :priority, :position]
    add_index :tasks, :due_date
  end
end
