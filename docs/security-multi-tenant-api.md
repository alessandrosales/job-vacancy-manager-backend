# Segurança multi-tenant da API (`user_id`)

Este documento avalia se a modelagem descrita em [`db.mermaid`](./db.mermaid) e a implementação Rails permitem que um usuário autenticado acesse dados sensíveis de outro usuário (IDOR / quebra de isolamento entre tenants).

## Modelagem de dados

O diagrama define **isolamento lógico por usuário**: entidades de domínio possuem `user_id` (ou, nas tabelas de junção com currículo, `user_id` redundante para alinhar ownership ao tenant).

Campos particularmente sensíveis no modelo:

| Área | Campo / dado | Observação |
|------|----------------|------------|
| Autenticação | `users.password_digest`, `users.token` | Nunca devem aparecer em JSON de API |
| Segredos | `users.ai_token` | Chave de provedor de IA; só o dono pode definir via API |
| Currículo | `resumes.compiled_markdown` | Conteúdo gerado / ATS |
| Perfil | `full_address`, `bio`, `phone`, etc. | PII do usuário |

Não há conceito de “organização compartilhada” ou “time” no diagrama: **todo acesso a registros de domínio deve passar pelo usuário autenticado**.

## Implementações de segurança (backend)

As medidas abaixo complementam o isolamento por escopo nos controllers.

### Versionamento de JWT (`jwt_version`)

- Coluna **`users.jwt_version`** (inteiro, padrão `0`).
- Cada token HS256 inclui a claim **`jv`** com o valor atual de `jwt_version` (`User::JwtIssuer`).
- **`User::JwtIssuer.user_from_token`** exige que o valor da claim **`jv`** coincida com `users.jwt_version`. Tokens **sem** `jv` são tratados como versão **0** e continuam válidos **somente** enquanto `jwt_version` do usuário for **0** (após troca de senha ou `invalidate_jwt_sessions!`, é obrigatório obter um token novo).
- Ao **rotacionar a senha** (`password_digest` alterado em registro já persistido), `jwt_version` é incrementado automaticamente, invalidando todos os JWTs anteriores.
- **`User#invalidate_jwt_sessions!`** incrementa `jwt_version` sem mudar senha (útil para “encerrar todas as sessões” a partir de código/console ou futuro endpoint).

### Documentação OpenAPI (`/api-docs`)

- Fora **development** e **test**, as engines **Rswag** só são montadas se **`ENABLE_API_DOCS=true`** no ambiente.
- Opcional: **`API_DOCS_USERNAME`** + **`API_DOCS_PASSWORD`** ativam Basic Auth na UI Swagger (`config/initializers/rswag_ui.rb`).

### Concern `Api::V1::TenantScopedRecord`

- Macro **`tenant_scoped_record`** para padronizar `before_action` que resolve um registro via `current_user.<associação>.find_by(...)` e responde **404** se o ID não for do tenant.
- Exemplo de uso: `Api::V1::OpportunitiesController`.

## Como a API impõe o isolamento hoje

### Autenticação

- Endpoints protegidos herdam de `Api::V1::AuthenticatedController`, que inclui `Api::V1::Authenticatable`.
- O JWT é validado em `User::JwtIssuer.user_from_token`; em caso de sucesso, `Current.user` é definido para a requisição e limpo no `after_action`.

### Padrão dos controllers de recurso

Para a maioria dos recursos REST (`companies`, `roles`, `opportunities`, `resumes`, etc.), o padrão dominante é:

```ruby
current_user.<associação>.find_by(id: params[:id])
```

Isso garante que um ID válido **de outro tenant** resulte em “não encontrado” (`404`), sem vazar existência do registro nem dados.

### Rotas aninhadas em `resumes`

Controllers que operam sobre um currículo específico usam `Api::V1::ResumeScoped`, que resolve o resume com:

```ruby
current_user.resumes.find_by(id: params[:resume_id])
```

Ou seja, exportação Markdown/PDF, sincronização de junções e duplicação ficam restritas ao dono.

### Validações no modelo (defesa adicional)

- **`Opportunity`**: `scoped_associations_owned_by_user` garante que `company_id`, `role_id` e `status_id` pertençam ao mesmo `user_id` do registro, impedindo referenciar empresas/cargos/status de outro usuário mesmo que alguém adultere o payload.
- **`Resume`**: `role_owned_by_user` garante que `role_id` seja do mesmo usuário.
- **`Resume`**: métodos `sync_*_links!` só aceitam IDs que existem no escopo do usuário (`owned_scope.where(id: ids).count == ids.size`).
- **`Resume::PdfImporter`**: resolve o papel com `user.roles.find_by!(id: role_id)` antes de persistir.

### Serialização (`as_api_json`)

- **`User#as_api_json`**: não expõe `password_digest`, `token` nem `ai_token`; expõe apenas `ai_token_configured` (booleano derivado).
- Demais modelos expõem campos de negócio; o risco de vazamento para outro usuário depende do controller **não** serializar registros fora do escopo — o que, na revisão atual, está alinhado com `current_user`.

## Achados e riscos

### Isolamento entre usuários (IDOR)

**Conclusão:** com a revisão dos controllers e modelos, **não há endpoint que liste ou retorne entidades de domínio de outro usuário** usando apenas um ID conhecido, desde que se mantenha o padrão `current_user.*.find_by`.

**Ajuste aplicado:** em `Api::V1::UsersController#set_user`, a verificação anterior carregava qualquer usuário por `params[:id]` e respondia `403` quando o ID não era o do solicitante. Isso permitia **enumerar UUIDs de usuários existentes** (403 vs 404). O fluxo foi alterado para resolver o recurso apenas quando `params[:id]` coincide com `current_user.id`, respondendo `404` nos demais casos — alinhado ao restante da API.

### Riscos residuais (defesa em profundidade)

1. **JWT stateless** — Não há denylist por token: entre emissão e expiração (`User::JwtIssuer.token_ttl`), um token com `jv` correto continua válido até expirar ou até **`jwt_version`** subir (troca de senha / `invalidate_jwt_sessions!`).
2. **Sem RLS no PostgreSQL** — O isolamento depende da aplicação. Row Level Security exigiria políticas por tabela, **`FORCE ROW LEVEL SECURITY`** (senão o dono das tabelas ignora RLS) e um papel de banco dedicado para o app — não está habilitado neste projeto; avaliar quando o usuário da conexão não for superusuário/dono das tabelas.
3. **Novos endpoints** — Repetir escopo por `current_user`, validações de FK no modelo quando aplicável e preferência por **404** uniforme; usar `TenantScopedRecord` quando fizer sentido.

### Autenticação e fluxos públicos

- Registro e login são esperados sem Bearer token; não retornam dados de terceiros.
- Recuperação de senha responde `204` mesmo se o e-mail não existir (evita enumeração de contas por essa rota).

## Checklist para novas features

- [ ] `before_action` ou query sempre via `current_user.<associação>` (ou equivalente explícito).
- [ ] FKs aceitas no `permit` validadas no modelo contra `user_id` quando o registro pai também é tenant-scoped.
- [ ] Respostas de autorização: preferir **404 uniforme** para “ID válido mas não seu” em APIs multi-tenant, salvo requisito explícito de `403`.
- [ ] Novos campos secretos: nunca incluir em `as_api_json` nem em `permit` de rotas públicas.
- [ ] Testes de request cobrindo “outro usuário + mesmo UUID de recurso” → `404` ou erro sem corpo sensível.

## Referências no código

- `app/models/user/jwt_issuer.rb` — claims `sub`, `exp`, `jv`
- `app/models/user.rb` — `jwt_version`, rotação com senha, `invalidate_jwt_sessions!`
- `app/controllers/concerns/api/v1/authenticatable.rb` — JWT e `Current.user`
- `app/controllers/concerns/api/v1/tenant_scoped_record.rb` — macro de escopo por tenant
- `app/controllers/concerns/api/v1/resume_scoped.rb` — escopo de currículo
- `config/routes.rb` — montagem condicional de `/api-docs`
- `config/initializers/rswag_ui.rb` — Basic Auth opcional
- `app/models/opportunity.rb` — validação de FKs por usuário
- `app/models/resume.rb` — junções e `role_owned_by_user`
- `docs/db.mermaid` — modelo lógico multi-tenant
