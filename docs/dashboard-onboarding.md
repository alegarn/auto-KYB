# Technical Documentation: Dashboard Onboarding

**Feature ID**: `008-dashboard-onboarding`
**Date**: 2026-04-07
**Status**: Final
**Plan Reference**: [plans/012-onboarding-precise-plan.md](plans/012-onboarding-precise-plan.md)

## Purpose

The Dashboard Onboarding is a contextual, non-blocking guidance system designed to reduce "Time to Value" (TTV) for new users. It replaces empty-state friction with an actionable checklist and a detailed side-panel (Sheet) that explains the core KYB workflow.

### Success Criteria

- **Reduced TTV**: Users can identify the next 3 steps of the core workflow within 5 seconds of first login.
- **Zero Performance Regression**: Returning users who have completed or dismissed onboarding do not load the onboarding JS bundle.
- **Clean Separation**: Product onboarding state is distinct from account/auth onboarding (`onboarding_completed`).
- **Data Integrity**: Progress is derived from real domain records (Forms, Clients, Invitations), not just persisted booleans.

## Functional Requirements

### FR-01: Progress Tracking
- **Business Progress**: Must be computed at runtime based on:
    - `form`: User has at least one Workspace Form.
    - `client`: User has at least one Client.
    - `invite`: User has at least one `ClientForm` (invitation).
    - `crm` (Pro only): User has an active, authenticated CRM connection.
- **UI State Persistence**: Dismissal and "detailed view seen" state must be persisted in `users.onboarding_state` (JSONB).
- **Versioning**: Supports an `onboarding_state.version` (current: `1`) to allow resetting/updates for all users. 
    - **Logic**: If the persisted version is lower than the current application version, any existing `dismissed_at` or `detailed_view_seen_at` timestamps are ignored for visibility but preserved for history.
- **Automatic Completion**: The onboarding UI automatically hides when all steps contributing to its progress calculation are 100% complete.

### FR-02: User Experience (Checklist Card)
- **Visibility**: Displayed at the top of the Dashboard for eligible users.
- **Variants**:
    - **Basic**: 3 steps (`form`, `client`, `invite`).
    - **Pro**: 4 steps (adds `crm`).
- **intelligent Deep-Linking**:
    - Each step provides a context-aware link (`href`).
    - Example: The "Review or create a new form" step points to the most recently updated form's edit page if a form exists, otherwise to the form creation page.
- **Dismissal**: Users can permanently hide the card. Dismissal is version-scoped.

### FR-03: Detailed Guidance (Side Sheet)
- **Discovery**: Opened via a "View Details" call-to-action on the checklist card.
- **Content**: Provides rich text descriptions and direct actions for each onboarding step.
- **Tracking**: Opening the sheet marks `detailed_view_seen_at`. 
- **Guide Tracking**: Opening a guide from the `Explore` tab records the guide key in `users.onboarding_state.guides_seen` so the UI can show which editorial paths were already visited.

### FR-04: Interactive Mini-Tutorials
- **Scope**: The "Explore" tab can launch focused practice tutorials for forms, client workflow, and CRM sync.
- **Real Screens**: Tutorials run on the real product pages instead of a mocked walkthrough so users can immediately apply the action they are reading about.
- **One-Click Exit**: Every tutorial exposes a `Quit tutorial` action that closes the overlay without a server round-trip.
- **Missing Target Guidance**: When a tutorial step points at UI that is not visible yet, the overlay shows a contextual helper message instead of failing silently.
- **Contextual Availability**: A guide can expose disabled practice cards with a reason when the required real data is not available yet. Example: client export practice remains unavailable until a concrete client record exists.
- **No Persistent UI State**: Tutorial step progress stays client-side. Product progress continues to be derived from real Rails domain records.

## Technical Architecture

- **Backend Aggregation**: 
    - `DashboardQuery`: Aggregates derived progress, variant selection (`Basic` vs `Pro`), and UI state into a single `onboarding_summary` payload.
- **Persistence Layer**:
    - `OnboardingTracking` (Concern): Encapsulates `JSONB` schema, default keys (`dismissed_at`, `detailed_view_seen_at`, `demo_seeded_at`, `restarted_at`, `data_exported_at`, `guides_seen`, `version`), and atomic updates via `with_lock`.
- **Mutation Endpoints**:
    - `OnboardingController` owns the UI-state mutations (`dismiss`, `details_seen`, `guide_seen`, `reset`) and rejects invalid guide keys with `422` instead of silently reporting success.
- **Frontend Performance**:
    - **Inertia Defer**: The onboarding payload is sent as a deferred prop.
    - **Lazy Chunking**: The `DashboardOnboardingCard` is dynamically imported via an effect only if `visible: true`.
    - **Lazy Tutorial Runtime**: The tutorial overlay is dynamically imported only when the current URL includes `onboarding_tutorial=...`.
    - **Fallback UI**: A skeleton state is rendered during the component chunk load or during the deferred data fetch.
    - **Failure Handling**: If the onboarding chunk fails to load or the data fetch errors, the dashboard continues to render the rest of the application gracefully.

## Interactive Tutorial Architecture

- **Guide Content**: The dashboard sheet still owns editorial content (guide titles, explanations, tips), but interactive practice cards are resolved from existing onboarding step hrefs.
- **Launch Mechanism**: A practice card appends `onboarding_tutorial` to the destination URL and navigates through the normal Inertia flow.
- **Runtime Host**: `AuthenticatedLayout` lazy-loads a lightweight `OnboardingTutorialHost` only when that query parameter is present.
- **Target Resolution**: Product pages expose narrowly scoped `data-onboarding-tutorial` markers on existing controls. The host highlights those controls and can optionally focus, scroll, or click them.
- **Exit Behavior**: Exiting a tutorial removes the query parameter with `history.replaceState`, preserving unsaved page state, and the authenticated layout reacts to that browser URL change immediately so the overlay closes without a reload.

## Testing Strategy

- **Controller Specs**: Rails controller specs cover the onboarding UI mutations, including guide tracking validation and reset behavior.
- **Guide UI**: Frontend component tests cover the Explore tab, contextual launch links, and disabled practice states.
- **Guide Tracking UI**: Frontend component tests cover the `Explore` tab mutation that marks a guide as seen and close the sheet cleanly to avoid teardown leaks in the shared `bits-ui` sheet runtime.
- **Tutorial Helpers**: Frontend unit tests cover tutorial URL generation and contextual availability rules.
- **Tutorial Host**: Frontend component tests cover target focus/click helpers and the one-click exit path.
- **System Specs**: Rails system specs cover launching each real tutorial family from the dashboard, including export-oriented practice cards and fallback guidance when a targeted control is not currently available.

## User Scenarios

### User Story 1: First-Time Login (Basic Plan)
**Given** a new user on the Basic plan has just signed up
**When** they land on the Dashboard
**Then** they see a "Launch your first client workflow" checklist with 3 steps
**And** the "Review or create a new form" step is marked as complete (due to auto-created default form)

### User Story 2: Completing the Workflow
**Given** the user has completed all 3-4 steps (Forms, Clients, Invitations, CRM)
**When** the Dashboard is rendered
**Then** the onboarding card is hidden automatically without requiring manual dismissal.

### User Story 3: Pro Variant visibility
**Given** a user is on a Pro plan (CRM Entitlement allowed)
**When** they view the Dashboard
**Then** they see a 4th "Connect your CRM" step in the checklist.

### User Story 4: Versioned Reset
**Given** a user had dismissed version 0 of onboarding
**When** the system version is bumped to 1
**Then** the user sees onboarding again on their next dashboard visit.
