require "spec_helper"
require "pry"

RSpec.describe StampClient do

  it "has a version number" do
    expect(AkerStampClient::VERSION).not_to be nil
  end
end
