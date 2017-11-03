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

  describe StampClient::Permission do
    describe '#create' do
      before do
        @id = SecureRandom.uuid
        stamp_name = 'stamp123'
        stamp_owner_id = 'dirk@here.com'
        stub_stamp(@id, stamp_name, stamp_owner_id)

        rs = StampClient::Stamp.find(@id)
        @stamp = rs&.first

        @permission_type = :spend
        @permitted = 'permitted_person'
        @postdata = { type: "permissions", attributes: { "permission-type": @permission_type, permitted: @permitted, "accessible-id": @id }}
      end

      context 'when the user is the owner of the stamp' do
        before do
          @permission_id = "4"
          response_body = make_permission_data(@permission_id, @permission_type, @permitted, @id)

          stub_request(:post, url+"permissions")
            .with(body: { data: @postdata }.to_json, headers: request_headers)
            .to_return(status: 200, body: response_body.to_json, headers: response_headers)
        end

        it 'creates a permission on the stamp' do
          perm = StampClient::Permission.create(permission_type: @permission_type, permitted: @permitted, accessible_id: @id)

          expect(WebMock).to have_requested(:post, url+"permissions")
            .with(body: { data: @postdata }.to_json, headers: request_headers)

          expect(perm).not_to be_nil
          expect(perm.id).to eq @permission_id
          expect(perm.permission_type).to eq @permission_type
          expect(perm.permitted).to eq @permitted
          expect(perm.accessible_id).to eq @id
        end
      end

      context 'when the user is not the owner of the stamp' do
        before do
          stub_request(:post, url+"permissions")
            .with(body: { data: @postdata }.to_json, headers: request_headers)
            .to_return(status: 403, body: "", headers: response_headers)
        end

        it 'throws AccessDenied exception' do
          expect { StampClient::Permission.create(permission_type: @permission_type, permitted: @permitted, accessible_id: @id) }.to raise_error JsonApiClient::Errors::AccessDenied
        end
      end
    end

    describe '#destroy' do

      context 'when the user is the owner of the stamp' do
        before do
          @id = "1"
          permission_type = :spend
          permitted = 'dirk'
          stamp_id = SecureRandom.uuid
          stub_permission(@id, permission_type, permitted, stamp_id)

          stub_request(:delete, url+"permissions").
            with(headers: response_headers).
            to_return(status: 204, body: "", headers: response_headers)
        end

        it 'deletes the permission' do
          perm = StampClient::Permission.find(@id).first
          expect(perm.destroy).to eq true
          expect(WebMock).to have_requested(:delete, url+"permissions")
        end
      end

      context 'when the user is not the owner of the stamp' do
        before do
          @perm_id = "1"
          permission_type = :spend
          permitted = 'dirk'
          stamp_id = SecureRandom.uuid
          stub_permission(@perm_id, permission_type, permitted, stamp_id)

          stub_request(:delete, url+"permissions").
            with(headers: response_headers).
            to_return(status: 403, body: "", headers: {})
        end

        it 'raises an error' do
          perm = StampClient::Permission.find(@perm_id).first
          expect { perm.destroy }.to raise_error JsonApiClient::Errors::AccessDenied
        end
      end

    end

    describe '#check_catch' do
      before do
        @permission_type = :spend
        @names = ['dirk@here.com']
        @material_uuids = [ SecureRandom.uuid, SecureRandom.uuid, SecureRandom.uuid ]
      end

      context 'when there are no unpermitted material uuids' do
        before do
          stub_permission_check_200(@permission_type, @names, @material_uuids)
          @data = make_permission_check_data(@permission_type, @names, @material_uuids)
          @result = StampClient::Permission.check_catch(@data)
        end

        it 'sends the check request' do
          expect(WebMock).to have_requested(:post, url+"permissions/check")
            .with(body: { data: @data }.to_json, headers: request_headers)
        end

        it 'returns true' do
          expect(@result).to be_truthy
        end
      end

      context 'when there are unpermitted material uuids' do
        before do
          @unpermitted_uuid = @material_uuids[0,2]
          stub_permission_check_403(@permission_type, @names, @material_uuids, @unpermitted_uuids)
          data = make_permission_check_data(@permission_type, @names, @material_uuids)
          @result = StampClient::Permission.check_catch(data)
        end

        it 'returns false' do
          expect(@result).to be_falsey
        end

        it 'contains the unpermitted uuids' do
          expect(StampClient::Permission.unpermitted_uuids).to eq(@unpermitted_uuids)
        end
      end
    end

  end

  private

    def stamp_urlid(id)
      url+'stamps/'+id
    end

    def stub_stamp(id, name, owner_id)
      stamp_data = make_stamp_data(id, name, owner_id)

      stub_request(:get, stamp_urlid(id))
           .with(headers: request_headers)
           .to_return(status: 200, body: { data: stamp_data }.to_json, headers: response_headers)
    end

    def make_stamp_data(id, name, owner_id)
        {
          id: id,
          type: "stamps",
          attributes: {
            name: name,
            'owner-id': owner_id
          }
        }
    end

    def permission_urlid(id)
      url+'permissions/'+id
    end

    def stub_permission(id, permission_type, permitted, accessible_id)
      permission_data = make_permission_data(id, permission_type, permitted, accessible_id)

      stub_request(:get, permission_urlid(id))
          .with(headers: request_headers)
          .to_return(status: 200, body: { data: permission_data }.to_json, headers: response_headers)
    end

    def make_permission_data(id, permission_type, permitted, accessible_id)
      {
        data:
        {
          id: id,
          type: "permissions",
          attributes:
          {
            "permission-type": permission_type,
            permitted: permitted,
            "accessible-id": accessible_id
          }
        }
      }

    end

    def stub_permission_check_200(permission_type, names, material_uuids)
      data = make_permission_check_data(permission_type, names, material_uuids)
      stub_data = {data: data}
      stub_request(:post, url+"permissions/check").
        with(body: stub_data.to_json, headers: request_headers).
        to_return(status: 200, body: '', headers: response_headers)
    end

    def stub_permission_check_403(permission_type, names, material_uuids, unpermitted_uuids)
      data = make_permission_check_data(permission_type, names, material_uuids)
      stub_data = {data: data}

      response_body = { errors: [{
          status: "403",
          title: "Permission failed",
          detail: "The specified permission was not present for some materials.",
          material_uuids: unpermitted_uuids
      }]}

      stub_request(:post, url+"permissions/check").
        with(body: stub_data.to_json, headers: request_headers).
        to_return(status: 403, body: response_body.to_json, headers: response_headers)
    end

    def make_permission_check_data(permission_type, names, material_uuids)
      {
          permission_type: permission_type,
          names: names,
          material_uuids: material_uuids
      }
    end

end
