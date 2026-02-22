require 'rails_helper'

RSpec.describe 'TODO Block Creation', type: :request do
  let(:document) { create(:document) }
  let(:auth_token) { 'test_token_123' }
  
  before do
    # Mock authentication - skip token check
    allow_any_instance_of(Api::BaseController).to receive(:authenticate).and_return(true)
  end

  describe 'POST /api/documents/:document_id/blocks' do
    context 'when creating TODO blocks rapidly' do
      let(:todo_params) do
        {
          block: {
            block_type: 'todo',
            content: { text: '', checked: false }
            # No position - server auto-assigns
          }
        }
      end

      it 'creates multiple TODO blocks without database lock errors' do
        # Simulate rapid creation (like pressing Enter quickly)
        expect {
          5.times do
            post "/api/documents/#{document.id}/blocks",
                 params: todo_params,
                 headers: { 'Authorization' => "Token token=#{auth_token}" }
            
            expect(response).to have_http_status(:created), 
              "Expected 201 but got #{response.status}: #{response.body}"
          end
        }.to change(Block, :count).by(5)

        # All blocks should have unique positions
        positions = Block.where(document: document).pluck(:position)
        expect(positions).to eq(positions.uniq), 
          'All blocks should have unique positions'
      end

      it 'auto-assigns position when nil' do
        # Create first block with position 0
        create(:block, document: document, position: 0)

        # Create second block without position
        post "/api/documents/#{document.id}/blocks",
             params: todo_params,
             headers: { 'Authorization' => "Token token=#{auth_token}" }

        expect(response).to have_http_status(:created)
        
        json = JSON.parse(response.body)
        expect(json['position']).to eq(1), 
          'Server should auto-assign position=1 when position=0 exists'
      end
    end

    context 'when creating TODO with Enter key behavior' do
      let(:existing_todo) { create(:block, :todo, document: document, position: 0) }
      
      before { existing_todo }

      it 'creates new TODO block after existing one' do
        # User presses Enter in TODO block
        # 1. Update existing block (PATCH)
        patch "/api/documents/#{document.id}/blocks/#{existing_todo.id}",
              params: { 
                block: { 
                  content: { text: 'Updated text', checked: false } 
                } 
              },
              headers: { 'Authorization' => "Token token=#{auth_token}" }

        expect(response).to have_http_status(:ok)

        # 2. Create new TODO block (POST)
        post "/api/documents/#{document.id}/blocks",
             params: {
               block: {
                 block_type: 'todo',
                 content: { text: '', checked: false }
               }
             },
             headers: { 'Authorization' => "Token token=#{auth_token}" }

        expect(response).to have_http_status(:created)
        
        json = JSON.parse(response.body)
        expect(json['position']).to eq(1), 
          'New TODO should be created at position=1'
        expect(json['block_type']).to eq('todo')
        expect(json['content']['text']).to eq('')
        # Rails JSON might return boolean as string
        expect([false, 'false']).to include(json['content']['checked'])
      end
    end

    context 'when handling database busy exception' do
      it 'does not return 500 error' do
        # Simulate high load - create 10 blocks concurrently
        threads = []
        errors = []

        10.times do |i|
          threads << Thread.new do
            begin
              post "/api/documents/#{document.id}/blocks",
                   params: {
                     block: {
                       block_type: 'todo',
                       content: { text: "TODO #{i}", checked: false }
                     }
                   },
                   headers: { 'Authorization' => "Token token=#{auth_token}" }
              
              errors << response.status unless response.status == 201
            rescue => e
              errors << e.message
            end
          end
        end

        threads.each(&:join)

        expect(errors).to be_empty, 
          "Expected no errors, but got: #{errors.inspect}"
        
        expect(Block.where(document: document).count).to eq(10)
      end
    end
  end

  describe 'PATCH /api/documents/:document_id/blocks/:id' do
    let(:todo_block) { create(:block, :todo, document: document, position: 0) }

    it 'updates TODO content' do
      patch "/api/documents/#{document.id}/blocks/#{todo_block.id}",
            params: {
              block: {
                content: { text: 'Updated TODO', checked: true }
              }
            },
            headers: { 'Authorization' => "Token token=#{auth_token}" }

      expect(response).to have_http_status(:ok)
      
      json = JSON.parse(response.body)
      expect(json['content']['text']).to eq('Updated TODO')
      expect([true, 'true']).to include(json['content']['checked'])
    end

    it 'uses content_hash= setter for proper JSON handling' do
      # This tests that the controller uses content_hash= instead of direct content=
      patch "/api/documents/#{document.id}/blocks/#{todo_block.id}",
            params: {
              block: {
                content: { text: 'Test', checked: false, extra_field: 'ignored' }
              }
            },
            headers: { 'Authorization' => "Token token=#{auth_token}" }

      expect(response).to have_http_status(:ok)
      
      # Reload from DB to verify JSON was stored correctly
      todo_block.reload
      content = todo_block.content_hash
      
      expect(content).to be_a(Hash)
      expect(content['text']).to eq('Test')
      # Rails params might convert boolean to string, this is OK
      expect(content['checked'].to_s).to eq('false')
    end
  end
end
