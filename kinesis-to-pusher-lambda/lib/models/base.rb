# frozen_string_literal: true

module Models
  class Base
    def initialize(event)
      @event = event
    end

    attr_reader :event

    def id
      Digest::SHA1.hexdigest(attributes.to_s)
    end

    def source
      event.fetch('source')
    end

    def type
      event.fetch('type')
    end

    def timestamp
      return unless event['timestamp']

      DateTime.parse(event['timestamp'])
    end

    def attributes
      {}
    end

    private

    def data
      event['data']
    end

    def links
      data['links']
    end

    def linked
      event['linked']
    end
  end
end
