# frozen_string_literal: true

RSpec.describe "Editable once user fields" do
  fab!(:admin)
  fab!(:user)
  fab!(:user2, :user)

  let!(:field) do
    Fabricate(
      :user_field,
      name: "Company",
      field_type: "text",
      editable: true,
      editable_once: true,
      requirement: "optional",
    )
  end

  let(:field_id) { field.id.to_s }
  let(:update_url) { "/u/#{user.username}.json" }

  def set_field_value(target_user, value)
    target_user.custom_fields["#{User::USER_FIELD_PREFIX}#{field.id}"] = value
    target_user.save_custom_fields
  end

  describe "Admin::UserFieldsController" do
    before { sign_in(admin) }

    it "allows creating a field with editable_once" do
      expect {
        post "/admin/config/user_fields.json",
             params: {
               user_field: {
                 name: "Nationality",
                 description: "Your country of origin",
                 field_type: "text",
                 requirement: "optional",
                 editable: true,
                 editable_once: true,
               },
             }
        expect(response.status).to eq(200)
      }.to change(UserField, :count).by(1)

      expect(UserField.last.editable_once).to eq(true)
    end

    it "allows updating a field to editable_once" do
      put "/admin/config/user_fields/#{field.id}.json",
          params: { user_field: { editable_once: false } }
      expect(response.status).to eq(200)
      expect(field.reload.editable_once).to eq(false)

      put "/admin/config/user_fields/#{field.id}.json",
          params: { user_field: { editable_once: true } }
      expect(response.status).to eq(200)
      expect(field.reload.editable_once).to eq(true)
    end

    it "includes editable_once in the serialized response" do
      get "/admin/config/user_fields.json"
      expect(response.status).to eq(200)
      user_field_json = response.parsed_body["user_fields"].find { |f| f["id"] == field.id }
      expect(user_field_json).to have_key("editable_once")
      expect(user_field_json["editable_once"]).to eq(true)
    end

    it "allows admin to update an editable_once field value for a user even when the user has a value" do
      set_field_value(user, "OriginalValue")

      put "/u/#{user.username}.json",
          params: { user_fields: { field_id => "NewValue" } }
      expect(response.status).to eq(200)
      expect(user.reload.custom_fields["#{User::USER_FIELD_PREFIX}#{field.id}"]).to eq("NewValue")
    end
  end

  describe "UsersController#update" do
    before { sign_in(user) }

    it "allows user to set an editable_once field when it has no value" do
      expect {
        put update_url, params: { user_fields: { field_id => "InitialValue" } }
        expect(response.status).to eq(200)
      }.to change { user.reload.custom_fields["#{User::USER_FIELD_PREFIX}#{field.id}"] }.from(nil).to(
        "InitialValue",
      )
    end

    it "prevents user from changing an editable_once field after providing a value" do
      set_field_value(user, "LockedValue")

      put update_url, params: { user_fields: { field_id => "NewValue" } }
      expect(response.status).to eq(200)
      expect(user.reload.custom_fields["#{User::USER_FIELD_PREFIX}#{field.id}"]).to eq("LockedValue")
    end

    it "works with for_all_users requirement" do
      field.update!(requirement: "for_all_users")

      put update_url, params: { user_fields: { field_id => "FirstValue" } }
      expect(response.status).to eq(200)
      expect(user.reload.custom_fields["#{User::USER_FIELD_PREFIX}#{field.id}"]).to eq("FirstValue")

      put update_url, params: { user_fields: { field_id => "TryToChange" } }
      expect(response.status).to eq(200)
      expect(user.reload.custom_fields["#{User::USER_FIELD_PREFIX}#{field.id}"]).to eq("FirstValue")
    end

    context "when admin clears the value" do
      it "allows user to fill in the field again after admin clears it" do
        set_field_value(user, "OldValue")
        admin = Fabricate(:admin)
        sign_in(admin)

        # Admin clears the value
        put "/u/#{user.username}.json", params: { user_fields: { field_id => "" } }

        sign_in(user)
        put update_url, params: { user_fields: { field_id => "NewValue" } }
        expect(response.status).to eq(200)
        expect(user.reload.custom_fields["#{User::USER_FIELD_PREFIX}#{field.id}"]).to eq("NewValue")
      end
    end

    context "when user is a moderator" do
      it "allows moderator (staff) to change editable_once field for themselves" do
        mod = Fabricate(:moderator)
        set_field_value(mod, "OldValue")
        sign_in(mod)

        put "/u/#{mod.username}.json", params: { user_fields: { field_id => "NewValue" } }
        expect(response.status).to eq(200)
        expect(mod.reload.custom_fields["#{User::USER_FIELD_PREFIX}#{field.id}"]).to eq("NewValue")
      end
    end
  end
end
