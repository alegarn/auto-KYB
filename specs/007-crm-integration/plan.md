# Implementation Plan: [FEATURE]

**Branch**: `[007-crm-integration]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[007-crm-integration]/spec.md`

## Summary

Implement an external CRM integration to synchronize client records and field mappings between Quick‑KYB and third‑party CRMs (initial rollout: Salesforce/HubSpot compatibility). The feature provides:

- Server-side sync: push created/updated clients and scheduled pulls where supported.
- Administrative UI: configure per‑environment field mappings, mapping previews, and manual sync triggers.
- Reliable background processing with idempotency, retries, audit logging, and webhook handlers for inbound events.
- Contract tests and OpenAPI-driven integration checks to validate mappings and error handling.

This approach minimizes frontend changes by centralizing mapping and sync logic in backend services and background jobs.

## Technical Context

**Language/Version**: Ruby 3.x, Ruby on Rails 8.1 (backend); Svelte 5 + Vite (frontend)

**Primary Dependencies**: Rails, Inertia (inertia_rails), ActiveRecord, ActiveStorage, PostgreSQL, a background job processor (ActiveJob with SolidQueue), Faraday/HTTParty for CRM HTTP client, dotenv-rails for env config

**Storage**: PostgreSQL (primary persistent store); ActiveStorage for file attachments

**Testing**: Rspec for Rails tests (project contains tests/), TypeScript frontend tests (.spec.ts) via Jest/Vitest patterns; contract tests driven from OpenAPI (`specs/007-crm-integration/contracts/openapi.yaml`:1)

**Target Platform**: Linux servers / Docker / Heroku-compatible deployments

**Project Type**: Web application (Rails backend + Svelte frontend via Inertia)

**Performance Goals**: Keep standard API endpoints <200ms p95; CRM syncs executed as background jobs within rate limits and completed within operational SLAs (configurable batch sizes)

**Constraints**: GDPR-sensitive data handling, idempotent delivery for webhooks, retry/backoff for transient CRM errors, minimal schema changes to client model where possible

**Scale/Scope**: Initial support for small-to-medium customer bases; design for horizontal scaling of background workers and safe reprocessing of historical syncs

### Manifests

**Gemfile highlights (not exhaustive)**
- rails (~> 8.1.2)
- pg (PostgreSQL adapter)
- solid_queue, solid_cache, solid_cable (queue/cache/cable adapters)
- dotenv-rails (environment config)
- inertia_rails, vite_rails (frontend/Inertia integration)
- rspec-rails (development/test), factory_bot_rails (test fixtures)
- capybara, capybara-lockstep, selenium-webdriver (system/browser tests)
- aws-sdk-s3 (ActiveStorage production adapter)
- bootsnap, kamal, thruster (performance/deploy/runtime helpers)
- brakeman, rubocop, rubocop-rails (security/static analysis / linting)

Refer to [`Gemfile`](Gemfile:1) for full gem versions and groups.

**package.json highlights (not exhaustive)**
- svelte (^5) and @inertiajs/svelte (frontend integration)
- vite, vite-plugin-ruby (build tooling)
- vitest, @vitest/ui, @vitest/coverage-v8 (frontend unit tests)
- @testing-library/svelte, @testing-library/jest-dom (testing helpers)
- playwright, jsdom (e2e/headless testing)
- storybook and Storybook addons (UI component development)

Refer to [`package.json`](package.json:1) for full dependency list and scripts.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Code Quality (Principle I)
- [x] Code follows Ruby on Rails community standards
- [x] Code passes RuboCop linting with project-specific rules
- [x] Code is self-documenting with clear variable and method names
- [x] Complex logic is extracted into well-named methods or service objects
- [x] Public methods have documentation comments

### DRY (Principle II)
- [x] Code duplication is eliminated through proper abstraction
- [x] Common functionality is extracted into shared modules, concerns, or service objects
- [x] Views use partials and components for repeated UI patterns
- [x] Database queries are scoped and reused

### Convention Over Configuration (Principle III)
- [x] Ruby on Rails conventions for naming, file structure, and patterns are followed
- [x] Custom configurations are only used when conventions cannot meet requirements
- [x] Rails generators and standard directory structure are used
- [x] RESTful routing conventions are followed

### MVC Architecture (Principle IV)
- [x] Models contain business logic and data access rules
- [x] Controllers are thin, handling only request/response orchestration
- [x] Views are presentation logic only, with no business logic
- [x] Cross-cutting concerns use concerns, services, or decorators appropriately

### RESTful Design (Principle V)
- [x] API endpoints follow RESTful conventions with appropriate HTTP verbs
- [x] Resources are nouns and actions are verbs
- [x] Standard Rails resource routing is used
- [x] Responses have appropriate status codes
- [x] API is stateless with proper HTTP caching headers

### Test-Driven Development (Principle VI) - NON-NEGOTIABLE
- [x] Tests are written before implementation code (Red-Green-Refactor cycle)
- [x] All features have corresponding tests
- [x] Tests cover happy paths, edge cases, and error conditions
- [x] Test suite runs quickly and reliably
- [x] Integration tests cover critical user journeys
- [x] Unit tests cover business logic

### Quality Standards
- [x] User interfaces follow consistent design patterns and components
- [x] Shared Svelte components from `app/frontend/components/ui/` are used
- [x] Consistent color schemes, typography, and spacing are maintained
- [x] User-facing text is clear, concise, and uses consistent terminology
- [x] Loading states and error messages are consistent
- [x] UI is responsive and works across device sizes
- [x] Accessibility compliance (WCAG 2.1 AA minimum) is ensured

### Performance Requirements
- [x] API endpoints respond within 200ms (p95) for standard operations
- [x] Page loads complete within 2 seconds on 3G connections
- [x] Database queries are optimized with proper indexing
- [x] N+1 queries are eliminated through eager loading
- [x] Frontend bundle size is optimized through code splitting
- [x] Images and assets are optimized and lazy-loaded
- [x] Appropriate caching is implemented at multiple levels

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

app/
├── controllers/
│   ├── client_portal/
│   ├── identity/
│   └── (other controllers...)
├── models/
├── services/
├── jobs/
├── serializers/
├── views/
├── frontend/                # Svelte + Inertia assets (app/frontend/)
│   └── components/
config/
├── initializers/
db/
├── migrate/
public/
bin/
scripts/
specs/
├── 007-crm-integration/
test/
├── frontend/
├── controllers/
└── (other test categories)
storage/
docs/
.specify/

(Note: top-level files such as `Gemfile` and `package.json` are present but omitted from this folders-only listing.)


**Structure Decision**: Web application monorepo: primary Rails app under `app/` with supporting config and infra at repository root; Svelte frontend integrated via Inertia within the Rails app. The CRM integration will primarily modify `app/services/`, `app/models/`, `app/controllers/`, add background job workers in `app/jobs/`, serializers in `app/serializers/`, database migrations in `db/migrate/`, and add contract/tests under `specs/007-crm-integration/`.


## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
