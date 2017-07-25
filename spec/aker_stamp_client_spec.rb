require "spec_helper"

RSpec.describe StampClient do

  let(:content_type) { 'application/vnd.api+json' }
  let(:request_headers) { { 'Accept' => content_type, 'Content-Type'=> content_type } }
  let(:response_headers) { { 'Content-Type'=> content_type } }
  let(:url) { 'http://localhost:9999/api/v1/' }

  before do
    StampClient::Base.site = url
  end

  it "has a version number" do
    expect(AkerStampClient::VERSION).not_to be nil
  end

  describe StampClient::Stamp do

    describe '#find' do
      before do
        @id = "123"
        @name = "stamp1"
        @owner_id = "1"

        stub_stamp(@id, @name, @owner_id)

        @rs = StampClient::Stamp.find(@id)
        @stamp = @rs&.first
      end

      it 'finds one stamp' do
        expect(@rs).not_to be_nil
        expect(@rs.length).to eq(1)
      end

      it 'gives a stamp with the correct fields' do
        expect(@stamp).not_to be_nil
        expect(@stamp.id).to eq(@id)
        expect(@stamp.name).to eq(@name)
        expect(@stamp["owner-id"]).to eq(@owner_id)
      end
    end

    describe '#all' do
      before do
        @data = [
          make_stamp_data(1, "stamp1", 1, stamp_urlid('1')),
          make_stamp_data(2, "stamp2", 1, stamp_urlid('2')),
        ]
        stub_request(:get, url+'stamps').
          to_return(status: 200, body: { data: @data }.to_json, headers: response_headers)
      end

      it 'returns all stamps' do
        rs = StampClient::Stamp.all
        expect(rs.length).to eq(@data.length)
        @data.zip(rs).each do |d, stamp|
          expect(stamp.id).to eq(d[:id])
          expect(stamp.name).to eq(d[:attributes][:name])
          expect(stamp.owner_id).to eq(d[:attributes][:'owner-id'])
        end
      end
    end

  end

  private

  def stamp_urlid(id)
    url+'stamps/'+id
  end

  def stub_stamp(id, name, owner_id)
    stamp_data = make_stamp_data(id, name, owner_id, stamp_urlid(id))

    stub_request(:get, stamp_urlid(id))
         .with(headers: request_headers)
         .to_return(status: 200, body: { data: stamp_data }.to_json, headers: response_headers)
  end

  def make_stamp_data(id, name, owner_id, urlid)
      {
        id: id,
        type: "stamps",
        links: {
          self: urlid
        },
        attributes: {
          name: name,
          'owner-id': owner_id
        },
        relationships: {
          permissions: {
            links: {
              self: urlid+"/relationships/permissions",
              related: urlid+"/permissions",
            },
          },
          materials: {
            links: {
              self: urlid+"/relationships/materials",
              related: urlid+"/materials",
            }
          }
        }
      }
  end

end

