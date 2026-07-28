# frozen_string_literal: true

# spec/spec_helper.rb

require 'rspec'

ENV['DYNAMODB_TABLE_NAME'] = 'test-table'
ENV['PUSHER_APP_ID'] = 'app-id'
ENV['PUSHER_KEY'] = 'key'
ENV['PUSHER_SECRET'] = 'secret'
ENV['PUSHER_CLUSTER'] = 'us2'

require 'aws-sdk-dynamodb'
require 'pusher'

Aws.config.update(
  stub_responses: true,
  region: 'us-east-1'
)

# spec/spec_helper.rb
RSpec.configure do |config|
  config.before(:each) do
    pusher = instance_double(Pusher::Client)
    allow(Pusher::Client).to receive(:new).and_return(pusher)
  end
end
