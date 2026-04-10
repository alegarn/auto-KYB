# Feature Specification: Dashboard Onboarding

**Feature ID**: `008-dashboard-onboarding`
**Date**: 2026-04-07
**Status**: Final
**Plan Reference**: [plans/012-onboarding-precise-plan.md](plans/012-onboarding-precise-plan.md)

## Clarifications (2026-04-07)

- **Q: How is the visual progress computed?**  
  - A: It is 33% per step for Basic (3 steps total) or 25% for Pro (4 steps total).
- **Q: Should "Demo Data" automatically mark steps as complete?**  
  - A: Yes. If a user has a demo client, the `has_clients?` check in `DashboardQuery` will return true, and the "Add a client" step will be marked as complete.
- **Q: Is there an empty state for the checklist itself?**  
  - A: No. If the checklist is empty (100% complete) or dismissed, the card is simply hidden from the dashboard.
- **Q: Can the user reopen onboarding once dismissed?**  
  - A: Yes, the user can click "Reset Onboarding" which updates `restarted_at`. It brings back the card even if 100% complete or previously dismissed without destroying user data (forms/clients).
- **Q: What happens when a tutorial step targets UI that is not visible yet?**  
  - A: The tutorial stays open and shows contextual guidance explaining how to reveal the missing control instead of silently breaking the flow.

## User Scenarios

### User Story 1 - View Onboarding Progress (Priority: P1)
As a new user, I want to see which steps I need to take next, so that I can start using the core features of the app without confusion.

**Acceptance Scenarios**:
1. **Given** a new user with only the default form, **When** they land on the Dashboard, **Then** they see the onboarding card with the "Review or create a new form" step already checked.
2. **Given** the onboarding card is visible, **When** the user is a Basic user, **Then** they see 3 actionable steps.
3. **Given** the onboarding card is visible, **When** the user is a Pro user, **Then** they see 4 actionable steps, including a CRM step.
4. **Given** the card is loading data, **When** the deferred prop hasn't resolved yet, **Then** a skeleton UI is displayed to prevent layout shift.

### User Story 2 - Move from Quick to Detailed Guidance (Priority: P1)
As a user, I want to read more about a specific step if I'm not sure what it does, so I can understand the KYB workflow in depth.

**Acceptance Scenarios**:
1. **Given** the onboarding card is visible, **When** the user clicks "View Details", **Then** the Detailed Onboarding Sheet opens from the side.
2. **Given** the Detailed Onboarding Sheet is open, **When** the user clicks a step link (e.g., "Add a client"), **Then** they are navigated to the correct workspace page.
3. **Given** the user opens the sheet for the first time, **When** the sheet is opened, **Then** a background request marks the detailed view as "seen" to suppress new indicators.

### User Story 3 - Dismissing Onboarding (Priority: P2)
As an experienced user, I want to remove the onboarding guide once I'm comfortable with the app, so I can reclaim my dashboard space.

**Acceptance Scenarios**:
1. **Given** the onboarding card is visible, **When** the user clicks "Dismiss", **Then** the card is removed from the UI immediately.
2. **Given** the card was dismissed, **When** the page is refreshed, **Then** the card remains hidden.
3. **Given** the user completes all steps, **When** they return to the Dashboard, **Then** the card is automatically hidden even if they didn't click "Finish Tutorial".

### User Story 4 - Practice Interactive Tutorials (Priority: P2)
As a user, I want to practice key onboarding actions directly on the real product pages, so I can learn the workflow without leaving the app context.

**Acceptance Scenarios**:
1. **Given** the user opens the Explore tab from detailed onboarding, **When** they launch a practice card, **Then** they are taken to the real destination page with the tutorial overlay active.
2. **Given** a tutorial is active, **When** the user clicks "Quit tutorial", **Then** the overlay closes immediately and the current page stays loaded.
3. **Given** a tutorial step points to a control that is not visible yet, **When** the step becomes active, **Then** the overlay shows contextual guidance explaining how to reveal that control.
4. **Given** a practice flow depends on an existing client record, **When** no concrete client page is available yet, **Then** that practice card remains unavailable and explains why.

## Requirements mapping to Implementation

| Requirement | Implementation |
|-------------|----------------|
| **FR-01 (Business Progress)** | `DashboardQuery#onboarding_summary` derived from DB records. |
| **FR-01 (UI Persistence)** | `OnboardingTracking` concern writing to `users.onboarding_state`. |
| **FR-02 (Visibility)** | `Dashboard.svelte` conditional dynamic import. |
| **FR-02 (Variants)** | `onboarding.variant` decides between 3-step or 4-step layout. |
| **FR-03 (Side Sheet)** | `DashboardOnboardingDetailsSheet.svelte` using shared Sheet components. |
| **FR-04 (Interactive Mini-Tutorials)** | `onboarding-tutorials.ts`, `OnboardingTutorialHost.svelte`, and real-page `data-onboarding-tutorial` targets. |
| **Performance** | `InertiaRails.defer` + `router.patch` (dismiss) + Svelte lazy-load. |
