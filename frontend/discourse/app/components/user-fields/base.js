/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { service } from "@ember/service";
import { classNameBindings } from "@ember-decorators/component";

@classNameBindings(":user-field", "field.field_type", "customFieldClass")
export default class UserFieldBase extends Component {
  @service currentUser;

  didInsertElement() {
    super.didInsertElement(...arguments);

    let element = this.element.querySelector(
      ".user-field.dropdown .select-kit-header"
    );
    element = element || this.element.querySelector("input");
    this.field.element = element;
  }

  @computed
  get noneLabel() {
    return "user_fields.none";
  }

  @computed("field.editable_once", "value", "currentUser.staff")
  get locked() {
    if (!this.field?.editable_once || this.currentUser?.staff) {
      return false;
    }
    const value = this.value;
    return value != null && value !== "" && value !== false && value !== "false";
  }

  @computed("field.name")
  get customFieldClass() {
    if (this.field?.name) {
      const fieldName = this.field.name
        .replace(/\s+/g, "-")
        .replace(/[!\"#$%&'\(\)\*\+,\.\/:;<=>\?\@\[\\\]\^`\{\|\}~]/g, "")
        .toLowerCase();
      return fieldName && `user-field-${fieldName}`;
    }
  }
}
