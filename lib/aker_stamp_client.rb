require "aker_stamp_client/version"
require "json_api_client"

module StampClient
  class Base < JsonApiClient::Resource
    self.site = ENV['STAMP_URL']

    # has_many :permissions
  end

  class Stamp < Base
  end

  class Permission < Base
  end

end

