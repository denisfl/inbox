# frozen_string_literal: true

require "rails_helper"

RSpec.describe Task, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:document).optional }
    it { is_expected.to have_many(:task_tags).dependent(:destroy) }
    it { is_expected.to have_many(:tags).through(:task_tags) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_inclusion_of(:priority).in_array(%w[pinned high mid low]) }

    it "allows nil recurrence_rule" do
      task = build(:task, recurrence_rule: nil)
      expect(task).to be_valid
    end

    it "allows valid recurrence_rule values" do
      %w[daily weekly monthly yearly].each do |rule|
        task = build(:task, recurrence_rule: rule)
        expect(task).to be_valid
      end
    end

    it "rejects invalid recurrence_rule values" do
      task = build(:task, recurrence_rule: "biweekly")
      expect(task).not_to be_valid
    end

    it "normalizes blank recurrence_rule to nil" do
      task = create(:task, recurrence_rule: "")
      expect(task.recurrence_rule).to be_nil
    end
  end

  describe "scopes" do
    describe ".active" do
      let!(:active_task) { create(:task, completed: false) }
      let!(:completed_task) { create(:task, :completed) }

      it "returns only incomplete tasks" do
        expect(Task.active).to include(active_task)
        expect(Task.active).not_to include(completed_task)
      end
    end

    describe ".completed" do
      let!(:active_task) { create(:task, completed: false) }
      let!(:completed_task) { create(:task, :completed) }

      it "returns only completed tasks" do
        expect(Task.completed).to include(completed_task)
        expect(Task.completed).not_to include(active_task)
      end
    end

    describe ".pinned" do
      let!(:pinned_task) { create(:task, :pinned) }
      let!(:regular_task) { create(:task, priority: "mid") }

      it "returns only pinned tasks" do
        expect(Task.pinned).to include(pinned_task)
        expect(Task.pinned).not_to include(regular_task)
      end
    end

    describe ".today" do
      let!(:today_task) { create(:task, :due_today) }
      let!(:pinned_task) { create(:task, :pinned) }
      let!(:tomorrow_task) { create(:task, :due_tomorrow) }
      let!(:completed_today) { create(:task, :completed, due_date: Date.current) }

      it "returns active tasks due today and pinned tasks" do
        expect(Task.today).to include(today_task, pinned_task)
        expect(Task.today).not_to include(tomorrow_task)
        expect(Task.today).not_to include(completed_today)
      end
    end

    describe ".upcoming" do
      let!(:upcoming_task) { create(:task, :due_tomorrow) }
      let!(:today_task) { create(:task, :due_today) }
      let!(:completed_upcoming) { create(:task, :completed, due_date: Date.current + 1.day) }

      it "returns active tasks due after today" do
        expect(Task.upcoming).to include(upcoming_task)
        expect(Task.upcoming).not_to include(today_task)
        expect(Task.upcoming).not_to include(completed_upcoming)
      end
    end

    describe ".inbox" do
      let!(:inbox_task) { create(:task, :inbox) }
      let!(:pinned_no_date) { create(:task, :pinned, due_date: nil) }
      let!(:dated_task) { create(:task, :due_today) }

      it "returns active tasks with no due_date and not pinned" do
        expect(Task.inbox).to include(inbox_task)
        expect(Task.inbox).not_to include(pinned_no_date)
        expect(Task.inbox).not_to include(dated_task)
      end
    end

    describe ".overdue" do
      let!(:overdue_task) { create(:task, :overdue) }
      let!(:today_task) { create(:task, :due_today) }
      let!(:completed_overdue) { create(:task, :completed, due_date: Date.current - 2.days) }

      it "returns active tasks with due_date in the past" do
        expect(Task.overdue).to include(overdue_task)
        expect(Task.overdue).not_to include(today_task)
        expect(Task.overdue).not_to include(completed_overdue)
      end
    end

    describe ".tagged_with" do
      let!(:tag1) { create(:tag, name: "work") }
      let!(:tag2) { create(:tag, name: "urgent") }
      let!(:task_both) { create(:task) }
      let!(:task_one) { create(:task) }
      let!(:task_none) { create(:task) }

      before do
        create(:task_tag, task: task_both, tag: tag1)
        create(:task_tag, task: task_both, tag: tag2)
        create(:task_tag, task: task_one, tag: tag1)
      end

      it "returns tasks matching ALL specified tags (AND logic)" do
        result = Task.tagged_with(%w[work urgent])
        expect(result).to include(task_both)
        expect(result).not_to include(task_one)
        expect(result).not_to include(task_none)
      end

      it "returns tasks with a single tag" do
        result = Task.tagged_with(%w[work])
        expect(result).to include(task_both, task_one)
        expect(result).not_to include(task_none)
      end

      it "returns all tasks when tag_names is blank" do
        expect(Task.tagged_with([])).to match_array(Task.all)
      end
    end

    describe ".in_date_range" do
      let!(:in_range) { create(:task, due_date: 3.days.from_now.to_date) }
      let!(:out_of_range) { create(:task, due_date: 30.days.from_now.to_date) }
      let!(:completed_in_range) { create(:task, :completed, due_date: 3.days.from_now.to_date) }

      it "returns active tasks within the date range" do
        result = Task.in_date_range(2.days.from_now.to_date, 5.days.from_now.to_date)
        expect(result).to include(in_range)
        expect(result).not_to include(out_of_range)
        expect(result).not_to include(completed_in_range)
      end
    end

    describe ".ordered" do
      let!(:low_task) { create(:task, priority: "low", position: 0) }
      let!(:high_task) { create(:task, priority: "high", position: 0) }
      let!(:pinned_task) { create(:task, :pinned, position: 0) }
      let!(:mid_task) { create(:task, priority: "mid", position: 0) }

      it "orders by priority (pinned > high > mid > low) then position" do
        result = Task.ordered.to_a
        expect(result.first).to eq(pinned_task)
        expect(result.second).to eq(high_task)
      end
    end
  end

  describe "instance methods" do
    describe "#complete!" do
      let(:task) { create(:task) }

      it "marks the task as completed with a timestamp" do
        task.complete!
        expect(task.completed).to be true
        expect(task.completed_at).to be_present
      end

      context "with recurrence" do
        let!(:task) { create(:task, :recurring_daily) }

        it "spawns a new task with the next due date" do
          expect { task.complete! }.to change(Task, :count).by(1)
          new_task = Task.last
          expect(new_task.due_date).to eq(task.due_date + 1.day)
          expect(new_task.title).to eq(task.title)
          expect(new_task.recurrence_rule).to eq("daily")
          expect(new_task.completed).to be false
        end
      end

      context "with weekly recurrence" do
        let(:task) { create(:task, :recurring_weekly) }

        it "spawns a new task 1 week later" do
          task.complete!
          new_task = Task.where.not(id: task.id).last
          expect(new_task.due_date).to eq(task.due_date + 1.week)
        end
      end

      context "with monthly recurrence" do
        let(:task) { create(:task, :recurring_monthly) }

        it "spawns a new task 1 month later" do
          task.complete!
          new_task = Task.where.not(id: task.id).last
          expect(new_task.due_date).to eq(task.due_date + 1.month)
        end
      end

      context "with yearly recurrence" do
        let(:task) { create(:task, :recurring_yearly) }

        it "spawns a new task 1 year later" do
          task.complete!
          new_task = Task.where.not(id: task.id).last
          expect(new_task.due_date).to eq(task.due_date + 1.year)
        end
      end

      context "recurring without due_date" do
        let!(:task) { create(:task, recurrence_rule: "daily", due_date: nil) }

        it "does not spawn a new task" do
          expect { task.complete! }.not_to change(Task, :count)
        end
      end
    end

    describe "#uncomplete!" do
      let(:task) { create(:task, :completed) }

      it "marks the task as not completed" do
        task.uncomplete!
        expect(task.completed).to be false
        expect(task.completed_at).to be_nil
      end
    end

    describe "#toggle!" do
      it "completes an active task" do
        task = create(:task)
        task.toggle!
        expect(task.completed).to be true
      end

      it "uncompletes a completed task" do
        task = create(:task, :completed)
        task.toggle!
        expect(task.completed).to be false
      end
    end

    describe "#overdue?" do
      it "returns true when due_date is in the past and not completed" do
        task = build(:task, :overdue)
        expect(task.overdue?).to be true
      end

      it "returns false when completed" do
        task = build(:task, :completed, due_date: Date.current - 2.days)
        expect(task.overdue?).to be false
      end

      it "returns false when due_date is today" do
        task = build(:task, :due_today)
        expect(task.overdue?).to be false
      end

      it "returns false when due_date is nil" do
        task = build(:task, due_date: nil)
        expect(task.overdue?).to be false
      end
    end

    describe "#due_today?" do
      it "returns true when due_date is today" do
        task = build(:task, :due_today)
        expect(task.due_today?).to be true
      end

      it "returns false when due_date is not today" do
        task = build(:task, :due_tomorrow)
        expect(task.due_today?).to be false
      end
    end

    describe "#recurring?" do
      it "returns true when recurrence_rule is set" do
        task = build(:task, :recurring_daily)
        expect(task.recurring?).to be true
      end

      it "returns false when recurrence_rule is nil" do
        task = build(:task, recurrence_rule: nil)
        expect(task.recurring?).to be false
      end
    end
  end
end
