require "aker_stamp_client/version"
require "json_api_client"
require "pry"

module StampClient
  class Base < JsonApiClient::Resource
    self.site = ENV['STAMP_URL']
  end

  class Stamp < Base
    custom_endpoint :set_permissions, on: :member, request_method: :post
    custom_endpoint :apply, on: :member, request_method: :post
    custom_endpoint :unapply, on: :member, request_method: :post

    def owner_id
      attributes['owner-id']
    end

    def update(attrs)
      self.update_attributes(attrs)
    end

    def self.find_with_permissions(stamp_id)
      includes(:permissions).find(stamp_id)
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

