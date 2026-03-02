# frozen_string_literal: true

RSpec.shared_context "telegram_stub" do
  before do
    stub_request(:post, /api\.telegram\.org/)
      .to_return(status: 200, body: '{"ok":true,"result":{"message_id":1}}', headers: { "Content-Type" => "application/json" })
  end
end
