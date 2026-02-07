# Feature Specification: Drag and Drop Form Builder UI

**Feature Branch**: `001-form-builder-ui`
**Created**: 2026-02-07
**Status**: Draft
**Input**: User description: "Let's add a form builder. For now user can build a form in the app in the edit / create pages of the forms. Building a form is possible but the features are limited. User should be able to create/edit some complex forms in a easy UI (with drag and drop from a sidebar/bottom bar for big/small screens) grouping the possibilities by input categories (basic, table, buttons...). The data coming from the form should be simple, only a string or an array within string for multiple results, or a file, per input."

## Clarifications

### Session 2026-02-07

- Q: How should the system handle concurrent editing when multiple users attempt to edit the same form simultaneously? → A: Lock form during editing - only one user can edit at a time because user can only edit their own forms.
- Q: Should the form builder support file upload fields? → A: Yes, add file upload as a field type in the Basic category (frontend only)
- Q: What types of field validation should be supported in the form builder? → A: Basic + pattern validation: date range, numeric range, email/phone format validation
- Q: How should table/grid fields work in the form builder? → A: Dynamic table: add/remove rows, fixed column definitions
- Q: Should users be able to duplicate existing fields in the form builder? → A: Yes, add duplicate button on each field

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag and Drop Form Builder (Priority: P1)

As a user, I want to build forms using a drag and drop interface with categorized field components, so that I can quickly create complex forms without writing code or navigating complex menus.

**Why this priority**: This is the core functionality that enables users to create forms efficiently. Without drag and drop, form creation remains limited to the current basic interface. This provides the foundation for all other form building features.

**Independent Test**: Can be fully tested by opening the form builder, dragging fields from the component palette to the form canvas, and verifying fields are added in the correct order.

**Acceptance Scenarios**:

1. **Given** the user is on the form creation or edit page, **When** the page loads, **Then** a component palette is displayed with categorized field groups
2. **Given** the component palette is visible, **When** the user drags a field component from the palette to the form canvas, **Then** the field is added to the form at the drop location
3. **Given** the form canvas has existing fields, **When** the user drags a new field between two existing fields, **Then** the new field is inserted at that position and existing fields shift accordingly
4. **Given** the user is on a mobile device, **When** the page loads, **Then** the component palette is displayed as a bottom bar instead of a sidebar
5. **Given** the component palette is displayed, **When** the user expands a category group, **Then** the fields within that category are revealed and available for dragging

---

### User Story 2 - Categorized Field Components (Priority: P1)

As a user, I want form fields organized into logical categories (basic, table, buttons, etc.), so that I can quickly find and add the type of field I need without searching through a long list.

**Why this priority**: Categorization is essential for usability when the number of available field types grows. Without organization, users struggle to find fields, reducing productivity. This directly impacts the user experience of building complex forms.

**Independent Test**: Can be fully tested by expanding each category in the component palette and verifying the correct field types are displayed within each category.

**Acceptance Scenarios**:

1. **Given** the component palette is displayed, **When** the user views the palette, **Then** at least the following categories are visible: Basic, Table, Buttons
2. **Given** the Basic category is expanded, **When** the user views the fields, **Then** at least text, number, email, date, textarea, and file upload fields are available
3. **Given** the Table category is expanded, **When** the user views the fields, **Then** at least table/grid field is available for structured data entry
4. **Given** the Buttons category is expanded, **When** the user views the fields, **Then** at least submit and reset button options are available
5. **Given** a category is collapsed, **When** the user clicks on the category header, **Then** the category expands to show its fields

---

### User Story 3 - Field Configuration and Editing (Priority: P1)

As a user, I want to configure form field properties (label, required status, options, etc.) after adding them to my form, so that I can customize each field to match my specific requirements.

**Why this priority**: Field configuration is essential for creating functional forms. Without it, users cannot set required fields, add validation, or customize field behavior. This is a core requirement for any usable form builder.

**Independent Test**: Can be fully tested by adding a field to the form, clicking on it to open the configuration panel, modifying properties, and verifying the changes are reflected in the form preview.

**Acceptance Scenarios**:

1. **Given** a field is added to the form canvas, **When** the user clicks on the field, **Then** a configuration panel appears with editable properties for that field
2. **Given** the configuration panel is open, **When** the user modifies the field label, **Then** the label is updated on the form canvas in real-time
3. **Given** the configuration panel is open, **When** the user toggles the required checkbox, **Then** the field's required status is updated and visually indicated on the canvas
4. **Given** a select or radio field is selected, **When** the user adds options to the configuration, **Then** the options are displayed in the form preview
5. **Given** the user has made changes to field configuration, **When** the user saves the form, **Then** all field configurations are persisted

---

### User Story 4 - Field Reordering via Drag and Drop (Priority: P1)

As a user, I want to reorder form fields by dragging them to new positions, so that I can organize my form layout to match my desired user flow.

**Why this priority**: Field ordering is critical for form usability. Users need to arrange fields in a logical sequence for form respondents. Without reordering, users would need to delete and recreate fields in the correct order, which is inefficient.

**Independent Test**: Can be fully tested by adding multiple fields to a form, then dragging a field from one position to another and verifying the field moves to the new position.

**Acceptance Scenarios**:

1. **Given** the form canvas has multiple fields, **When** the user drags a field to a new position, **Then** the field moves to the new position and other fields shift accordingly
2. **Given** the user is dragging a field, **When** the field is hovered over a valid drop location, **Then** a visual indicator shows where the field will be placed
3. **Given** the user drags a field to an invalid location, **When** the drop is attempted, **Then** the field returns to its original position
4. **Given** fields have been reordered, **When** the user saves the form, **Then** the new field order is persisted
5. **Given** the user is on a mobile device, **When** the user drags a field using touch gestures, **Then** the field moves to the new position

---

### User Story 5 - Responsive UI for Mobile and Desktop (Priority: P1)

As a user, I want the form builder interface to adapt to my screen size, so that I can build forms on both desktop and mobile devices with an optimal experience.

**Why this priority**: Users may need to create or edit forms from various devices. A responsive interface ensures the feature is usable across all devices, which is essential for modern web applications.

**Independent Test**: Can be fully tested by viewing the form builder on different screen sizes and verifying the layout adapts appropriately (sidebar on desktop, bottom bar on mobile).

**Acceptance Scenarios**:

1. **Given** the user is on a desktop screen (width ≥ 768px), **When** the form builder loads, **Then** the component palette is displayed as a sidebar on the left side of the screen
2. **Given** the user is on a mobile screen (width < 768px), **When** the form builder loads, **Then** the component palette is displayed as a bottom bar at the bottom of the screen
3. **Given** the user is on a mobile device, **When** the component palette is displayed as a bottom bar, **Then** the categories are horizontally scrollable if they exceed the screen width
4. **Given** the user resizes the browser window, **When** the width crosses the breakpoint, **Then** the component palette transitions between sidebar and bottom bar layout
5. **Given** the user is on a mobile device, **When** the user taps on a category, **Then** the category expands to show available fields

---

### User Story 6 - Form Preview and Testing (Priority: P2)

As a user, I want to preview my form as it will appear to respondents, so that I can verify the form layout and behavior before publishing it.

**Why this priority**: Preview functionality helps users catch errors and design issues before the form is used by respondents. This improves form quality and reduces the need for corrections after publication.

**Independent Test**: Can be fully tested by creating a form with various field types, opening the preview mode, and verifying the form renders correctly and behaves as expected.

**Acceptance Scenarios**:

1. **Given** the user is editing a form, **When** the user clicks the preview button, **Then** the form is displayed in preview mode showing how it will appear to respondents
2. **Given** the form is in preview mode, **When** the user fills out the form fields, **Then** the form accepts input and behaves as if it were a live form
3. **Given** the form is in preview mode, **When** a required field is left empty, **Then** appropriate validation messages are displayed
4. **Given** the user is in preview mode, **When** the user clicks the edit button, **Then** the view returns to the form builder
5. **Given** the form has conditional logic or dynamic fields, **When** the user interacts with the form in preview mode, **Then** the dynamic behavior is demonstrated

---

### User Story 7 - Field Deletion and Duplication (Priority: P2)

As a user, I want to remove and duplicate fields in my form, so that I can clean up unused fields and quickly create similar fields without reconfiguring from scratch.

**Why this priority**: Field deletion and duplication are necessary maintenance operations. Users may add fields they decide they don't need, or may want to remove obsolete fields. Duplication saves time when creating similar fields. These operations improve form building efficiency.

**Independent Test**: Can be fully tested by adding multiple fields to a form, duplicating one field, and removing another, then verifying both operations work correctly.

**Acceptance Scenarios**:

1. **Given** a field is displayed on the form canvas, **When** the user clicks the delete button on the field, **Then** a confirmation dialog appears
2. **Given** the confirmation dialog is displayed, **When** the user confirms the deletion, **Then** the field is removed from the form canvas
3. **Given** the confirmation dialog is displayed, **When** the user cancels the deletion, **Then** the field remains on the form canvas
4. **Given** a field is deleted, **When** the user saves the form, **Then** the deletion is persisted and the field no longer appears in the saved form
5. **Given** a field is deleted, **When** the form has existing responses that included that field, **Then** the existing response data for that field is preserved
6. **Given** a field is displayed on the form canvas, **When** the user clicks the duplicate button on the field, **Then** a copy of the field is added immediately below the original field
7. **Given** a field is duplicated, **When** the duplicate is created, **Then** all field properties (label, type, validation, options, etc.) are copied to the new field
8. **Given** a field is duplicated, **When** the user saves the form, **Then** both the original and duplicated fields are persisted

---

### Edge Cases

- What happens when the user tries to add a field with an invalid configuration (e.g., a select field with no options)? System prevents saving and displays validation error.
- How does the system handle forms with a very large number of fields (e.g., 50+ fields)? System supports up to 50 fields per form without performance degradation.
- What happens when the user's browser doesn't support drag and drop functionality? System provides alternative click-to-add interface as fallback.
- How does the system handle concurrent editing when multiple users are editing the same form? System locks the form during editing - only one user can edit at a time; other users see a read-only view with a message indicating the form is being edited.
- What happens when the user tries to drag a field outside the form canvas boundaries? Field returns to original position.
- How does the system handle form data migration when field types are changed after responses have been collected? Existing response data for that field is preserved.
- What happens when the user's internet connection is lost while editing a form? Auto-save drafts are preserved in localStorage and sync when connection is restored.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a drag and drop interface for adding form fields to a form canvas
- **FR-002**: System MUST organize form field components into at least three categories: Basic, Table, and Buttons
- **FR-003**: System MUST display the component palette as a sidebar on desktop screens (width ≥ 768px)
- **FR-004**: System MUST display the component palette as a bottom bar on mobile screens (width < 768px)
- **FR-005**: System MUST allow users to drag fields from the component palette to the form canvas
- **FR-006**: System MUST allow users to reorder form fields by dragging them to new positions
- **FR-007**: System MUST display visual indicators showing where a field will be placed during drag operations
- **FR-008**: System MUST provide a configuration panel for editing field properties after fields are added to the form
- **FR-009**: System MUST allow users to configure field labels, required status, field-specific options, and validation rules
- **FR-010**: System MUST update field configurations in real-time on the form canvas as users make changes
- **FR-011**: System MUST support at least the following field types in the Basic category: text, number, email, date, textarea, checkbox, select, radio, file upload
- **FR-012**: System MUST support at least a table/grid field in the Table category with dynamic row addition/removal
- **FR-012d**: System MUST allow users to define fixed column structures for table fields (column names, types, and validation)
- **FR-012e**: System MUST allow form respondents to add and remove rows in table fields during form submission
- **FR-012a**: System MUST allow users to configure file upload fields with allowed file types and size limits
- **FR-012b**: System MUST support basic validation rules: required status, min/max length for text fields, min/max values for number fields
- **FR-012c**: System MUST support pattern validation: regex patterns for text fields, email format validation for email fields
- **FR-013**: System MUST support at least submit and reset button options in the Buttons category
- **FR-014**: System MUST allow categories to be expanded and collapsed in the component palette
- **FR-015**: System MUST provide a preview mode to view the form as it will appear to respondents
- **FR-016**: System MUST allow users to delete fields from the form with a confirmation dialog
- **FR-016a**: System MUST allow users to duplicate existing fields with a duplicate button on each field
- **FR-017**: System MUST persist field order, configurations, and form structure when the form is saved
- **FR-018**: System MUST support touch-based drag and drop gestures on mobile devices
- **FR-019**: System MUST store form field data as simple strings or arrays within strings for multiple values
- **FR-020**: System MUST provide a click-to-add interface as fallback when drag and drop is not supported
- **FR-021**: System MUST lock the form during editing so only one user can edit at a time
- **FR-022**: System MUST display a read-only view with a message when a form is being edited by another user
- **FR-023**: System MUST validate field configurations before allowing the form to be saved
- **FR-024**: System MUST provide appropriate empty state messages when no fields are added to the form
- **FR-025**: System MUST auto-save form drafts to prevent data loss during editing
- **FR-026**: System MUST display loading indicators while form data is being saved or loaded
- **FR-027**: System MUST comply with WCAG 2.1 Level AA accessibility standards

### Key Entities

- **Form**: Represents a data collection form created by users. Key attributes include name, description, structure (field definitions and order), and creation/update timestamps.
- **Form Field**: Represents an individual field within a form. Key attributes include label, field type (text, number, email, date, textarea, checkbox, select, radio, file upload, table, button), required status, position/order, and metadata (options, validation rules, allowed file types, size limits, etc.).
- **Field Category**: Represents a grouping of related field types in the component palette. Examples include Basic (text, number, email), Table (grid/table fields), and Buttons (submit, reset).
- **Form Response**: Represents data submitted by form respondents. Each response contains field values stored as strings, arrays within strings for multiple-value fields, or file references for file upload fields.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can add a field to a form using drag and drop in under 5 seconds
- **SC-002**: Users can reorder 10 form fields in under 30 seconds
- **SC-003**: Form builder interface renders within 2 seconds on initial load
- **SC-004**: 90% of users successfully create a form with at least 5 different field types on first attempt
- **SC-005**: Form builder supports up to 50 fields per form without performance degradation
- **SC-006**: Drag and drop operations complete within 500ms with visual feedback
- **SC-007**: Form preview loads within 1 second when switching from edit mode
- **SC-008**: 95% of users report the form builder is "easy to use" or "very easy to use" in user satisfaction surveys
- **SC-009**: Mobile form builder interface is fully functional on screens as small as 320px width
- **SC-010**: Auto-save drafts are preserved even if the user navigates away and returns to the form

## Assumptions

- Users are already authenticated before accessing the form builder
- The existing Form and FormField models will be extended to support new field types and configurations
- Field metadata will be stored in the existing JSONB metadata column on form_fields
- Form field order will be stored using the existing position column on form_fields
- Form responses will continue to use the existing JSONB data structure with simple string or array values
- The drag and drop functionality will use a modern web library compatible with the existing Svelte 5 frontend
- Touch-based drag and drop will use standard touch events supported by modern mobile browsers
- Auto-save functionality will use localStorage as a fallback similar to the existing implementation
- Form field validation will be performed both client-side for immediate feedback and server-side for data integrity
- The form builder will be integrated into the existing form create/edit pages (app/frontend/pages/forms/new.svelte and edit.svelte)

## Dependencies

- Existing Form and FormField models must support new field types and configurations
- Existing form routing and controller actions must handle the new form structure
- Frontend drag and drop library must be selected and integrated with Svelte 5
- Responsive design system or component library must support sidebar/bottom bar layouts
- Form validation system must support the new field types and configurations
- Auto-save functionality must be compatible with the new drag and drop interface
