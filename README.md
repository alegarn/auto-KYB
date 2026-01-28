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
	the platform-specific mechanism you prefer.
- For containerized development, review `Dockerfile` and `Procfile.dev`.

Contributing
--
- Open an issue or submit a pull request. Keep changes small and focused.

Further improvements (suggested)
--
- Add a `Makefile` or more robust `bin/dev` orchestration for local setup
- Add explicit development environment notes (exact Ruby/Node versions)
- Add CI job examples and prettier/linting config for frontend code
- Add Node.js 18+ for SSR and Vite


Files changed
--
- Updated the top-level README with setup and usage instructions.

App goal
--
This project demonstrates a simple merchant onboarding flow for a payment
company.

Use case (merchant onboarding):

- **Input:** Put the onboard forms online with a login component so merchants
	can submit their business and contact information.
- **Output:** Export collected information via email or an API so it can be
	imported into a CRM or downstream system.
- **Unique / value:** Verify submitted information by checking public
	sources (e.g., business registries, public profiles) to reduce manual review
	and improve trustworthiness of onboarding data.

The repository includes example frontend pages and components (forms, hero,
pricing, footer) that illustrate how to wire UI inputs to back-end export and
verification flows. Use these as a starting point to integrate real APIs or
connect to your CRM.

License
--
No license specified. Add a `LICENSE` file if you intend to publish.
