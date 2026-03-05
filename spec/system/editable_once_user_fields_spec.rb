# frozen_string_literal: true

describe "Editable once user fields", type: :system do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, active: true) }

  let(:admin_user_fields_page) { PageObjects::Pages::AdminUserFields.new }
  let(:user_preferences_profile_page) { PageObjects::Pages::UserPreferencesProfile.new }

  it "allows configuring editable once and locks the field after first user update" do
    sign_in(admin)
    admin_user_fields_page.visit
    admin_user_fields_page
      .click_add_field
      .set_name("One-time display name")
      .set_description("Can only be edited once")
      .select_preference("editable_once")
      .save_field

    admin_user_fields_page.click_edit
    expect(admin_user_fields_page.preference_state("editable")).to eq(checked: true, disabled: true)
    admin_user_fields_page.save_field

    field = UserField.find_by(name: "One-time display name")
    expect(field).to be_present
    expect(field).to have_attributes(editable_once: true, editable: true)

    sign_in(user)
    user_preferences_profile_page.visit(user)
    user_preferences_profile_page.fill_custom_text_field(
      "user-field-one-time-display-name",
      with: "My first value",
    )
    user_preferences_profile_page.save

    page.refresh

    expect(
      user_preferences_profile_page.has_custom_text_field_disabled?(
        "user-field-one-time-display-name",
      ),
    ).to eq(true)
  end
end
