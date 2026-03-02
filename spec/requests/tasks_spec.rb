# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tasks", type: :request do
  describe "GET /tasks" do
    let!(:today_task) { create(:task, :due_today, title: "Today task") }
    let!(:overdue_task) { create(:task, :overdue, title: "Overdue task") }
    let!(:inbox_task) { create(:task, :inbox, title: "Inbox task") }
    let!(:completed_task) { create(:task, :completed, :due_today, title: "Completed task") }

    it "returns success" do
      get tasks_path

      expect(response).to have_http_status(:ok)
    end

    it "defaults to today filter" do
      get tasks_path

      expect(response.body).to include("Today task")
    end

    it "filters by upcoming" do
      upcoming_task = create(:task, :due_tomorrow, title: "Tomorrow task")

      get tasks_path(filter: "upcoming")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tomorrow task")
    end

    it "filters by inbox" do
      get tasks_path(filter: "inbox")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Inbox task")
    end

    it "filters by completed" do
      get tasks_path(filter: "completed")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Completed task")
    end

    it "filters by overdue" do
      get tasks_path(filter: "overdue")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Overdue task")
    end

    it "filters by tags" do
      tag = create(:tag, name: "urgent")
      create(:task_tag, task: today_task, tag: tag)

      get tasks_path(tags: ["urgent"])

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /tasks/new" do
    it "returns success" do
      get new_task_path

      expect(response).to have_http_status(:ok)
    end

    it "pre-fills due_date from params" do
      get new_task_path(due_date: "2026-04-01")

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /tasks" do
    it "creates a task with valid params" do
      expect {
        post tasks_path, params: { task: { title: "New task", priority: "mid" } }
      }.to change(Task, :count).by(1)

      expect(response).to redirect_to(tasks_path(filter: "inbox"))
    end

    it "renders new on invalid params" do
      post tasks_path, params: { task: { title: "", priority: "mid" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /tasks/:id/edit" do
    let(:task) { create(:task) }

    it "returns success" do
      get edit_task_path(task)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /tasks/:id" do
    let(:task) { create(:task, title: "Old title") }

    it "updates the task" do
      patch task_path(task), params: { task: { title: "New title" } }

      expect(response).to have_http_status(:redirect)
      expect(task.reload.title).to eq("New title")
    end

    it "renders edit on invalid params" do
      patch task_path(task), params: { task: { title: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /tasks/:id" do
    let!(:task) { create(:task) }

    it "deletes the task" do
      expect {
        delete task_path(task)
      }.to change(Task, :count).by(-1)

      expect(response).to redirect_to(tasks_path)
    end
  end

  describe "PATCH /tasks/:id/toggle" do
    let(:task) { create(:task) }

    it "toggles completion" do
      patch toggle_task_path(task)

      expect(task.reload.completed).to be true
    end

    it "responds with redirect for HTML" do
      patch toggle_task_path(task)

      expect(response).to have_http_status(:redirect)
    end
  end
end
