require 'rails_helper'

RSpec.describe Block, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:document) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:block_type) }
    # Position allows nil (set_default_position callback assigns it)
    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0).allow_nil }
    it { is_expected.to validate_inclusion_of(:block_type).in_array(Block::BLOCK_TYPES) }
  end

  describe 'scopes' do
    let(:document) { create(:document) }
    let!(:block_2) { create(:block, :text, document: document, position: 2) }
    let!(:block_1) { create(:block, :text, document: document, position: 1) }
    let!(:heading_block) { create(:block, :heading, document: document, position: 0) }
    let!(:code_block) { create(:block, :code, document: document, position: 3) }

    describe '.ordered' do
      it 'returns blocks ordered by position' do
        expect(Block.ordered).to eq([ heading_block, block_1, block_2, code_block ])
      end
    end

    describe '.by_type' do
      it 'filters blocks by type' do
        expect(Block.by_type('heading')).to contain_exactly(heading_block)
        expect(Block.by_type('text')).to contain_exactly(block_1, block_2)
      end
    end
  end

  describe 'callbacks' do
    context 'before_create :set_default_position' do
      let(:document) { create(:document) }

      context 'when position is not set' do
        it 'sets position to next available number' do
          create(:block, document: document, position: 0)
          create(:block, document: document, position: 1)

          new_block = build(:block, document: document, position: nil)
          new_block.save

          expect(new_block.position).to eq(2)
        end
      end

      context 'when position is explicitly set' do
        it 'does not override the position' do
          block = create(:block, document: document, position: 5)
          expect(block.position).to eq(5)
        end
      end
    end
  end

  describe '#content_hash' do
    context 'with valid JSON content' do
      let(:block) { create(:block, :text) }

      it 'parses content as hash' do
        expect(block.content_hash).to be_a(Hash)
        expect(block.content_hash).to have_key('text')
      end
    end

    context 'with invalid JSON content' do
      let(:block) { create(:block, content: 'invalid json') }

      it 'returns empty hash' do
        expect(block.content_hash).to eq({})
      end
    end

    context 'with nil content' do
      let(:block) { create(:block, content: nil) }

      it 'returns empty hash' do
        expect(block.content_hash).to eq({})
      end
    end
  end

  describe '#content_hash=' do
    let(:block) { create(:block) }
    let(:data) { { text: 'Test content', metadata: { important: true } } }

    it 'serializes hash to JSON' do
      block.content_hash = data
      expect(block.content).to eq(data.to_json)
    end
  end
end
