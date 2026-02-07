# Subspace Plan (Client Portal)

Date: 2026-02-04

## Objective
Create a dedicated client subspace where a user links a form to a client, generates a password, and the client can log in to complete the form with partial saves until validation. After validation, the linked form response is locked and marked as validated.

## Current Codebase Constraints (Observed)
- `Client` belongs to `User` only (no form link). See [app/models/client.rb](app/models/client.rb).
- `Form` belongs to `User` and uses `structure` + `form_fields` (not a JSON schema field). See [app/models/form.rb](app/models/form.rb) and [app/models/form_field.rb](app/models/form_field.rb).
- Inertia pages use mixed casing: `forms/*` and `Clients/*`. See [app/controllers/forms_controller.rb](app/controllers/forms_controller.rb) and [app/controllers/clients_controller.rb](app/controllers/clients_controller.rb).
- Authentication is session-based with `Session` and `Current`. See [app/models/session.rb](app/models/session.rb) and [app/models/current.rb](app/models/current.rb).

## Plan Judgment (Current Draft)
- **Overall fit:** B → A‑ after adjustments
- **Why:** Correct direction, but needed alignment with existing `structure`/`form_fields`, controller naming, and a join model instead of adding `form_id` on `clients`.
- **Strengths:** Additive design, clear separation of portal auth, reuse of existing serializers.
- **Gaps fixed below:** TDD flow, phased tasks, and explicit Rails principles.

## Rails Principles (Enforced)
- **DRY:** reuse serializers/services, keep shared logic in models/concerns
- **CoC:** standard REST routes, naming aligned with Rails conventions
- **MVC:** thin controllers, business logic in models/services
- **REST:** use `show/update` for portal form, avoid custom verbs unless needed

## Key Adjustments to Fit the Codebase
1. **Use a join model (`ClientForm`) instead of `form_id` on `clients`.**
   - Allows linking multiple forms to a client over time without mutating the client model.
2. **Reuse existing form definition (`structure` + `form_fields`).**
   - The client portal renders fields from `FormDetailSerializer`.
3. **Add new controllers and pages without changing existing `ClientsController` or `FormsController`.**
   - Avoid regressions in current UI and routes.
4. **Follow current Inertia naming conventions.**
   - New client-portal pages should be under `ClientPortal/*` and excluded from authenticated sidebar layout in [app/frontend/entrypoints/inertia.ts](app/frontend/entrypoints/inertia.ts).

---

## Updated Domain Model
### New Models

### `ClientForm`
- `id: uuid`
- `client_id: uuid` (FK)
- `form_id: uuid` (FK)
- `status: integer` enum (`draft`, `filled`, `validated`)
- `password_digest: string`
- `access_token: string`
- `expires_at: datetime`
- `validated_at: datetime`
- timestamps

### `FormResponse`
- `id: uuid`
- `client_form_id: uuid` (FK)
- `data: jsonb`
- `version: integer`
- timestamps

### Relationships
- `User` has many `clients`, `forms` (unchanged).
- `Client` has many `client_forms` (new).
- `Form` has many `client_forms` (new).
- `ClientForm` belongs to `client` and `form`.
- `ClientForm` has many `form_responses`.

---

## Routes (Additive)
```ruby
# config/routes.rb
resources :client_forms, only: [:create, :show, :destroy] do
  member do
    get :password_reveal
  end
end

namespace :client_portal do
  get  "login/:access_token", to: "sessions#new", as: :login
  post "login/:access_token", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  resource :form_response, only: [:show, :update]
end
```

---

## Controllers (New)
### `ClientFormsController`
Responsibilities:
- Create link between existing client and form
- Generate `access_token` + `password_digest`
- One-time password reveal page
- Soft revoke (optional) by destroying `ClientForm`

### `ClientPortal::SessionsController`
Responsibilities:
- Login using `access_token` + password
- Set signed cookie `client_form_session`
- Logout clears cookie

### `ClientPortal::FormResponsesController`
Responsibilities:
- Show form fields (via `FormDetailSerializer`)
- Partial save to `FormResponse` (versioned)
- Validation action (locks the `ClientForm`)

---

## Inertia Pages (New)
1. `app/frontend/pages/ClientPortal/Login.svelte`
2. `app/frontend/pages/ClientPortal/FormResponse.svelte`
3. `app/frontend/pages/Clients/PasswordReveal.svelte`

Notes:
- These pages should **not** use sidebar layout (exclude from authenticated pages list in [app/frontend/entrypoints/inertia.ts](app/frontend/entrypoints/inertia.ts)).

---

## Serializers (Reuse Existing)
- `FormDetailSerializer` provides `form_fields` and `structure` to render client form.
- Add `ClientFormSerializer` for portal usage (new).

---

## Services (Optional, Recommended)
### `ClientInvitationService`
- Inputs: `client_id`, `form_id`, `expires_in`
- Creates `ClientForm` + password + access token
- Returns one-time password for reveal page

---

## Migration Plan
1. Create `client_forms` table (FKs to `clients` and `forms`)
2. Create `form_responses` table (FK to `client_forms`)
3. Add indexes:
   - `client_forms` on `client_id`, `form_id`, `access_token`
   - `form_responses` on `client_form_id`, `version`

---

## Status Workflow
- `draft`: no data or partial data
- `filled`: at least one `FormResponse` saved
- `validated`: client confirms final submission (locks the link)

State transitions:
- On save: `draft` → `filled`
- On validate: `filled` → `validated` (sets `validated_at`)

---

## Security Hardening (Aligned to Stack)
1. **One-time password reveal page** (store in encrypted session, not flash)
2. **Rate limiting** for portal login (rack-attack)
3. **Signed cookies** for client portal sessions
4. **Expiration** enforced via `expires_at`
5. **Lock after validation** via `validated_at`

---

## Implementation Phases (TDD-First, Simple Tasks)
Each phase follows **Test → Code → Refactor**. Tasks are explicit to avoid ambiguity.

### Phase 0 — Baseline & Naming Alignment
**Goal:** ensure naming and layouts align with existing Svelte/Inertia patterns.
- Test:
   - Add routing spec asserting these paths resolve: `/client_portal/login/:access_token`, `/client_portal/form_response`.
- Code:
   - Add route placeholders only if specs require them (no controller logic yet).
   - Ensure `ClientPortal/*` pages are excluded from sidebar layout in [app/frontend/entrypoints/inertia.ts](app/frontend/entrypoints/inertia.ts).
- Refactor:
   - None.

### Phase 1 — Migrations (TDD)
**Goal:** introduce data structures only.
- Test:
   - Add schema expectations for `client_forms` and `form_responses` tables.
   - Expect indexes on `client_forms.access_token`, `client_forms.client_id`, `client_forms.form_id`.
   - Expect index on `form_responses.client_form_id` and `form_responses.version`.
- Code:
   - Create migration `create_client_forms` with columns: `client_id`, `form_id`, `status` (integer, default 0), `password_digest`, `access_token`, `expires_at`, `validated_at`, timestamps.
   - Create migration `create_form_responses` with columns: `client_form_id`, `data` (jsonb), `version` (integer), timestamps.
- Refactor:
   - Ensure `status` default and null constraints are set consistently.

### Phase 2 — Models & Associations (TDD)
**Goal:** add models with validations and simple scopes.
- Test:
   - `ClientForm` validates presence of `client` and `form`.
   - `ClientForm` enum `status` values: `draft`, `filled`, `validated`.
   - `ClientForm#locked?` true when `validated_at` present or `expires_at` in past.
   - `FormResponse` sets incremental `version` per `client_form`.
- Code:
   - Add `ClientForm` model with `belongs_to :client`, `belongs_to :form`, `has_secure_password`, `has_secure_token :access_token`.
   - Add `FormResponse` model with `belongs_to :client_form`, `before_create` to set `version`.
   - Add associations on `Client` and `Form` to `client_forms` and `form_responses` (through `client_forms`).
- Refactor:
   - Extract `set_version` method on `FormResponse`.

### Phase 3 — Linking Flow (User Side) (TDD)
**Goal:** allow users to link a form to a client and generate credentials.
- Test:
   - Request spec: POST `client_forms#create` creates `ClientForm` for current user’s client/form.
   - Request spec: redirects to `password_reveal` and stores one-time password in session.
   - Request spec: `password_reveal` works once and then expires.
- Code:
   - Add `ClientFormsController` with `create` and `password_reveal` actions.
   - In `create`, generate password and store in encrypted session with 5‑minute TTL.
   - In `password_reveal`, render `Clients/PasswordReveal` with `client`, `form`, `access_url`, `password`.
- Refactor:
   - Add `ClientInvitationService` to encapsulate `ClientForm` creation + password generation.

### Phase 4 — Client Portal Auth (TDD)
**Goal:** password-based login via access token.
- Test:
   - Request spec: POST login with valid `access_token` + password sets signed cookie.
   - Request spec: invalid password returns error and does not set cookie.
- Code:
   - Add `ClientPortal::SessionsController` with `new`, `create`, `destroy`.
   - Store `client_form_session` in signed, HTTP‑only cookie.
   - Add `ClientPortal::BaseController` to load `Current.client_form` from cookie.
- Refactor:
   - Extract `authenticate_client_form!` in base controller.

### Phase 5 — Form Response Save (TDD)
**Goal:** partial save and render using existing form structure.
- Test:
   - Request spec: `show` returns `form` payload with `form_fields`.
   - Request spec: `update` creates `FormResponse` with `data` and increments `version`.
- Code:
   - Add `ClientPortal::FormResponsesController#show` and `#update`.
   - Use `FormDetailSerializer` to provide form fields.
   - Set `ClientForm` status to `filled` on first save.
- Refactor:
   - Keep `data` validation in model or service (no controller logic).

### Phase 6 — Validation & Lock (TDD)
**Goal:** validation locks the client form.
- Test:
   - Request spec: `update` with `form_response[validate]=true` sets `validated_at` and `status=validated`.
   - Request spec: further updates are blocked when locked.
- Code:
   - In `FormResponsesController#update`, branch on `validate` flag.
   - Clear `client_form_session` cookie after validation.
- Refactor:
   - Add `ClientForm#validate!` and `ClientForm#locked?`.

### Phase 7 — Frontend Pages (TDD)
**Goal:** minimal UI for login, response, and password reveal.
- Test:
   - Add Storybook stories or Svelte component tests for `ClientPortal/Login` and `ClientPortal/FormResponse`.
   - Assert form renders fields by type (`text`, `number`, `date`, etc.).
- Code:
   - `ClientPortal/Login.svelte`: form with password input and submit button.
   - `ClientPortal/FormResponse.svelte`: render fields using `form.form_fields` data.
   - `Clients/PasswordReveal.svelte`: one‑time credentials display.
- Refactor:
   - Extract `FormFieldRenderer.svelte` if more than 3 field types.

### Phase 8 — Security Hardening (TDD)
**Goal:** safe password reveal + rate limiting.
- Test:
   - Request spec: password reveal only works once and expires in 5 minutes.
   - Request spec: rate limiting returns 429 after threshold.
- Code:
   - Implement one-time password storage in encrypted session.
   - Add `rack-attack` gem and initializer with login throttles.
- Refactor:
   - Move throttle configs to `config/initializers/rack_attack.rb`.

---

## Deliverables Summary
- **2 new tables** (`client_forms`, `form_responses`)
- **3 controllers** (`ClientFormsController`, `ClientPortal::SessionsController`, `ClientPortal::FormResponsesController`)
- **3 Svelte pages** (portal + password reveal)
- **1 serializer** (`ClientFormSerializer`)
- **1 optional service** (`ClientInvitationService`)
- **Routes update**

---

## Notes on Backward Compatibility
- Existing `Client` and `Form` workflows remain unchanged.
- All new functionality is additive and isolated to a new subspace.
- No changes to `ClientsController` or `FormsController` required.
