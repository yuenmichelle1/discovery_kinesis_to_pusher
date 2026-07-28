# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/models/panoptes_workflow_counter'

RSpec.describe Models::PanoptesWorkflowCounter do
  subject(:counter) { described_class.new(event) }

  let(:event) { fixture('workflow_counters_payload') }

  it 'returns correct attributes' do
    expected_attributes = {
      project_id: event['data']['project_id'],
      workflow_id: event['data']['workflow_id'],
      subjects_count: event['data']['subjects_count'],
      retired_subjects_count: event['data']['retired_subjects_count'],
      classifications_count: event['data']['classifications_count']
    }

    expect(counter.attributes).to include(expected_attributes)
  end
end
