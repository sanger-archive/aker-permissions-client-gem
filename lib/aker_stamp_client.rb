require "aker_stamp_client/version"
require "json_api_client"
require "pry"

module StampClient
  class Base < JsonApiClient::Resource
    self.site = ENV['STAMP_URL']
  end

  class Stamp < Base
    def owner_id
      attributes['owner-id']
    end

    def update(attrs)
      self.update_attributes(attrs)
    end

  end

  class Permission < Base
    custom_endpoint :check, on: :collection, request_method: :post

    class << self
      attr_accessor :unpermitted_uuids

      def check_catch(args)
        begin
          check(args)
        rescue JsonApiClient::Errors::AccessDenied => e
          @unpermitted_uuids = e.env.body["errors"].first["material_uuids"]
          return false
        end
        return true
      end
    end
  end

  class Material < Base
  end

end

