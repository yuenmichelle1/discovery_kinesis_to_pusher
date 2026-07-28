# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/models/talk_comment'

RSpec.describe Models::TalkComment do
  subject(:comment) { described_class.new(event) }

  let(:event) { fixture('comment_payload') }

  it 'returns correct attributes' do
    expected_attributes = {
      id: event['data']['id'],
      project_id: event['data']['project_id'],
      board_id: event['data']['board_id'],
      focus_id: event['data']['focus_id'],
      focus_type: event['data']['focus_type'],
      user_id: event['data']['user_id'],
      body: event['data']['body'],
      created_at: event['data']['created_at'],
      url: event['data']['url']
    }

    expect(comment.attributes).to include(expected_attributes)
  end
end
