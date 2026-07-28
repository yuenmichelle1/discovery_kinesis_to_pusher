# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/models/panoptes_classification'

RSpec.describe Models::PanoptesClassification do
  subject(:classification) { described_class.new(event) }

  let(:event) { fixture('classification_payload') }

  it 'returns the id' do
    expect(classification.id).to eq(event['data']['id'])
  end

  it 'returns updated_at as timestamp' do
    expect(classification.timestamp).to eq(DateTime.parse(event['data']['updated_at']))
  end

  describe '#subject_urls' do
    it 'returns the subject urls for the subjects in the links' do
      expected_subject_urls = event['linked']['subjects'].flat_map { |subject| subject['locations'] }

      expect(classification.subject_urls).to eq(expected_subject_urls)
    end

    context 'when no linked subjects are present' do
      before { event['linked'].delete('subjects') }

      it 'returns an empty array' do
        expect(classification.subject_urls).to eq([])
      end
    end
  end

  describe '#attributes' do
    it 'returns a hash of attributes' do
      expected_attributes = {
        classification_id: event['data']['id'],
        project_id: event['data']['links']['project'],
        workflow_id: event['data']['links']['workflow'],
        user_id: event['data']['links']['user'],
        subject_ids: event['data']['links']['subjects'],
        subject_urls: classification.subject_urls,
        geo: instance_of(Hash)
      }

      expect(classification.attributes).to include(expected_attributes)
    end
  end
end
