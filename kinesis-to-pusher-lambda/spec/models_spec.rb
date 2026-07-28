# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/models'

RSpec.describe Models do
  describe '.for' do
    subject(:model) { described_class.for(event) }

    let(:event) do
      {
        'source' => source,
        'type' => type,
        'foo' => 'bar'
      }
    end

    shared_examples 'returns the expected model' do |klass|
      it 'returns an instance of the model' do
        expect(model).to be_a(klass)
      end

      it 'passes the event to the constructor' do
        expect(klass).to receive(:new).with(event).and_call_original

        model
      end
    end

    context 'with a Panoptes classification' do
      let(:source) { 'panoptes' }
      let(:type) { 'classification' }

      include_examples 'returns the expected model', Models::PanoptesClassification
    end

    context 'with a Panoptes workflow counter' do
      let(:source) { 'panoptes' }
      let(:type) { 'workflow_counters' }

      include_examples 'returns the expected model', Models::PanoptesWorkflowCounter
    end

    context 'with a Talk comment' do
      let(:source) { 'talk' }
      let(:type) { 'comment' }

      include_examples 'returns the expected model', Models::TalkComment
    end

    context 'when the source is unknown' do
      let(:source) { 'unknown' }
      let(:type) { 'classification' }

      it { is_expected.to be_nil }
    end

    context 'when the type is unknown' do
      let(:source) { 'panoptes' }
      let(:type) { 'unknown' }

      it { is_expected.to be_nil }
    end
  end
end
