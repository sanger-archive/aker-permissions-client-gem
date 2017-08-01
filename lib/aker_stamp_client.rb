require "aker_stamp_client/version"
require "json_api_client"
require "pry"
require 'active_support/inflector'

module StampClient
  class Base < JsonApiClient::Resource
    self.site = ENV['STAMP_URL']
    self.json_key_format = :dasherized_key
  end

  class Stamp < Base
    custom_endpoint :set_permissions, on: :member, request_method: :post
    custom_endpoint :apply, on: :member, request_method: :post
    custom_endpoint :unapply, on: :member, request_method: :post

    def update(attrs)
      self.update_attributes(attrs)
    end

    def self.find_with_permissions(stamp_id)
      includes(:permissions).find(stamp_id)
    end

    def self.find_with_materials(stamp_id)
      includes(:materials).find(stamp_id)
    end

    def set_permissions_to(permissions)
      json_permissions = permissions.map do |perm|
        perm.map { |k,v| [k.to_s.sub('_','-'), v] }.to_h
      end
      set_permissions(data: json_permissions).first
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
      attributes[:permission_type]&.to_sym
    end

    class << self
      attr_accessor :unpermitted_uuids

      def check_catch(materials)
        begin
          check(data: materials)
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

