require "aker_stamp_client/version"
require "json_api_client"

module StampClient
  class Base < JsonApiClient::Resource
    self.site = ENV['STAMP_URL']

    # has_many :permissions
  end

  class Stamp < Base

    def owner_id
      attributes['owner-id']
    end
  end

  class Permission < Base
  end

end

