# frozen_string_literal: true

require 'spec_helper'
require_relative '../lambda_function'

RSpec.describe '#lambda_handler' do
  subject(:invoke) { lambda_handler(event: event, context: nil) }

  before do
    allow(DYNAMODB).to receive(:put_item)
    allow(PUSHER).to receive(:trigger)
  end

  def fixture(name)
    JSON.parse(File.read("spec/fixtures/#{name}.json"))
  end

  def kinesis_event(payload)
    {
      'Records' => [
        {
          'kinesis' => {
            'data' => Base64.strict_encode64(JSON.dump(payload))
          }
        }
      ]
    }
  end

  describe 'when Models.for returns nil' do
    let(:event) do
      kinesis_event(
        'source' => 'unknown',
        'type' => 'unknown'
      )
    end

    it 'does not write or publish' do
      invoke

      expect(DYNAMODB).not_to have_received(:put_item)
      expect(PUSHER).not_to have_received(:trigger)
    end
  end

  describe 'for a Talk comment' do
    let(:payload) { fixture('comment_payload') }
    let(:event) { kinesis_event(payload) }

    it 'stores the unique key in DynamoDB' do
      invoke

      comment_id = payload['data']['id']

      expect(DYNAMODB).to have_received(:put_item).with(
        hash_including(
          table_name: DYNAMODB_TABLE,
          item: hash_including(
            'unique_key' => "talk-comment-#{comment_id}"
          ),
          condition_expression: 'attribute_not_exists(unique_key)'
        )
      )
    end

    it 'publishes the event to Pusher' do
      invoke

      expect(PUSHER).to have_received(:trigger).with(
        'talk',
        'comment',
        Models::TalkComment.new(payload).attributes
      )
    end
  end

  describe 'for a Panoptes classification' do
    let(:payload) { fixture('classification_payload') }
    let(:event) { kinesis_event(payload) }
    let(:attributes) { Models::PanoptesClassification.new(payload).attributes }

    it 'stores the unique key in DynamoDB' do
      invoke

      classification_id = payload['data']['id']

      expect(DYNAMODB).to have_received(:put_item).with(
        hash_including(
          table_name: DYNAMODB_TABLE,
          item: hash_including(
            'unique_key' => "panoptes-classification-#{classification_id}"
          ),
          condition_expression: 'attribute_not_exists(unique_key)'
        )
      )
    end

    it 'publishes to the project-specific channel' do
      invoke

      expect(PUSHER).to have_received(:trigger).with(
        "panoptes-project-#{attributes[:project_id]}",
        'classification',
        attributes
      )
    end
  end

  describe 'workflow counters event' do
    let(:payload) { fixture('workflow_counters_payload') }
    let(:event) { kinesis_event(payload) }
    let(:attributes) { Models::PanoptesWorkflowCounter.new(payload).attributes }

    let(:unique_id) do
      data = payload['data']
      "#{data['project_id']}-#{data['workflow_id']}-#{data['classifications_count']}"
    end

    it 'stores the expected unique key' do
      invoke

      expect(DYNAMODB).to have_received(:put_item).with(
        hash_including(
          item: hash_including(
            'unique_key' => "panoptes-workflow_counters-#{unique_id}"
          )
        )
      )
    end

    it 'publishes to the project-specific channel' do
      invoke

      expect(PUSHER).to have_received(:trigger).with(
        "panoptes-project-#{attributes[:project_id]}",
        'workflow_counters',
        attributes
      )
    end
  end

  describe 'when the event type is unsupported' do
    let(:event) do
      kinesis_event(
        'source' => 'talk',
        'type' => 'unknown'
      )
    end

    it 'does not write or publish' do
      invoke

      expect(DYNAMODB).not_to have_received(:put_item)
      expect(PUSHER).not_to have_received(:trigger)
    end
  end

  describe 'when DynamoDB reports a duplicate' do
    let(:payload) { fixture('comment_payload') }
    let(:event) { kinesis_event(payload) }

    before do
      allow(DYNAMODB).to receive(:put_item).and_raise(
        Aws::DynamoDB::Errors::ConditionalCheckFailedException.new(nil, 'duplicate')
      )
    end

    it 'does not publish to Pusher' do
      invoke

      expect(PUSHER).not_to have_received(:trigger)
    end
  end
end
