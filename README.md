# Job Vacancy Manager — Backend

API REST em **Ruby on Rails 8.1** (modo **API-only**) para gerenciar **oportunidades de trabalho**, **currículos**, **empresas**, **papéis (roles)**, **habilidades**, **experiências** e dados de perfil — com **multi-tenant por usuário** (cada registro de domínio pertence ao usuário autenticado).

Projeto pensado para integração com um front-end separado (SPA / Inertia / React): **JSON em `snake_case`**, **IDs UUID (string 36 caracteres)** e **autenticação JWT** (`Authorization: Bearer`).

---

## Destaque rápido (para compartilhar)

- Rails 8.1 + SQLite (dev/test; produção com volumes Docker para `storage/*.sqlite3`)
- JWT + `has_secure_password` (bcrypt)
- OpenAPI 3 servido em **`/api-docs`** (RSwag UI + spec gerada a partir dos specs)
- CORS configurável para origens do front-end
- Health check em **`/up`**

---

## Stack principal

| Tecnologia | Uso |
|------------|-----|
| **Ruby** | 3.3.6 (ver `.ruby-version`) |
| **Rails** | ~> 8.1.3 |
| **SQLite** | Active Record (`storage/development.sqlite3`, etc.) |
| **Puma** | Servidor HTTP |
| **JWT** (`jwt`) | Tokens de acesso |
| **rack-cors** | CORS para `/api/*` |
| **rswag-api / rswag-ui / rswag-specs** | Documentação OpenAPI + geração a partir do RSpec |
| **solid_queue / solid_cache / solid_cable** | Filas, cache e cable com SQLite em produção (Rails 8) |
| **Kamal** | Deploy opcional em container (ver `config/deploy.yml`) |

---

## Estrutura do repositório

Visão orientada a pastas — o que importa para entender e evoluir o projeto:

```text
job-vacancy-manager-backend/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb          # ActionController::API
│   │   ├── concerns/                          # Concerns compartilhados
│   │   └── api/v1/                            # Versão 1 da API
│   │       ├── base_controller.rb             # rescue_from global (404 JSON inválido, etc.)
│   │       ├── authenticated_controller.rb    # JWT + paginação em index
│   │       ├── auth/                          # login, registro, senha, /me
│   │       ├── *_controller.rb                # recursos REST (users, opportunities, …)
│   │       └── resume_* / work_experience_*   # sincronização de associações (PATCH)
│   ├── models/                                # Entidades + as_api_json, validações, UUID
│   ├── models/concerns/
│   ├── services/                              # Ex.: agregações (dashboard)
│   ├── mailers/                               # Registro / alteração de senha
│   └── views/                                 # Templates de e-mail
├── config/
│   ├── routes.rb                              # Rotas `/api/v1/...`
│   ├── database.yml                           # SQLite em storage/
│   ├── initializers/
│   │   ├── cors.rb                            # CORS_ORIGINS
│   │   └── rswag_*.rb
│   └── environments/
├── db/
│   ├── migrate/
│   └── schema.rb                              # Fonte da verdade do modelo físico
├── docs/
│   ├── api-resource-patterns.md               # Padrões da API (autenticação, paginação, Swagger)
│   └── db.mermaid                             # Diagrama ER conceitual
├── spec/
│   ├── requests/api/v1/                       # RSwag + exemplos de request/response
│   ├── support/
│   └── swagger_helper.rb
├── swagger/
│   └── v1/swagger.yaml                        # Spec OpenAPI gerada
├── storage/                                   # Bancos SQLite (dev/test/prod)
├── bin/setup                                  # bundle + db:prepare (+ opcional --reset)
├── bin/dev                                    # rails server
└── Gemfile
```

---

## Modelo de domínio (resumo)

Todos os recursos abaixo (exceto autenticação pública) são **filtrados pelo `user_id` do JWT**.

### Entidades principais

| Entidade | Descrição |
|----------|-----------|
| **User** | Conta: nome, e-mail, senha (`password_digest`), perfil (bio, telefone, endereço, etc.), `token` opcional legado |
| **Company** | Empresa: nome, URL, descrição, `interest_level` |
| **Role** | Cargo / papel desejado: nome, descrição, `interest_level` |
| **Skill** | Habilidade com nome e descrição |
| **ReferenceLink** | Link de referência (título + URL) |
| **WorkExperience** | Experiência: título, empresa, datas, `is_remote` |
| **Certification** | Certificação com nome e período |
| **Education** | Formação: instituição, curso, datas |
| **OpportunityStatus** | Status do funil de oportunidades: `label`, `variant`, `position` |
| **Opportunity** | Oportunidade: liga **company**, **role** e **status**; URL, descrição, remuneração (`hourly_rate`, `annual_salary`), `interest_level` |
| **Resume** | Currículo: título, descrição, ligado a um **role**; associações N:N com experiências, certificações, educações e skills via tabelas de junção |

### Tabelas de junção (pertencem ao usuário)

- `resume_work_experiences`, `resume_certifications`, `resume_educations`, `resume_skills`
- `work_experience_skills` (skills por experiência)

Relacionamentos detalhados: **`docs/db.mermaid`** e **`db/schema.rb`**.

---

## API `/api/v1`

**Base URL (desenvolvimento):** `http://localhost:3000`

### Autenticação

- **Protegido:** cabeçalho `Authorization: Bearer <jwt>`.
- **Login:** `POST /api/v1/auth/login` — corpo JSON: `{ "auth": { "email": "...", "password": "..." } }` → `{ "token", "user" }` ou `401`.
- **Registro:** `POST /api/v1/auth/register` — `{ "auth": { "name", "email", "password", "password_confirmation" } }` → `201` com `token` + `user` ou `422` com `{ "errors": ... }`.
- **Usuário atual:** `GET /api/v1/auth/me` (com Bearer).
- **Recuperar / alterar senha:** `POST /api/v1/auth/recover-password`, `POST /api/v1/auth/change-password` (detalhes nos specs em `spec/requests/api/v1/auth/`).

Segredo JWT: `Rails.application.credentials.dig(:jwt, :secret)` → fallback **`ENV["JWT_SECRET"]`** → `secret_key_base`. Em produção, defina um segredo dedicado.

**Mailer e URL do frontend:** copie **`.env.example`** para **`.env`** na raiz do backend. Lá estão `FRONTEND_URL`, `MAILER_*` e `SMTP_*` (links em e-mails e servidor SMTP local, por exemplo Mailpit na porta 1025).

### Convenções de resposta

- **JSON:** chaves em **`snake_case`**.
- **Erros de validação:** `422` + `{ "errors": { ... } }`.
- **Registro não encontrado:** `404` (corpo vazio nas rotas que usam `rescue_from`).
- **Index paginado (padrão):** envelope `{ "data": [...], "meta": { "current_page", "per_page", "total_pages", "total_count" } }`. Opt-out: `?paginated=false` (array cru).
- Query: `page`, `per_page` (máx. 100).

### Rotas REST

| Método | Caminho | Observação |
|--------|---------|------------|
| GET | `/api/v1/users` | Lista só o usuário logado (paginado) |
| GET/POST | `/api/v1/users`, `/api/v1/users/:id` | `create` público; show/update/destroy com escopo do próprio usuário |
| GET/POST/PATCH/DELETE | `/api/v1/roles` | CRUD no escopo do usuário |
| GET/POST/PATCH/DELETE | `/api/v1/companies` | Idem |
| GET/POST/PATCH/DELETE | `/api/v1/skills` | Idem |
| GET/POST/PATCH/DELETE | `/api/v1/reference-links` | Idem |
| GET/POST/PATCH/DELETE | `/api/v1/certifications` | Idem |
| GET/POST/PATCH/DELETE | `/api/v1/educations` | Idem |
| GET/POST/PATCH/DELETE | `/api/v1/opportunity-statuses` | Idem |
| GET | `/api/v1/dashboard` | Resumo agregado (`DashboardSummary`) |
| GET/POST/PATCH/DELETE | `/api/v1/opportunities` | Idem |
| GET/POST/PATCH/DELETE | `/api/v1/resumes` | Currículos + JSON enriquecido em show/create/update |
| PATCH | `/api/v1/resumes/:id/work-experiences` | Sincroniza IDs de experiências (`resume_work_experience`) |
| PATCH | `/api/v1/resumes/:id/certifications` | Sincroniza certificações |
| PATCH | `/api/v1/resumes/:id/educations` | Sincroniza educações |
| PATCH | `/api/v1/resumes/:id/skills` | Sincroniza skills |
| GET/POST/PATCH/DELETE | `/api/v1/work-experiences` | CRUD |
| PATCH | `/api/v1/work-experiences/:id/skills` | Sincroniza skills da experiência |

### Documentação interativa

- **Swagger UI + JSON:** [http://localhost:3000/api-docs](http://localhost:3000/api-docs) (após subir o servidor).

### Health check

- **GET** `/up` — retorna `200` se a app subiu sem exceções (útil para load balancer / monitoramento).

---

## Pré-requisitos

- **Ruby 3.3.6** (recomendado: `rbenv`, `asdf` ou `mise`, alinhado ao `.ruby-version`)
- **Bundler**
- **SQLite 3** (via gem `sqlite3`; no macOS costuma funcionar out-of-the-box)

---

## Configuração e execução local

### 1. Clonar e entrar no diretório

```bash
git clone <url-do-repositório> job-vacancy-manager-backend
cd job-vacancy-manager-backend
```

### 2. Instalar dependências

```bash
bundle install
```

### 3. Banco de dados

```bash
bin/rails db:prepare
```

Isso cria/atualiza `storage/development.sqlite3` conforme `db/schema.rb` e migrações.

Para reset completo (apaga dados locais):

```bash
bin/rails db:reset
```

Ou use o script idempotente:

```bash
bin/setup              # bundle + db:prepare + limpa logs/tmp + sobe bin/dev
bin/setup --skip-server   # sem iniciar o servidor
bin/setup --reset         # inclui db:reset
```

### 4. Servidor de desenvolvimento

```bash
bin/dev
# equivalente a:
bin/rails server
```

API em **`http://localhost:3000`**.

### Variáveis de ambiente úteis

| Variável | Descrição |
|----------|-----------|
| **`CORS_ORIGINS`** | Lista separada por vírgulas de origens permitidas (ex.: `http://localhost:5173,https://app.exemplo.com`). Padrão se vazio: `http://localhost:5173,http://localhost:3000`. Ver `config/initializers/cors.rb`. |
| **`JWT_SECRET`** | Segredo HS256 para JWT (produção: obrigatório definir um valor forte). |
| **`RAILS_MAX_THREADS`** | Usado em `database.yml` para `max_connections` (padrão 5). |

Credenciais Rails (`config/credentials.yml.enc`) podem guardar `jwt: secret:` — ver documentação interna em **`docs/api-resource-patterns.md`**.

---

## Testes e geração do OpenAPI

```bash
bundle exec rspec
```

Regenerar **`swagger/v1/swagger.yaml`** a partir dos specs:

```bash
bin/rails rswag:specs:swaggerize
```

Ferramentas opcionais do Gemfile (dev/test): **Brakeman**, **bundler-audit**, **RuboCop** (omakase).

---

## Documentação adicional no repositório

- **`docs/api-resource-patterns.md`** — padrão de controllers, envelopes, paginação, Swagger e autenticação (referência para novos recursos).
- **`docs/db.mermaid`** — diagrama ER.

---

## Licença e uso

Defina a licença no repositório (ex.: arquivo `LICENSE`) conforme sua intenção ao divulgar nas redes — este README descreve apenas a arquitetura e o setup técnico.

---

**Resumo em uma linha:** API Rails 8 JSON-first para gestão de carreira e vagas, com JWT, UUIDs, SQLite e documentação OpenAPI em `/api-docs`, pronta para consumo por um front-end em outra origem (CORS).
