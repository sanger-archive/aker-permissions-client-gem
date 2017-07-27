require "spec_helper"
require "pry"

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

    describe "#create" do
      before do
        stub_request(:post, url+"stamps")
          .with( body: { data: { type: "stamps", attributes: { name: "stamp4", "owner-id": 1}}}.to_json, headers: request_headers )
          .to_return(status: 200, body: "", headers: response_headers)

        @new_stamp = StampClient::Stamp.create({name: 'stamp4', 'owner-id': 1})
      end

      it "has a name" do
        expect(@new_stamp.name).to eq 'stamp4'
      end

      it "has a owner_id" do
        expect(@new_stamp.owner_id).to eq 1
      end
    end

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

    describe '#find_with_permissions' do
      before do
        @stamp_id = "123"
        @name = "stamp1"
        @owner_id = "dirk@here.com"
        @permission_id = "1"
        @permission_type = :spend
        @permitted = 'zogh'

        stub_stamp(@stamp_id, @name, @owner_id)
      end

      it "returns an empty list when the stamp has no permissions" do
        response_body = make_stamp_with_no_permission_data(@stamp_id, @name, @owner_id)

        stub_request(:get, stamp_urlid(@stamp_id)+"?include=permissions")
          .with(:headers => request_headers )
          .to_return(:status => 200, :body => response_body.to_json, :headers => response_headers)

        stamp = StampClient::Stamp.find_with_permissions(@stamp_id)
        expect(stamp).not_to be_nil
        permissions = stamp.first.permissions
        expect(permissions.length).to eq 0
        expect(permissions).to eq []
      end

      it "returns list of permissions when the stamp has permissions" do
        response_body = make_stamp_with_permission_data(@stamp_id, @name, @owner_id, @permission_id, @permitted, @permission_type)

        stub_request(:get, stamp_urlid(@stamp_id)+"?include=permissions")
          .with(:headers => request_headers )
          .to_return(:status => 200, :body => response_body.to_json, :headers => response_headers)

        stamp = StampClient::Stamp.find_with_permissions(@stamp_id)
        permissions = stamp.first.permissions
        expect(permissions).not_to be_nil
        expect(permissions.length).to eq 1
        permission = permissions&.first
        expect(permission.id).to eq "1"
        expect(permission["permission-type"]).to eq @permission_type.to_s
        expect(permission["permitted"]).to eq @permitted
        expect(permission["accessible-id"]).to eq @stamp_id
      end
    end

    describe '#all' do
      before do
        @data = [
          make_stamp_data(1, "stamp1", 1),
          make_stamp_data(2, "stamp2", 1),
        ]
        stub_request(:get, url+'stamps')
          .to_return(status: 200, body: { data: @data }.to_json, headers: response_headers)
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

    describe '#patch' do
      before do
        id = "123"
        name = "stamp1"
        owner_id = "1"

        stub_stamp(id, name, owner_id)

        rs = StampClient::Stamp.find(id)
        @stamp = rs&.first

        stub_request(:patch, stamp_urlid(id))
          .with( body: { data: { id: '123', type: "stamps", attributes: { name: "newname"}}}.to_json, headers: request_headers)
          .to_return(status: 200, body: "", headers: response_headers)
      end

      it "can be updated" do
        @stamp.update(name: 'newname')
        expect(@stamp.name).to eq 'newname'
      end
    end
  end

  describe StampClient::Permission do
    describe '#create' do
      before do
        @id = '123'
        stamp_name = 'stamp123'
        stamp_owner_id = 'dirk@here.com'
        stub_stamp(@id, stamp_name, stamp_owner_id)

        rs = StampClient::Stamp.find(@id)
        @stamp = rs&.first

        @permission_type = :spend
        @permitted = 'permitted_person'
      end

      context 'when the user is the owner of the stamp' do
        before do
          response_body = make_permission_data("456", @permission_type, @permitted, @id)

          stub_request(:post, url+"permissions")
            .with(body: { data: { type: "permissions", attributes: { "permission-type": @permission_type, permitted: @permitted, "accessible-id": @id}}}.to_json,
              headers: request_headers)
            .to_return(:status => 200, :body => response_body.to_json, :headers => response_headers)
        end

        it 'creates a permission on the stamp' do
          perm = StampClient::Permission.create('permission-type': @permission_type, permitted: @permitted, 'accessible-id': @id)

          expect(perm).not_to be_nil
          expect(perm.id).to eq "456"
          expect(perm["permission-type"]).to eq "spend"
          expect(perm["permitted"]).to eq @permitted
          expect(perm["accessible-id"]).to eq @id
        end
      end

      context 'when the user is not the owner of the stamp' do
        before do
          stub_request(:post, url+"permissions")
            .with(body: { data: { type: "permissions", attributes: { "permission-type": @permission_type, permitted: @permitted, "accessible-id": @id}}}.to_json,
              headers: request_headers)
            .to_return(:status => 403, :body => "", :headers => response_headers)
        end

        it 'it throws AccessDenied exception ' do
          expect { StampClient::Permission.create('permission-type': @permission_type, permitted: @permitted, 'accessible-id': @id) }.to raise_error JsonApiClient::Errors::AccessDenied
        end
      end
    end

    describe '#destroy' do

      context 'when the user is the owner of the stamp' do
        before do
          @id = "1"
          permission_type = :spend
          permitted = 'dirk'
          stamp_id = '123'
          stub_permission(@id, permission_type, permitted, stamp_id)

          stub_request(:delete, url+"permissions").
            with(headers: response_headers).
            to_return(:status => 204, :body => "", :headers => {})
        end

        it 'the permission is destroyed and removed from the stamp' do
          p = StampClient::Permission.find(@id).first
          expect(p.destroy).to eq true
        end
      end

      context 'when the user is not the owner of the stamp' do
        before do
          @id = "1"
          permission_type = :spend
          permitted = 'dirk'
          stamp_id = 'x123'
          stub_permission(@id, permission_type, permitted, stamp_id)

          stub_request(:delete, url+"permissions").
            with(headers: response_headers).
            to_return(:status => 403, :body => "", :headers => {})
        end

        it 'the permission is destroyed and removed from the stamp' do
          p = StampClient::Permission.find(@id).first
          expect { p.destroy }.to raise_error JsonApiClient::Errors::AccessDenied
        end
      end

    end

    describe '#check_catch' do
      before do
        @permission_type = 'spend'
        @names = ['dirk@here.com']
        @material_uuids = ['123']
      end

      it 'returns true when check_catch returns no unpermitted material_uuids' do
        stub_permission_check_200(@permission_type, @names, @material_uuids)

        data = make_permission_check_data(@permission_type, @names, @material_uuids)
        rs = StampClient::Permission.check_catch(data)
        expect(rs).to eq true
      end

      it 'returns false when check_catch returns a list of unpermitted material_uuids' do
        stub_permission_check_403(@permission_type, @names, @material_uuids)

        data = make_permission_check_data(@permission_type, @names, @material_uuids)
        rs = StampClient::Permission.check_catch(data)
        expect(rs).to eq false
        expect(StampClient::Permission.unpermitted_uuids).to eq @material_uuids
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

  def make_stamp_with_permission_data(id, name, owner_id, permission_id, permitted, permission_type)
    {
      data:
      {
        id: id,
        type: "stamps",
        attributes:
        {
          name: name,
          "owner-id": owner_id
        },
        relationships:
        {
          permissions:
          {
            data: [{ type: "permissions", id: permission_id}]
          }
        }
      },
      included:
      [
        {
          id: permission_id,
          type: "permissions",
          attributes:
          {
            "permission-type": permission_type,
            permitted: permitted,
            "accessible-id": id
          }
        }
      ]
    }
  end

  def make_stamp_with_no_permission_data(id, name, owner_id)
    {
      data:
      {
        id: id,
        type: "stamps",
        attributes:
        {
          name: name,
          "owner-id": owner_id
        },
        relationships:
        {
          permissions:
          {
            data: []
          }
        }
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

  def stub_permission_check_200(permission_type, names, material_uuids)
    data = make_permission_check_data(permission_type, names, material_uuids)

    stub_request(:post, url+"permissions/check")
        .with( body: data.to_json, headers: request_headers)
        .to_return(status: 200, body: '', headers: response_headers)
  end

  def stub_permission_check_403(permission_type, names, material_uuids)
    data = make_permission_check_data(permission_type, names, material_uuids)

    response_body = {errors:[{status:"403",title:"Permission failed",detail:"The specified permission was not present for some materials.",material_uuids: material_uuids }]}

    stub_request(:post, url+"permissions/check")
        .with(body: data.to_json, headers: request_headers)
        .to_return(status: 403, body: response_body.to_json, headers: response_headers)
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

  def make_permission_check_data(permission_type, names, material_uuids)
    {
      data:
      {
        permission_type: permission_type,
        names: names,
        material_uuids: material_uuids
      }
    }
  end

  def stub_permission_check_200(permission_type, names, material_uuids)
    data = make_permission_check_data(permission_type, names, material_uuids)

    stub_request(:post, url+"permissions/check").
        with(
            body: data.to_json,
            headers: request_headers
            )
        .to_return(status: 200, body: '', headers: response_headers)
  end

  def stub_permission_check_403(permission_type, names, material_uuids)
    data = make_permission_check_data(permission_type, names, material_uuids)

    response_body = {errors:[{status:"403",title:"Permission failed",detail:"The specified permission was not present for some materials.",material_uuids: material_uuids }]}

    stub_request(:post, url+"permissions/check").
        with(
            body: data.to_json,
            headers: request_headers
            )
        .to_return(status: 403, body: response_body.to_json, headers: response_headers)
  end

  def make_permission_check_data(permission_type, names, material_uuids)
    {
      data: {
        permission_type: permission_type,
        names: names,
        material_uuids: material_uuids
      }
    }
  end

end

