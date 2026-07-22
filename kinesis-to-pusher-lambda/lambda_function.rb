require 'json'
require 'pusher'
require 'base64'
require 'time'
require 'aws-sdk-dynamodb'
require 'geocoder'
require_relative 'lib/geo'
require_relative 'lib/models'


TTL_SECONDS = 60 * 60 * 24 # 24 hours

Geocoder.configure(ip_lookup: :geoip2, geoip2: {
    file: File.expand_path('./lib/data/GeoLite2-City.mmdb', __FILE__)
})

DYNAMODB = Aws::DynamoDB::Client.new

DYNAMODB_TABLE = ENV.fetch("DYNAMODB_TABLE_NAME")

PUSHER = Pusher::Client.new(
  app_id: ENV.fetch("PUSHER_APP_ID"),
  key: ENV.fetch("PUSHER_KEY"),
  secret: ENV.fetch("PUSHER_SECRET"),
  cluster: ENV.fetch("PUSHER_CLUSTER"),
  use_tls: true
)

def lambda_handler(event:, context:)
  event['Records'].each do |record|
    payload = JSON.parse(Base64.decode64(record['kinesis']['data']))

    model = Models.for(payload)
    next unless model

    unique_id = case [model.source, model.type]
            when ["panoptes", "classification"]
              model.attributes[:classification_id]
            when ["panoptes", "workflow_counters"]
              "#{model.attributes[:project_id]}-#{model.attributes[:workflow_id]}-#{model.attributes[:classifications_count]}"
            when ["talk", "comment"]
              model.attributes[:id]
            end

    return unless unique_id

    unique_key = "#{model.source}-#{model.type}-#{unique_id}"

    begin
      DYNAMODB.put_item(
        table_name: DYNAMODB_TABLE,
        item: {
          'unique_key' => unique_key,
          'ttl' => Time.now.to_i + TTL_SECONDS
        },
        condition_expression: 'attribute_not_exists(unique_key)'
      )

      # PUSHER.trigger(
      #   model.source,          
      #   model.type,
      #    model.attributes
      # )
      
      if model.source == "panoptes" && model.type == "classification"
        project_specific_channel = "panoptes-project-#{model.attributes[:project_id]}"
        PUSHER.trigger(
          project_specific_channel,  
          model.type,   
          model.attributes
        )
      end

    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      next
    end
  end
end
