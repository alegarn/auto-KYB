# quick-kyb

Quick KYB is a client onboarding tool built for payment providers. The application uses Ruby on Rails with a Svelte + Vite frontend (integrated
via Inertia/Vite). It provides the scaffolding for a modern web app combining
Ruby on Rails back-end conventions with a fast Svelte frontend.

This README contains the minimal steps to get the project running locally,
project layout highlights, and quick commands for development and testing.

Prerequisites
--
- Ruby 3.x (use mise/rvm as preferred)
- Rails 8.1+ (bundled via `Gemfile`)
- npm
- PostgreSQL (or the DB configured in `config/database.yml`)

Quickstart (development)
--
1. Install Ruby gems and JavaScript dependencies:

```bash
bundle install
npm install
```

2. Create and prepare the database:

```bash
bin/rails db:create db:migrate db:seed
```

3. Run the app (concurrently starts Rails and Vite if `bin/dev` exists):

```bash
bin/dev
# or if you prefer just Rails: bin/rails server
```

4. Visit http://localhost:3000 (or the port printed by the server).

Project structure (high level)
--
- `app/` — Rails application code (models, controllers, views, jobs, mailers)
- `frontend/` — Svelte frontend sources, Vite entrypoints, components and types
- `config/` — Rails configuration, environment files and initializers
- `bin/` — useful scripts (e.g., `bin/dev`, `bin/rails`)
- `Procfile.dev`, `Dockerfile` — development and containerization helpers

Common tasks
--
- Run tests:

```bash
bin/rails test
```

- Run RuboCop (if present):

```bash
bundle exec rubocop
```

- Start only the frontend dev server (inside `frontend` if you prefer):

```bash
cd frontend
yarn dev
```

Notes & tips
--
- The repo integrates Vite + Svelte under `frontend/`; Svelte components live
	in `frontend/pages` and `frontend/components`.
- Environment and secrets: use Rails credentials (`bin/rails credentials:edit`) or
	# quick-kyb

	Quick KYB is a client onboarding tool built for payment providers. The
	application uses Ruby on Rails with a Svelte + Vite frontend (integrated via
	Inertia/Vite). It provides scaffolding for a modern web app combining Rails
	back-end conventions with a fast Svelte frontend.

	This README contains the minimal steps to get the project running locally,
	project layout highlights, and quick commands for development and testing.

	Prerequisites
	--
	- Ruby: 3.4.8 (see `.ruby-version`)
	- Rails: ~> 8.1 (declared in `Gemfile`)
	- Node.js: Recommended 18+ (Vite and modern Svelte tooling work best on Node 18+)
	- npm (or Yarn/PNPM if you prefer)
	- PostgreSQL (or the DB configured in `config/database.yml`)

	Quickstart (development)
	--
	1. Install Ruby gems and JavaScript dependencies:

	```bash
	bundle install
	npm install
	```

	2. Create and prepare the database:

	```bash
	bin/rails db:create db:migrate db:seed
	```

	3. Run the app (recommended):

	`bin/dev` is provided to orchestrate the Rails and frontend dev servers together. It prefers `overmind` or `hivemind` if installed, otherwise it will install and use `foreman`.

	```bash
	bin/dev
	# or run services individually:
	# Start Rails only: bin/rails server
	# Start Vite frontend only: bin/vite dev
	# or bin/setup to setup and start the app
	```

	`Procfile.dev` defines the concurrent processes used by `bin/dev`:

	- `vite: bin/vite dev`
	- `web: bin/rails s`

	4. Visit http://localhost:3000 (or the port printed by the server).

	Project structure (high level)
	--
	- `app/` — Rails application code (models, controllers, views, jobs, mailers)
	- `frontend/` — Svelte frontend sources, Vite entrypoints, components and types
	- `config/` — Rails configuration, environment files and initializers
	- `bin/` — useful scripts (e.g., `bin/dev`, `bin/rails`, `bin/vite`)
	- `Procfile.dev`, `Dockerfile` — development and containerization helpers

	Database configuration
	--
	This project uses PostgreSQL by default. See `config/database.yml` for
	database names and connection options. By default:

	- Development DB: `quick_kyb_development`
	- Test DB: `quick_kyb_test`
	- Production DB: `quick_kyb_production` (configured to read password from env vars)

	Environment variables
	--
	- `DATABASE_URL` — optional full database connection URL (overrides `config/database.yml`)
	- `QUICK_KYB_DATABASE_PASSWORD` — used in `config/database.yml` for production
	- `PORT` — `bin/dev` and `bin/rails` respect `PORT` (defaults to 3000)

	Common tasks
	--
	- Install deps: `bundle install && npm install`
	- Create DB & migrate: `bin/rails db:create db:migrate db:seed`
	- Run all dev services: `bin/dev`
	- Rails only: `bin/rails server`
	- Vite frontend only: `bin/vite dev`

	Frontend (npm scripts)
	--
	From the repository root you can run frontend tooling using `npm`:

	- `npm run check` — run `svelte-check` and `tsc` type checks
	- `npm run lint` — ESLint for `app/frontend`
	- `npm run lint:fix` — run eslint with `--fix`
	- `npm run format` — run Prettier check
	- `npm run format:fix` — fix formatting with Prettier
	- `npm run test:unit` — run Vitest unit tests
	- `npm run test:unit:ui` — run Vitest with UI
	- `npm run test:unit:coverage` — run Vitest and produce coverage
	- `npm run storybook` — start Storybook on port 6006
	- `npm run build-storybook` — build Storybook static site

	Testing and linting
	--
	- Rails tests: `bin/rails test` (or use `rspec` if configured)
	- Frontend unit tests: `npm run test:unit`
	- System / E2E tests: see `spec/` and test-related gems in the `Gemfile`

	Docker & deployment
	--
	There is a `Dockerfile` and a `Procfile.dev` for local development orchestration. For containerized deployments, review `Dockerfile` and any platform-specific deployment scripts (e.g., `kamal` integration referenced in the `Gemfile`).

	Notes & tips
	--
	- The repo integrates Vite + Svelte under `frontend/`; Svelte components live in `frontend/pages` and `frontend/components`.
	- `bin/dev` prefers `overmind` or `hivemind` and falls back to `foreman` (it will attempt to install `foreman` if missing).
	- Use Rails credentials for secrets: `bin/rails credentials:edit`.
	- Recommended Node version: 18+ for best compatibility with Vite and modern Svelte tooling.

	Contributing
	--
	- Open an issue or submit a pull request. Keep changes small and focused.

	Further improvements (suggested)
	--
	- Add a `Makefile` or more robust `bin/dev` orchestration for local setup
	- Add explicit CI examples and recommended exact development runtime versions
	- Add a `LICENSE` if publishing the repo

	Files changed
	--
	- Updated the top-level README with setup and usage instructions, exact Ruby version, and developer-friendly commands for running services, tests, and linters.

	App goal
	--
	This project demonstrates a simple merchant onboarding flow for a payment company.

	Use case (merchant onboarding):

	- **Input:** Put the onboard forms online with a login component so merchants can submit their business and contact information.
	- **Output:** Export collected information via email or an API so it can be imported into a CRM or downstream system.
	- **Unique / value:** Verify submitted information by checking public sources (e.g., business registries, public profiles) to reduce manual review and improve trustworthiness of onboarding data.

	The repository includes example frontend pages and components (forms, hero, pricing, footer) that illustrate how to wire UI inputs to back-end export and verification flows. Use these as a starting point to integrate real APIs or connect to your CRM.

	License
	--
	- No license specified. Add a `LICENSE` file if you intend to publish.
