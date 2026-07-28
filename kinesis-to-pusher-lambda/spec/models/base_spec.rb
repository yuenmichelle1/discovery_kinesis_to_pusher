# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/models/base'

RSpec.describe Models::Base do
  subject(:model) { klass.new(event) }

  let(:klass) do
    Class.new(described_class) do
      def attributes
        { 'foo' => 'bar' }
      end
    end
  end

  let(:event) do
    {
      'source' => 'panoptes',
      'type' => 'classification',
      'timestamp' => '2024-01-01T12:34:56Z',
      'data' => {},
      'linked' => {}
    }
  end

  describe '#source' do
    it 'returns the event source' do
      expect(model.source).to eq('panoptes')
    end
  end

  describe '#type' do
    it 'returns the event type' do
      expect(model.type).to eq('classification')
    end
  end

  describe '#timestamp' do
    it 'parses the timestamp' do
      expect(model.timestamp).to eq(DateTime.parse('2024-01-01T12:34:56Z'))
    end

    context 'when the event has no timestamp' do
      before { event.delete('timestamp') }

      it 'returns nil' do
        expect(model.timestamp).to be_nil
      end
    end
  end

  describe '#id' do
    it 'returns the SHA1 digest of the attributes' do
      expect(model.id).to eq(
        Digest::SHA1.hexdigest(model.attributes.to_s)
      )
    end
  end

  describe '#attributes' do
    context 'on the base class' do
      let(:klass) { described_class }

      it 'returns an empty hash' do
        expect(model.attributes).to eq({})
      end
    end
  end

  describe '#event' do
    it 'exposes the original event' do
      expect(model.event).to eq(event)
    end
  end
end
