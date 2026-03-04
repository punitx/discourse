# frozen_string_literal: true

describe "Editable once user fields", type: :system do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, active: true) }

  let(:user_fields_page) { PageObjects::Pages::AdminUserFields.new }
  let(:user_preferences_profile_page) { PageObjects::Pages::UserPreferencesProfile.new }

  describe "admin UI" do
    before { sign_in(admin) }

    it "shows the editable once checkbox and toggles correctly" do
      user_fields_page.visit
      user_fields_page.click_add_field

      form = page.find(".user-field")
      editable_once_label = I18n.t("admin_js.admin.user_fields.editable_once.title")

      expect(form).to have_field(editable_once_label, checked: false)

      form.check(editable_once_label)
      expect(form).to have_field(editable_once_label, checked: true)

      editable_label = I18n.t("admin_js.admin.user_fields.editable.title")
      expect(form).to have_field(editable_label, checked: true)
    end

    it "disables editable_once when for_all_users is selected" do
      user_fields_page.visit
      user_fields_page.click_add_field

      form = page.find(".user-field")
      editable_once_label = I18n.t("admin_js.admin.user_fields.editable_once.title")

      user_fields_page.choose_requirement("for_all_users")

      expect(form).to have_field(editable_once_label, disabled: true)
    end
  end

  describe "user profile" do
    let!(:field) do
      UserField.create!(
        field_type: "text",
        name: "Company",
        description: "Your company name",
        requirement: :optional,
        editable: true,
        editable_once: true,
      )
    end

    context "when user has not yet filled in the field" do
      before { sign_in(user) }

      it "shows the field as editable" do
        user_preferences_profile_page.visit(user)

        field_input = find(".user-field-company input")
        expect(field_input).not_to be_disabled
      end

      it "allows the user to fill in the field" do
        user_preferences_profile_page.visit(user)

        find(".user-field-company input").fill_in(with: "Acme Corp")
        user_preferences_profile_page.save

        page.refresh
        expect(find(".user-field-company input").value).to eq("Acme Corp")
      end
    end

    context "when user has already filled in the field" do
      before do
        user.custom_fields["#{User::USER_FIELD_PREFIX}#{field.id}"] = "Acme Corp"
        user.save_custom_fields
        sign_in(user)
      end

      it "shows the field as disabled/read-only" do
        user_preferences_profile_page.visit(user)

        field_input = find(".user-field-company input")
        expect(field_input).to be_disabled
      end

      it "does not allow the user to change the value" do
        user_preferences_profile_page.visit(user)

        find(".user-field-company input")
        user_preferences_profile_page.save

        page.refresh
        expect(find(".user-field-company input").value).to eq("Acme Corp")
      end
    end

    context "when viewing as admin" do
      before do
        user.custom_fields["#{User::USER_FIELD_PREFIX}#{field.id}"] = "Acme Corp"
        user.save_custom_fields
        sign_in(admin)
      end

      it "shows the field as editable for staff" do
        page.visit("/u/#{user.username}/preferences/profile")

        field_input = find(".user-field-company input")
        expect(field_input).not_to be_disabled
      end
    end
  end
end
