# API resource patterns (using `Users` as the reference)

This document explains **how the `users` resource was built** (routes, controllers, model, migration, specs, and Swagger) so you can **reuse the same shape** for the rest of the domain tables. It also includes reminders that tend to matter as the API grows.

Cross-reference with the planned data model: [`docs/db.mermaid`](./db.mermaid).

---

## 1. Architecture overview

| Layer | Pattern |
|-------|---------|
| **API** | REST under `/api/v1`, JSON, attributes in **snake_case** (aligned with the Rails / Inertia front and `db.mermaid`). |
| **IDs** | API contract is **UUID** (36-character string). With the current SQLite setup, the primary key is `string(36)` plus generation in the model; on PostgreSQL later you can move to a native `uuid` type. |
| **Validation errors** | Body `{ "errors": { ... } }` with `422 Unprocessable Entity`. |
| **Missing records** | `404` with an empty body (`head :not_found`), via `rescue_from` on the API base controller. |
| **Auth** | **JWT** (`Authorization: Bearer <token>`) for protected routes; `POST /api/v1/auth/login` issues tokens. |
| **Documentation** | **OpenAPI 3** generated from **RSpec + RSwag** (`spec/requests/...`), served at `/api-docs`. |

---

## 2. Routes and versioning

- Resources live under **`namespace :api` → `namespace :v1`** in `config/routes.rb`.
- Example: `resources :users` exposes `index`, `show`, `create`, `update`, `destroy` at `/api/v1/users` and `/api/v1/users/:id`, plus `post "auth/login", to: "auth/sessions#create"` for JWT issuance.
- **New entity:** add `resources :companies` (or similar) **inside** the same `namespace :v1` to keep the version stable; incompatible changes later should go to `v2`.

Swagger engines (do not confuse with business API routes):

- `mount Rswag::Ui::Engine => "/api-docs"`
- `mount Rswag::Api::Engine => "/api-docs"`

---

## 3. Controllers

### 3.1 Hierarchy

- `ApplicationController` inherits from `ActionController::API` (`config.api_only = true`).
- `Api::V1::BaseController < ApplicationController` — shared `rescue_from` and anything that must **not** require a JWT (e.g. `Auth::SessionsController`).
- `Api::V1::AuthenticatedController < BaseController` — includes `Api::V1::Authenticatable` (`before_action` + `Current.user`).
- Resource controllers that need a logged-in user: `Api::V1::UsersController < AuthenticatedController` with `skip_before_action :authenticate_request!, only: :create` for **public signup**.

### 3.2 `Api::V1::BaseController`

- Centralizes shared v1 behavior, for example:

  `rescue_from ActiveRecord::RecordNotFound` → `head :not_found`.

Then `show` / `update` / `destroy` do not repeat `rescue` in every resource.

### 3.3 Thin controllers (project rule)

- **No** heavy domain logic in the controller: validations and invariants live in the **model**; the controller orchestrates `find` / `save` / `render`.
- Success responses: **`render json: object_or_collection`** using a payload prepared on the model (e.g. `as_api_json`).
- **Create:** `201 Created` + resource JSON.
- **Update:** `200 OK` + updated JSON; validation failure → `422` + `{ errors: ... }`.
- **Destroy:** `204 No Content` (`head :no_content`) after `destroy!` (a failed destroy raises—useful to catch callback bugs; if you prefer soft failure, use `destroy` and handle the return value).

### 3.4 Strong parameters

- **Create:** `params.require(:envelope).permit(...)` — envelope name matches the singular resource (`:user`, `:company`, …).
- **Update:** when a field **must not be applied when blank** (e.g. password), use a dedicated method (`user_update_params`) that strips blank keys before `update`.

### 3.5 Authentication and authorization (implemented for `users`)

- **Login:** `POST /api/v1/auth/login` with `{ "auth": { "email", "password" } }` returns `{ "token", "user" }` or `401` with an empty body on failure.
- **JWT:** HS256 payload `{ "sub" => user.id, "exp" => …, "jv" => users.jwt_version }` via `User::JwtIssuer`. Ausência de `jv` equivale a versão `0` (legado); `jv` deve igualar `users.jwt_version` ou resposta `401`. Segredo: `credentials.dig(:jwt, :secret)` → `ENV["JWT_SECRET"]` → `Rails.application.secret_key_base`.
- **`Current.user`:** set in `Api::V1::Authenticatable` after a valid Bearer token; cleared with `Current.reset` after each request.
- **`users#index`:** returns only the authenticated user (`[current_user.as_api_json]`); `show` / `update` / `destroy` respond `404` unless `id` is the authenticated user’s id (evita enumeração de contas).

### 3.6 Pagination on `index` (default behavior)

All `index` actions in `Api::V1` are paginated by default through the `Api::V1::Paginatable` concern (included in `AuthenticatedController`). Use `render_paginated(scope)` instead of `render json: scope.map(&:as_api_json)`:

```ruby
def index
  render_paginated(current_user.opportunities.order(created_at: :desc))
end
```

**Response shape (default):**

```json
{
  "data": [ { ... }, { ... } ],
  "meta": {
    "current_page": 1,
    "per_page": 25,
    "total_pages": 4,
    "total_count": 87
  }
}
```

**Query parameters:**

| Param | Default | Notes |
|-------|---------|-------|
| `page` | `1` | Coerced to `>= 1`; invalid values fall back to `1`. |
| `per_page` | `25` | Capped at `100`; invalid values fall back to `25`. |
| `paginated` | `true` | Send `false` / `0` / `no` to opt out and receive the legacy bare array (`[ {...}, ... ]`, no envelope). |

**OpenAPI:** add a `paginated_<resource>` envelope schema in `spec/swagger_helper.rb` and reference it from the `index` response (`schema "$ref" => "#/components/schemas/paginated_<resource>"`). Always document the three query params on the `get` block.

**Specs:** include `it_behaves_like "paginated index", path: "/api/v1/<resource>"` (defined in `spec/support/shared_examples/paginated_index.rb`) to cover envelope shape, `?paginated=false` opt-out, `per_page` cap, and `page`/`per_page` navigation.

### 3.7 Still worth planning for other resources

- **Filters** on `index` (search, date ranges) once the SPA needs them.
- **Nested routes** (`/api/v1/users/:user_id/companies`) only when the UX and authorization model are truly nested.
- **Refresh tokens / revocation** — optional use of `users.token` or a separate table; today access tokens are stateless until expiry.

---

## 4. Model

### 4.1 Responsibilities

- **Validations** (`validates`, formats, uniqueness).
- **Callbacks** only when they stay simple and predictable (e.g. `before_validation :normalize_email`, `before_create :assign_uuid`).
- **API serialization:** an explicit method like `as_api_json` using `as_json(only: [...])` so you **never** expose `password_digest`, internal tokens, etc.

### 4.2 `User`-specific notes

- `has_secure_password` + `password_digest` column.
- Optional password on update: conditional validation with `if: -> { password.present? }`.
- **UUID:** `assign_uuid` on create when the DB primary key is a string column.

For **other models**, reuse the `as_api_json` pattern (and, if needed, `assign_uuid` via `ApplicationRecord` or a shared concern) instead of duplicating attribute lists in controllers.

### 4.3 Where to put shared behavior (Rails / Basecamp style)

- Model-specific concerns under `app/models/model_name/` (e.g. `Company::Searchable`); avoid scattering domain rules in root-level “service objects” unless you have a clear reason—see the internal *ruby-on-rails-best-practices* skill.

---

## 5. Migrations and database

- Tables and columns in **snake_case**; indexes on fields you query often and on **uniqueness** (`email`, etc.).
- **Optional token with uniqueness:** a **partial** unique index `WHERE token IS NOT NULL` documents intent and avoids odd `NULL` uniqueness edge cases on some databases.
- **SQLite + UUID:** today the PK is `string(36)` because `id: :uuid` on SQLite broke `schema.rb` dumping on Rails 8.1; the migration comment explains. When you adopt PostgreSQL, align column type and default (`gen_random_uuid()` or equivalent).

---

## 6. Specs (RSpec) and Swagger (RSwag)

### 6.1 Main files

| File | Role |
|------|------|
| `spec/swagger_helper.rb` | Sets `openapi_root`, the `v1/swagger.yaml` document, `servers`, and `components.schemas` (reusable types, e.g. `user`, `user_create_request`, `validation_errors`). |
| `spec/requests/api/v1/users_spec.rb` | Describes **paths** and **responses**; `run_test!` runs a real request and feeds the generated YAML. |
| `swagger/v1/swagger.yaml` | **Generated**—do not hand-edit as the source of truth; regenerate after changing specs. |

### 6.2 Request spec conventions

- `require "swagger_helper"` at the top.
- `RSpec.describe "...", openapi_spec: "v1/swagger.yaml"` to bind to the right document.
- Per operation: `tags`, `consumes` / `produces`, `parameter` (body with `$ref` to a schema).
- Each `response XXX` with `schema` (or `$ref`) + `let(:body)` / `let(:id)` + `run_test!` (optional block with extra JSON assertions).

### 6.3 Commands

```bash
bundle exec rspec
bin/rails rswag:specs:swaggerize
```

The second command uses the formatter’s **dry-run** path to **regenerate** OpenAPI from the request specs.

### 6.4 Model specs

- `spec/models/user_spec.rb` covers rules that do not depend on HTTP; good for validations and normalization without going through Swagger.

### 6.5 CI reminder

- Ensure `db:test:prepare` / migrations are applied in CI before `rspec` (`rails_helper` already tries `maintain_test_schema!`).

---

## 7. Checklist for a **new** resource (mirroring `users`)

1. **Migration** with FKs as `uuid` / `string(36)` per project convention + `user_id` when the row is scoped to a user (`db.mermaid`).
2. **Model** with validations, `as_api_json` (and UUID assignment if applicable).
3. **`config/routes.rb`:** `resources :name` inside `api/v1`.
4. **`Api::V1::NamesController < AuthenticatedController`** (or `BaseController` if fully public) with the same HTTP patterns, strong params (`name_params` / `name_update_params` when needed), and `skip_before_action` only for intentionally public actions.
5. **`spec/swagger_helper.rb`:** add schemas (`name`, `name_create_request`, `names_list`, …); for protected routes add `security [bearer_auth: []]` and `let(:Authorization) { "Bearer #{...}" }` in RSwag examples.
6. **`spec/requests/api/v1/names_spec.rb`:** cover happy paths plus relevant `401` / `403` / `422` / `404` (plain `type: :request` examples are fine when one OpenAPI operation cannot express two different auth modes).
7. Run **`rspec`** and **`rswag:specs:swaggerize`**.
8. **Scope** all queries to `current_user` / associations when the table has `user_id` (`db.mermaid`) — e.g. `current_user.roles.build` and `current_user.roles.find_by(id: ...)` so the client never sets `user_id` (see `RolesController`, `SkillsController`).

---

## 8. Important concepts (implicit reminders for future resources)

| Topic | Why it matters |
|-------|----------------|
| **`Current` (request scope)** | Modern Rails pattern for `current_user` / account; useful in controllers and models via `Current.user`, but jobs do not inherit the request—set context explicitly there. |
| **Idempotency and DELETE** | Clients may retry DELETE; either accept `404` on a second delete or always return `204`—align with the team. |
| **Nested `errors` JSON** | `errors.as_json` may differ on string vs symbol keys by version; front end and OpenAPI should agree on one stable shape. |
| **`params.expect` (Rails 8+)** | Stricter alternative to `require` / `permit`; consider when you want a hard failure on malformed payloads. |
| **CORS** | **`rack-cors`** is configured in `config/initializers/cors.rb` for `/api/*`; set **`CORS_ORIGINS`** (comma-separated) in production. |
| **Rate limiting and abuse** | Public signup (`POST /users`) in production usually needs throttling / CAPTCHA / email confirmation. |
| **Transactions and `destroy!`** | Callbacks or `restrict_with_error` FKs can block deletes; decide between `422` with a body vs a handled 500. |
| **Pagination + ordering** | `index` should use an explicit order (`order(created_at: :desc)`) for stable results. |
| **API versioning** | Ship breaking changes only under `/api/v2`; keep `v1` stable as long as legacy clients need it. |
| **Alignment with the React layout repo** | The `job-vacancy-manager-layout` project documents **snake_case** entity keys; keeping the same JSON keys reduces friction for Inertia or SPA integration. |

---

## 9. References in this repo

- Roles / skills / reference links / work experiences / certifications / educations / opportunity statuses / opportunities / resumes (user-scoped): `roles_controller.rb`, `skills_controller.rb`, `reference_links_controller.rb`, `work_experiences_controller.rb`, `certifications_controller.rb`, `educations_controller.rb`, `opportunity_statuses_controller.rb`, `opportunities_controller.rb`, `resumes_controller.rb`
- Vínculos N:N (substituição completa via **`PATCH`** + array de IDs; `[]` remove todos): `work_experience_skills_controller.rb`, `resume_work_experiences_controller.rb`, `resume_certifications_controller.rb`, `resume_educations_controller.rb`, `resume_skills_controller.rb`
- UUID PK concern: `app/models/concerns/uuid_primary_key.rb`
- Users controller: `app/controllers/api/v1/users_controller.rb`
- Authenticated base: `app/controllers/api/v1/authenticated_controller.rb`
- API base (no JWT): `app/controllers/api/v1/base_controller.rb`
- JWT concern: `app/controllers/concerns/api/v1/authenticatable.rb`
- Pagination concern: `app/controllers/concerns/api/v1/paginatable.rb`
- Pagination shared examples: `spec/support/shared_examples/paginated_index.rb`
- Login: `app/controllers/api/v1/auth/sessions_controller.rb`
- Request context: `app/models/current.rb`
- JWT encoding: `app/models/user/jwt_issuer.rb`
- Model: `app/models/user.rb`
- Migration: `db/migrate/20260202120000_create_users.rb`
- Request specs: `spec/requests/api/v1/users_spec.rb`, `spec/requests/api/v1/auth_sessions_spec.rb`
- OpenAPI base config: `spec/swagger_helper.rb`
- CORS: `config/initializers/cors.rb`
- Default security headers: `config/application.rb`
- Target ER diagram: `docs/db.mermaid`

Each new table can follow the same **trail**: **migration → model → routes → controller → schemas + request specs → regenerate Swagger**.
