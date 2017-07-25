require "aker_stamp_client/version"
require "json_api_client"

module StampClient
  class Base < JsonApiClient::Resource
    self.site = ENV['STAMP_URL']
  end

  class Stamp < Base
    def owner_id
      attributes['owner-id']
    end
  end

  class Permission < Base
    custom_endpoint :check, on: :collection, request_method: :post

    attr_accessor :unpermitted_uuids

    def self.check_catch(args)
      begin
        check(args)
      rescue JsonApiClient::Errors::AccessDenied => e
        @unpermitted_uuids = e.env.body["errors"].first["material_uuids"]
        return e.env.body["errors"].first["material_uuids"]
      end
      return true
    end
  end

  class Material < Base
  end

end

