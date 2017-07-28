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

    def self.find_with_materials(stamp_id)
      includes(:materials).find(stamp_id)
    end

    def set_permission_to(permissions)
      set_permissions(data: permissions).first
    end

    def apply_to(materials)
      apply(data: { materials: materials }).first
    end

    def unapply_to(materials)
      unapply(data: { materials: materials }).first
    end
  end

  class Permission < Base
    custom_endpoint :check, on: :collection, request_method: :post

    def permission_type
      attributes['permission-type'].to_sym
    end

    def accessible_id
      attributes['accessible-id']
    end

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
    def material_uuid
      attributes['material-uuid']
    end
    def stamp_id
      attributes['stamp-id']
    end
  end

end

