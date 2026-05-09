# Hireest — Backend

REST API in **Ruby on Rails 8.1** (**API-only** mode) to manage **job opportunities**, **resumes**, **companies**, **roles**, **skills**, **languages**, **work experience**, and profile data — with **per-user multi-tenancy** (every domain record belongs to the authenticated user).

Designed to integrate with a separate front-end (SPA / Inertia / React): **JSON in `snake_case`**, **UUID string IDs (36 characters)**, and **JWT authentication** (`Authorization: Bearer`).

---

## Quick highlights

- Rails 8.1 + SQLite (dev/test; production with Docker volumes for `storage/*.sqlite3`)
- JWT + `has_secure_password` (bcrypt)
- OpenAPI 3 served at **`/api-docs`** (RSwag UI + spec generated from specs)
- Configurable CORS for front-end origins
- Health check at **`/up`**

---

## Recent updates (2026-05-01)

- **Users — `preferred_language`:** UI language preference (`en`, `pt_br`, `es`), default `en`; exposed on user JSON and update endpoints.
- **`Language`:** User-spoken languages with `name` and proficiency `level` (`beginner`, `intermediate`, `advanced`, `native`); full CRUD under `/api/v1/languages`.
- **Resume PDF import** (`POST /api/v1/resumes/pdf-import`, `Resume::PdfImporter` + RubyLLM structured schema `Resume::PdfExtractSchema`):
  - Extracts **roles**, **languages**, **companies** (from employers in work history, with optional URL and text built from job tagline + duties), **reference links** (e.g. LinkedIn, GitHub), and **per-job skills** in addition to global skills, education, certifications, and work history.
  - **Skills from work experiences:** nested `skills` on each job create/find `Skill` rows, link them via `work_experience_skills`, and union those IDs into the imported resume’s `resume_skills`.
  - **Idempotent import:** Reuses existing **work experiences**, **educations**, and **certifications** when identifiers match (title, company, dates, etc.); reuses **skills**, **roles**, **languages**, and **reference links** by name/URL; does **not** create duplicate companies; **does not** overwrite **language** level or **pre-existing company** fields on a later import — companies created in the **same** import can still merge descriptions/URL. Empty per-job `skills` does not clear existing work-experience skill links.
- **Environment:** `RESUME_IMPORT_OPENAI_MODEL` (optional) selects the OpenAI model for CV extraction; RubyLLM is configured in `config/initializers/ruby_llm.rb`.

See **`docs/db.mermaid`** and migrations under `db/migrate/` for physical schema details.

---

## Main stack

| Technology | Purpose |
|------------|---------|
| **Ruby** | 3.3.6 (see `.ruby-version`) |
| **Rails** | ~> 8.1.3 |
| **SQLite** | Active Record (`storage/development.sqlite3`, etc.) |
| **Puma** | HTTP server |
| **JWT** (`jwt`) | Access tokens |
| **rack-cors** | CORS for `/api/*` |
| **rswag-api / rswag-ui / rswag-specs** | OpenAPI docs + generation from RSpec |
| **solid_queue / solid_cache / solid_cable** | Queue, cache, and cable backed by SQLite in production (Rails 8) |
| **Kamal** | Optional container deploy (see `config/deploy.yml`) |

---

## Repository layout

Folder-oriented view of what matters to understand and evolve the project:

```text
job-vacancy-manager-backend/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb          # ActionController::API
│   │   ├── concerns/                          # Shared concerns
│   │   └── api/v1/                            # API version 1
│   │       ├── base_controller.rb             # Global rescue_from (404 JSON, etc.)
│   │       ├── authenticated_controller.rb    # JWT + pagination on index
│   │       ├── auth/                          # login, register, password, /me
│   │       ├── *_controller.rb                # REST resources (users, opportunities, …)
│   │       └── resume_* / work_experience_*   # Association sync (PATCH)
│   ├── models/                                # Entities + as_api_json, validations, UUID
│   ├── models/concerns/
│   ├── models/resume/                         # PdfImporter, PdfExtractSchema, description helpers
│   ├── services/                              # e.g. aggregations (dashboard)
│   ├── mailers/                               # Registration / password change
│   └── views/                                 # Mailer templates
├── config/
│   ├── routes.rb                              # `/api/v1/...` routes
│   ├── database.yml                           # SQLite under storage/
│   ├── initializers/
│   │   ├── cors.rb                            # CORS_ORIGINS
│   │   └── rswag_*.rb
│   └── environments/
├── db/
│   ├── migrate/
│   └── schema.rb                              # Physical model source of truth
├── docs/
│   ├── api-resource-patterns.md               # API patterns (auth, pagination, Swagger)
│   └── db.mermaid                             # Conceptual ER diagram
├── spec/
│   ├── requests/api/v1/                       # RSwag + request/response examples
│   ├── support/
│   └── swagger_helper.rb
├── swagger/
│   └── v1/swagger.yaml                        # Generated OpenAPI spec
├── storage/                                   # SQLite DB files (dev/test/prod)
├── bin/setup                                  # bundle + db:prepare (+ optional --reset)
├── bin/dev                                    # rails server
└── Gemfile
```

---

## Domain model (summary)

All resources below (except public auth) are **scoped by the JWT’s `user_id`**.

### Core entities

| Entity | Description |
|--------|-------------|
| **User** | Account: name, email, password (`password_digest`), profile (bio, phone, address, etc.), optional legacy `token`, **`preferred_language`** |
| **Company** | Company: name, URL, description, `interest_level` |
| **Role** | Target role / title: name, description, `interest_level` |
| **Skill** | Skill with name and description |
| **Language** | Spoken language: `name`, `level` (`beginner` … `native`) |
| **ReferenceLink** | Reference link (title + URL) |
| **WorkExperience** | Job: title, company, dates, `is_remote`; many-to-many **skills** via `work_experience_skills` |
| **Certification** | Certification with name and date range |
| **Education** | Education: institution, degree, field, dates |
| **OpportunityStatus** | Pipeline status: `label`, `variant`, `position` |
| **Opportunity** | Opportunity: links **company**, **role**, and **status**; URL, description, pay (`hourly_rate`, `annual_salary`), `interest_level` |
| **Resume** | Resume: title, description, linked to one **role**; N:N with experiences, certifications, education, and skills via join tables |

### Join tables (user-scoped)

- `resume_work_experiences`, `resume_certifications`, `resume_educations`, `resume_skills`
- `work_experience_skills` (skills per experience)

For full relationships see **`docs/db.mermaid`** and **`db/schema.rb`**.

---

## API `/api/v1`

**Base URL (development):** `http://localhost:3000`

### Authentication

- **Protected:** header `Authorization: Bearer <jwt>`.
- **Login:** `POST /api/v1/auth/login` — JSON body: `{ "auth": { "email": "...", "password": "..." } }` → `{ "token", "user" }` or `401`.
- **Register:** `POST /api/v1/auth/register` — `{ "auth": { "name", "email", "password", "password_confirmation" } }` → `201` with `token` + `user` or `422` with `{ "errors": ... }`.
- **Current user:** `GET /api/v1/auth/me` (with Bearer).
- **Recover / change password:** `POST /api/v1/auth/recover-password`, `POST /api/v1/auth/change-password` (see `spec/requests/api/v1/auth/`).

JWT secret: `Rails.application.credentials.dig(:jwt, :secret)` → fallback **`ENV["JWT_SECRET"]`** → `secret_key_base`. In production, set a dedicated strong secret.

**Mailer and front-end URL:** copy **`.env.example`** to **`.env`** at the backend root. It documents `FRONTEND_URL`, `MAILER_*`, and `SMTP_*` (links in emails and local SMTP, e.g. Mailpit on port 1025).

### Response conventions

- **JSON:** keys in **`snake_case`**.
- **Validation errors:** `422` + `{ "errors": { ... } }`.
- **Not found:** `404` (empty body on routes using `rescue_from`).
- **Paginated index (default):** envelope `{ "data": [...], "meta": { "current_page", "per_page", "total_pages", "total_count" } }`. Opt-out: `?paginated=false` (raw array).
- Query params: `page`, `per_page` (max 100).

### REST routes

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/v1/users` | Lists only the signed-in user (paginated) |
| GET/POST | `/api/v1/users`, `/api/v1/users/:id` | `create` is public; show/update/destroy scoped to self |
| GET/POST/PATCH/DELETE | `/api/v1/roles` | User-scoped CRUD |
| GET/POST/PATCH/DELETE | `/api/v1/companies` | Same |
| GET/POST/PATCH/DELETE | `/api/v1/skills` | Same |
| GET/POST/PATCH/DELETE | `/api/v1/languages` | Same |
| GET/POST/PATCH/DELETE | `/api/v1/reference-links` | Same |
| GET/POST/PATCH/DELETE | `/api/v1/certifications` | Same |
| GET/POST/PATCH/DELETE | `/api/v1/educations` | Same |
| GET/POST/PATCH/DELETE | `/api/v1/opportunity-statuses` | Same |
| GET | `/api/v1/dashboard` | Aggregated summary (`DashboardSummary`) |
| GET/POST/PATCH/DELETE | `/api/v1/opportunities` | Same |
| GET/POST/PATCH/DELETE | `/api/v1/resumes` | Resumes + enriched JSON on show/create/update |
| POST | `/api/v1/resumes/pdf-import` | Multipart PDF import (structured extract + new resume) |
| PATCH | `/api/v1/resumes/:id/work-experiences` | Sync experience IDs (`resume_work_experience`) |
| PATCH | `/api/v1/resumes/:id/certifications` | Sync certifications |
| PATCH | `/api/v1/resumes/:id/educations` | Sync education |
| PATCH | `/api/v1/resumes/:id/skills` | Sync skills |
| GET/POST/PATCH/DELETE | `/api/v1/work-experiences` | CRUD |
| PATCH | `/api/v1/work-experiences/:id/skills` | Sync skills on an experience |

### Interactive documentation

- **Swagger UI + JSON:** [http://localhost:3000/api-docs](http://localhost:3000/api-docs) (after starting the server).

### Health check

- **GET** `/up` — returns `200` if the app booted without errors (load balancer / monitoring).

---

## Prerequisites

- **Ruby 3.3.6** (recommended: `rbenv`, `asdf`, or `mise`, aligned with `.ruby-version`)
- **Bundler**
- **SQLite 3** (via `sqlite3` gem; usually works out of the box on macOS)

---

## Local setup and run

### 1. Clone and enter the directory

```bash
git clone <repository-url> job-vacancy-manager-backend
cd job-vacancy-manager-backend
```

### 2. Install dependencies

```bash
bundle install
```

### 3. Database

```bash
bin/rails db:prepare
```

This creates/updates `storage/development.sqlite3` from `db/schema.rb` and migrations.

Full reset (wipes local data):

```bash
bin/rails db:reset
```

Or use the idempotent script:

```bash
bin/setup              # bundle + db:prepare + clean logs/tmp + starts bin/dev
bin/setup --skip-server   # without starting the server
bin/setup --reset         # includes db:reset
```

### 4. Development server

```bash
bin/dev
# equivalent to:
bin/rails server
```

API at **`http://localhost:3000`**.

### Useful environment variables

| Variable | Description |
|----------|-------------|
| **`CORS_ORIGINS`** | Comma-separated allowed origins (e.g. `http://localhost:5173,https://app.example.com`). Default if empty: `http://localhost:5173,http://localhost:3000`. See `config/initializers/cors.rb`. |
| **`JWT_SECRET`** | HS256 secret for JWT (production: set a strong value). |
| **`RAILS_MAX_THREADS`** | Used in `database.yml` for `max_connections` (default 5). |
| **`RESUME_IMPORT_OPENAI_MODEL`** | Optional OpenAI model id for resume PDF extraction (see `Resume::PdfImporter`). |

Rails credentials (`config/credentials.yml.enc`) may store `jwt: secret:` — see **`docs/api-resource-patterns.md`**.

---

## Tests and OpenAPI generation

```bash
bundle exec rspec
```

Regenerate **`swagger/v1/swagger.yaml`** from specs:

```bash
bin/rails rswag:specs:swaggerize
```

Optional Gemfile tools (dev/test): **Brakeman**, **bundler-audit**, **RuboCop** (Omakase).

---

## More docs in the repo

- **`docs/api-resource-patterns.md`** — controller patterns, envelopes, pagination, Swagger, and authentication (reference for new resources).
- **`docs/db.mermaid`** — ER diagram.

---

## License and usage

Add a license file (e.g. `LICENSE`) according to how you want to share the project — this README only describes architecture and technical setup.

---

**One-line summary:** Rails 8 JSON-first API for career and job tracking, with JWT, UUIDs, SQLite, OpenAPI at `/api-docs`, and optional RubyLLM-based resume PDF import — ready for a front-end on another origin (CORS).
