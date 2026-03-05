# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUserFields < PageObjects::Pages::Base
      def visit
        page.visit "admin/config/user-fields"
        self
      end

      def form
        PageObjects::Components::FormKit.new(".user-field .form-kit")
      end

      def choose_requirement(requirement)
        form = page.find(".user-field")

        form.choose(I18n.t("admin_js.admin.user_fields.requirement.#{requirement}.title"))
        self
      end

      def unselect_preference(preference)
        checkbox = preference_checkbox(preference)
        checkbox.click if checkbox.checked?
        self
      end

      def select_preference(preference)
        checkbox = preference_checkbox(preference)
        checkbox.click unless checkbox.checked?
        self
      end

      def preference_state(preference)
        checkbox = preference_checkbox(preference)
        { checked: checkbox.checked?, disabled: checkbox.disabled? }
      end

      def click_add_field
        page.find(".d-page-header__actions .btn-primary").click
        self
      end

      def click_edit
        page.find(".admin-user_field-item__edit").click
        self
      end

      def set_name(name)
        page.find(".user-field .user-field-name").fill_in(with: name)
        self
      end

      def set_description(description)
        page.find(".user-field .user-field-desc").fill_in(with: description)
        self
      end

      def save_field
        page.find(".user-field .save").click
        self
      end

      def add_field(name: nil, description: nil, requirement: nil, preferences: [])
        click_add_field

        set_name(name)
        set_description(description)
        choose_requirement(requirement) if requirement.present?
        preferences.each { |preference| select_preference(preference) }
        save_field
      end

      def has_user_field?(name)
        page.has_text?(name)
      end

      private

      def preference_checkbox(preference)
        form = page.find(".user-field")
        form.find_field(
          I18n.t("admin_js.admin.user_fields.#{preference}.title"),
          visible: :all,
          disabled: :all,
        )
      end
    end
  end
end
