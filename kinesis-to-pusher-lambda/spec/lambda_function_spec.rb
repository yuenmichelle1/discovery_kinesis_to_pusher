# frozen_string_literal: true

# spec/lambda_spec.rb

require 'spec_helper'
require_relative '../lambda_function'

RSpec.describe '#lambda_handler' do
  subject(:invoke) { lambda_handler(event: event, context: nil) }

  let(:classification_payload) do
    JSON.parse(File.read('spec/fixtures/example_kinesis_classification_payload.json'))
  end

  let(:comment_payload) do
    JSON.parse(File.read('spec/fixtures/example_kinesis_comment_payload.json'))
  end

  before do
    allow(DYNAMODB).to receive(:put_item)
    allow(PUSHER).to receive(:trigger)
  end

  describe 'when Models.for returns nil' do
    let(:event) do
      {
        'Records' => [
          {
            'kinesis' => {
              'data' => Base64.encode64(JSON.dump({ 'source' => 'unknown', 'type' => 'unknown' }))
            }
          }
        ]
      }
    end

    it 'does nothing' do
      invoke

      expect(DYNAMODB).not_to have_received(:put_item)
      expect(PUSHER).not_to have_received(:trigger)
    end
  end

  describe 'for a Talk comment' do
    let(:event) do
      {
        'Records' => [
          {
            'kinesis' => {
              'data' => Base64.encode64(JSON.dump(comment_payload))
            }
          }
        ]
      }
    end

    it 'stores the unique key in DynamoDB' do
      invoke

      expect(DYNAMODB).to have_received(:put_item).with(
        hash_including(
          table_name: DYNAMODB_TABLE,
          item: hash_including(
            'unique_key' => 'talk-comment-1820'
          ),
          condition_expression: 'attribute_not_exists(unique_key)'
        )
      )
    end

    it 'publishes the event to Pusher' do
      invoke

      comment_attributes = Models::TalkComment.new(comment_payload).attributes
      expect(PUSHER).to have_received(:trigger).with(
        'talk',
        'comment',
        comment_attributes
      )
    end
  end

  describe 'for a Panoptes classification' do
    let(:event) do
      {
        'Records' => [
          {
            'kinesis' => {
              'data' => Base64.encode64(JSON.dump(classification_payload))
            }
          }
        ]
      }
    end

    it 'does not publish to the general panoptes channel' do
      invoke

      expect(PUSHER).not_to have_received(:trigger).with(
        'panoptes',
        'classification',
        anything
      )
    end

    it 'publishes to the project-specific channel' do
      invoke

      attributes = Models::PanoptesClassification.new(classification_payload).attributes
      project_specific_channel = "panoptes-project-#{attributes[:project_id]}"

      expect(PUSHER).to have_received(:trigger).with(
        project_specific_channel,
        'classification',
        attributes
      )
    end
  end

  describe 'for a workflow counters event' do
    let(:source) { 'panoptes' }
    let(:type) { 'workflow_counters' }

    let(:attributes) do
      {
        project_id: 1,
        workflow_id: 2,
        classifications_count: 3
      }
    end

    it 'uses the expected unique key' do
      invoke

      expect(DYNAMODB).to have_received(:put_item).with(
        hash_including(
          item: hash_including(
            'unique_key' => 'panoptes-workflow_counters-1-2-3'
          )
        )
      )
    end
  end

  describe 'when the event type is unsupported' do
    let(:type) { 'unknown' }

    it 'returns without writing to DynamoDB' do
      invoke

      expect(DYNAMODB).not_to have_received(:put_item)
      expect(PUSHER).not_to have_received(:trigger)
    end
  end

  describe 'when DynamoDB reports a duplicate' do
    before do
      allow(DYNAMODB).to receive(:put_item).and_raise(
        Aws::DynamoDB::Errors::ConditionalCheckFailedException.new(
          nil,
          'duplicate'
        )
      )
    end

    it 'does not publish to Pusher' do
      invoke

      expect(PUSHER).not_to have_received(:trigger)
    end
  end
end
