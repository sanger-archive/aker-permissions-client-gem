require "spec_helper"
require "pry"

RSpec.describe StampClient do

  let(:content_type) { 'application/vnd.api+json' }
  let(:request_headers) { { 'Accept' => content_type, 'Content-Type'=> content_type } }
  let(:response_headers) { { 'Content-Type' => content_type } }
  let(:url) { 'http://localhost:9999/api/v1/' }

  before do
    StampClient::Base.site = url
  end

  describe StampClient::Deputy do

    describe "#create" do
      before do
        @new_id = SecureRandom.uuid
        @user_email = "guest@test.com"
        @deputy = "deputy1"
        stub_request(:post, url+"deputies")
          .with(body: { data: { type: "deputies", attributes: { deputy: @deputy }}}.to_json,
                headers: request_headers )
          .to_return(status: 201, body: { data: make_deputy_data(@new_id, @user_email, @deputy) }.to_json,
                     headers: response_headers)

        @new_deputy = StampClient::Deputy.create({ deputy: @deputy })
      end

      it "has an id" do
        expect(@new_deputy.id).to eq(@new_id)
      end

      it "has a user_email" do
        expect(@new_deputy.user_email).to eq(@user_email)
      end

      it "has an deputy" do
        expect(@new_deputy.deputy).to eq(@deputy)
      end
    end

    describe '#find' do
      before do
        @id = SecureRandom.uuid
        @user_email = "guest@test.com"
        @deputy = "deputy1"

        stub_deputy(@id, @user_email, @deputy)

        @dep = StampClient::Deputy.find(@id)
        @frist_dep = @dep&.first
      end

      it 'finds one deputy' do
        expect(@dep).not_to be_nil
        expect(@dep.length).to eq(1)
      end

      it 'gives a deputy with the correct fields' do
        expect(@frist_dep).not_to be_nil
        expect(@frist_dep.id).to eq(@id)
        expect(@frist_dep.user_email).to eq(@user_email)
        expect(@frist_dep.deputy).to eq(@deputy)
      end
    end

    describe '#all' do
      before do
        @data = [
          make_deputy_data(SecureRandom.uuid, 'jeff', "deputy1"),
          make_deputy_data(SecureRandom.uuid, 'bob', "deputy2"),
        ]
        stub_request(:get, url + 'deputies')
          .to_return(status: 200, body: { data: @data }.to_json, headers: response_headers)
      end

      it 'returns all deputies' do
        all_deps = StampClient::Deputy.all
        expect(all_deps.length).to eq(@data.length)
        @data.zip(all_deps).each do |d, deputy|
          expect(deputy.id).to eq(d[:id])
          expect(deputy.user_email).to eq(d[:attributes][:user_email])
          expect(deputy.deputy).to eq(d[:attributes][:deputy])
        end
      end
    end
  end

  ###
  # PRIVATE START
  ###
  private

    def deputy_urlid(id)
      url + 'deputies/' + id
    end

    def stub_deputy(id, user_email, deputy)
      deputy_data = make_deputy_data(id, user_email, deputy)

      stub_request(:get, deputy_urlid(id))
        .with(headers: request_headers)
        .to_return(status: 200, body: { data: deputy_data }.to_json, headers: response_headers)
    end

    def make_deputy_data(id, user_email, deputy)
        {
          id: id,
          type: "deputies",
          attributes: {
            user_email: user_email,
            deputy: deputy
          }
        }
    end

  ###
  # PRIVATE END
  ###

end
