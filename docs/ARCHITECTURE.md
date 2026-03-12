# Quick KYB - Architecture

## Overview

Quick KYB is a hybrid Rails + Vite/Svelte application. The backend is a Ruby on Rails app providing background jobs, and a PostreSQL database. The frontend uses Vite and Inertia Rails to build and serve Svelte components. Storybook is used for UI development, RSpec for backend tests, and Vitest for frontend unit tests.

## Components

- **Backend (Rails)**: code under `app/` (controllers, models, services, jobs, mailers, serializers).
  - **CRM Integration Subsystem**: Modular provider mapping layers (`app/services/crm/[provider]/`). New CRMs implement a `FieldMapper` inheriting from `Crm::FieldMapper`. See [CRM Field Mapping Guide](crm-field-mapping.md).
- **Frontend (Vite + Svelte)**: source under `src/` and `app/frontend/` with Storybook stories in `stories/`. Built with `vite.config.ts` and integrated into Rails via Vite plugin/config in `config/vite.json`.
- **Assets & Public**: static assets in `public/` and compiled frontend assets in `app/assets` and `public/vite-ssr` when SSR is used.
- **Background Workers**: jobs live in `app/jobs/` and queue configuration in `config/queue.yml` (Sidekiq or ActiveJob adapter configured in environment files).
- **Tests**: RSpec for Rails (spec/), Vitest for frontend (vitest.config.ts), + additional integration/system specs in `spec/system`.

## Data Flow

1. Client (browser) loads Svelte SPA or server-rendered page.
2. Frontend calls Rails JSON APIs (controllers -> services -> models -> serializers).
3. Long-running tasks are enqueued as background jobs and processed by worker pool.
4. Persistence in PostgreSQL (or DB configured in `config/database.yml`).

## Integration Points

- API endpoints: defined in `config/routes.rb` and implemented in `app/controllers`.
- Shared types/interfaces: `src/types/` for frontend types; consider generating or syncing types from backend contracts if needed.
- Storybook: component playground for Svelte components in `stories/` and `src/`.

## Local Development

- Start Rails server: `bin/rails server` (or use Procfile.dev / kamal for orchestrated dev). 
- Start Vite in watch mode: `npm run dev` (see `package.json` scripts).
- Run tests: `bundle exec rspec` for backend, `pnpm|npm run test` (Vitest) for frontend.

## Deployment

- Containerization: `Dockerfile` and `docker-entrypoint` exist for building images.
- Process management: `puma` for web, background workers for jobs, deployment orchestration via `kamal`/`Procfile` or standard container deploy.

## Observability & Security

- Logs: standard Rails logs in `log/`.
- Security: code-level checks and scanning tasks are present (see `bin/` helpers like `brakeman`, `bundler-audit`).

## Notes & Recommendations

- Keep API contracts stable; add automated contract tests if frontend/backend decouple further.
- Consider centralizing environment and deployment docs in `docs/` or `plans/`.

---
See the architecture diagram: `docs/architecture.mmd`.
