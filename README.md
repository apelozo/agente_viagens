# App de gerenciamento de viagens

Projeto full-stack:

- **Backend:** Node.js, Express, PostgreSQL, JWT, proxy para Google Places e Distance Matrix, WebSocket (broadcast de eventos).
- **Frontend:** Flutter (mobile/web/desktop), tema próprio, timeline, wishlist com mapa e fluxo de sugestões.

## Estrutura do repositório

| Pasta | Descrição |
|-------|-----------|
| `backend/` | API REST, `schema.sql`, scripts de banco |
| `lib/` | Aplicativo Flutter |
| `web/` | Entrada Flutter Web |

## Variáveis de ambiente (`backend/.env`)

```env
GOOGLE_PLACES_API_KEY=
GOOGLE_DISTANCE_MATRIX_API_KEY=
GOOGLE_API_BASE_URL=https://maps.googleapis.com/maps/api
DATABASE_URL=
JWT_SECRET=
PORT=5000
NODE_ENV=development
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
MAIL_FROM=
APP_BASE_URL=http://localhost:5000
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=
GOOGLE_OAUTH_REDIRECT_URI=http://localhost:5000/api/drive/oauth/callback
GOOGLE_OAUTH_TOKEN_PATH=.drive-oauth-token.json
DRIVE_PARENT_FOLDER_ID=
# Produção: origens HTTPS exactas (vírgula, sem espaços). Incluir Netlify e domínio customizado se usares ambos.
CORS_ALLOWED_ORIGINS=https://agentepessoaldaviagem.netlify.app,https://meuagentepessoal.net.br,https://www.meuagentepessoal.net.br
```

Chaves Google não são embutidas no app; apenas o backend chama as APIs.

## Setup local

### Backend

```bash
cd backend
npm install
npm run db:init
npm start
```

Servidor padrão: `http://localhost:5000` (altere com `PORT`).

Desenvolvimento com reload automático:

```bash
npm run dev
```

### Flutter

Na raiz do projeto:

```bash
flutter pub get
flutter run -d chrome
```

A URL da API é configurável por **dart-define** (veja `lib/services/api_service.dart`):

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:5000
```

Sem `API_BASE_URL`, o fallback do código pode apontar para um IP fixo de desenvolvimento — ajuste conforme sua rede.

**CORS em desenvolvimento:** se o Chrome usar outra origem (ex.: `http://localhost:<porta>` do `flutter run -d web-server`), acrescenta essa origem em `CORS_ALLOWED_ORIGINS` no `backend/.env` ou usa portas cobertas pelo fallback em `backend/server.js`.

**Backend em produção (Render):** `https://agente-viagens-api-backend.onrender.com` — usar este valor em `--dart-define=API_BASE_URL=...` e na variável `API_BASE_URL` do Static Site Netlify / Render, se aplicável.

### Build Android e Web (release)

Na raiz do projeto (defina a URL pública do backend; use `https` em produção):

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://seu-servidor.com
flutter build web --release --dart-define=API_BASE_URL=https://seu-servidor.com
```

- **APK Android:** `build/app/outputs/flutter-apk/app-release.apk` (instalação direta no telemóvel).
- **App Bundle (Google Play):** `flutter build appbundle --release --dart-define=API_BASE_URL=...` → `build/app/outputs/bundle/release/app-release.aab`.
- **Web estático:** pasta `build/web` (Netlify ou Render Static); o backend deve permitir **CORS** para a **origem HTTPS exacta** do site (`CORS_ALLOWED_ORIGINS` no Render).
- **Assinatura Play Store:** copie `android/key.properties.example` para `android/key.properties`, coloque o `.jks` em `android/app/` e preencha as palavras-passe (ficheiros sensíveis já estão no `.gitignore`).

#### Netlify (site estático — referência de produção Web)

1. Na máquina de desenvolvimento, com a URL **HTTPS** da API no Render:  
   `flutter build web --release --dart-define=API_BASE_URL=https://agente-viagens-api-backend.onrender.com`
2. A pasta a enviar é **`build/web`** (inclui `web/_redirects` → regra SPA na Netlify).
3. **Opção A — Netlify Drop:** [app.netlify.com/drop](https://app.netlify.com/drop) → arrasta a pasta `build/web`.
4. **Opção B — Netlify CLI:** na raiz do projeto:  
   `netlify deploy --dir=build/web` (pré-visualização) ou `netlify deploy --dir=build/web --prod` (produção).
5. No **Render** (Web Service da API), define **`CORS_ALLOWED_ORIGINS`** com a origem HTTPS **exacta** do teu site Netlify (ex.: `https://agentepessoaldaviagem.netlify.app`). Várias origens: separar por vírgula, sem espaços.
6. Para deploy **a partir do Git** com build automático na Netlify, usa **GitHub Actions** (ou CI) para correr `flutter build web` e publicar `build/web`, ou instala o SDK Flutter no ambiente de build da Netlify se disponível.

#### Render (backend API + Flutter Web) e Neon

O repositório inclui **`render.yaml`** (Blueprint) com dois serviços: **API** (`backend/`) e **site estático** (Flutter Web via `scripts/render-build-web.sh`). A base pode ficar só no **[Neon](https://neon.tech)** — cola o connection string em **`DATABASE_URL`** na API (não precisas de Postgres no Render).

**Resumo:** `server.js` usa `PORT` do Render e **`GET /health`**. O **Static Site** precisa da variável de build **`API_BASE_URL`** = URL `https` do teu backend (mesmo valor que usas no app).

1. **GitHub:** envia o projeto para um repositório (vê secção “Git” abaixo). Repositório **público** costuma ser necessário para **plano free** no Render — confirma as regras atuais na tua conta.
2. **Neon:** copia o **connection string** PostgreSQL → no Render, no serviço da API, define **`DATABASE_URL`**.
3. **Blueprint:** no Render, **New → Blueprint**, liga o repo e deixa detetar `render.yaml`, ou cria manualmente os dois serviços com os mesmos valores do ficheiro.
4. **Segredos no painel** (o assistente pede os marcados `sync: false`):
   - API: **`JWT_SECRET`**, **`APP_BASE_URL`** = `https://agente-viagens-api-backend.onrender.com` (ou a URL real da tua API no Render).
   - Site estático: **`API_BASE_URL`** = a mesma URL base da API (ex.: `https://agente-viagens-api-backend.onrender.com`).
5. **Schema na base:** após a API estar no ar com `DATABASE_URL` correto, **Shell** no Web Service da API → `npm run db:init` (ou corre `npm run db:init` localmente com o mesmo `DATABASE_URL` do Neon).
6. **Google / SMTP:** opcional — adiciona no painel da API (como no `.env` de exemplo).
7. **WebSocket / CORS:** cliente com `https` na API → `wss`. CORS restrito a **`CORS_ALLOWED_ORIGINS`** (lista separada por vírgulas); inclui a origem HTTPS exacta do Flutter Web na Netlify.

O primeiro build do **site Flutter** no Render descarrega o SDK (demorado). Se falhar por timeout, volta a **Deploy** manual ou gera `build/web` localmente e publica na Netlify.

#### Save in Cloud (opcional)

Deploy alternativo (Postgres + Node + estático ou só Node) — ver `DOCUMENTACAO_ATUAL.md` §16 como referência histórica; o fluxo principal do repositório voltou a **Render + Netlify**.

##### Subir o código para o GitHub (linha de comandos)

Na pasta do projeto (com Git instalado):

```bash
git init
git add .
git commit -m "Initial commit: app viagens"
git branch -M main
git remote add origin https://github.com/TEU_USUARIO/TEU_REPO.git
git push -u origin main
```

Cria o repositório vazio em [github.com/new](https://github.com/new) antes do `remote add` / `push`. Não commits `backend/.env` nem pastas `build/` (já estão no `.gitignore`).

## Endpoints principais (REST)

**Autenticação**

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/forgot-password`
- `POST /api/auth/change-password`

**Viagens e entidades** (JWT)

- `GET/POST/PUT/DELETE /api/viagens`
- `GET /api/viagens/:id/members`
- `POST /api/viagens/:id/members/invite`
- `PATCH /api/viagens/:id/members/:memberId`
- `POST /api/viagens/invites/accept`
- `GET/POST /api/viagens/cidades/:viagemId`
- `GET/POST /api/viagens/hoteis/:cidadeId` — `restaurantes`, `passeios` idem
- `PUT/DELETE /api/viagens/:entity/item/:id`

**Integrações (JWT)**

- `POST /api/places/search`
- `POST /api/distance/calculate`

**Timeline** (JWT)

- `GET/POST /api/timeline/:viagemId`
- `PUT /api/timeline/item/:id`
- `DELETE /api/timeline/item/:id`
- `POST /api/timeline/:viagemId/gerar-tempo-livre-dias`

**Wishlist** (JWT)

- `GET /api/wishlist/:viagemId` — query opcional: `categoria`, `status`
- `POST /api/wishlist/:viagemId`
- `POST /api/wishlist/:viagemId/import-place`
- `PUT /api/wishlist/item/:id`
- `DELETE /api/wishlist/item/:id`

**Sugestões** (JWT)

- `GET /api/suggestions/for-bloco/:blocoId`
- `POST /api/suggestions/accept`
- `POST /api/suggestions/reject`
- `GET /api/suggestions/preferences/:viagemId`
- `PUT /api/suggestions/preferences/:viagemId`

**Transportes** (JWT)

- `GET /api/viagens/:viagemId/meios-transporte`
- `POST /api/viagens/:viagemId/meios-transporte`
- `PUT /api/viagens/:viagemId/meios-transporte/:mtId`
- `DELETE /api/viagens/:viagemId/meios-transporte/:mtId`

**Documentos** (JWT)

- `GET /api/viagens/:viagemId/documentos`
- `POST /api/viagens/:viagemId/documentos/upload` (multipart; campo `arquivo`, apenas PDF até 20MB)
- `GET /api/viagens/:viagemId/documentos/:documentoId/open`
- `DELETE /api/viagens/:viagemId/documentos/:documentoId`

**Google Drive OAuth**

- `GET /api/drive/oauth/start`
- `GET /api/drive/oauth/callback`

**Health**

- `GET /health`

### Documentação

| Documento | Conteúdo |
|-----------|----------|
| **`DOCUMENTACAO_ATUAL.md`** | Estado técnico do sistema (API, schema, Flutter, WebSocket, design); deploy Render + Netlify; Save in §16 opcional |
| **`ENTREGAS_E_PENDENCIAS.md`** | O que foi entregue e o que falta (backlog resumido) |
| **`PLANO_EVOLUCAO_V2.md`** | Roadmap TripWeave (fases 0–6) |
| **`GUIA_IDENTIDADE_VISUAL.md`** | Tokens e padrões de UI para novas telas Flutter |
| **`MANUAL_USUARIO.md`** | Manual de uso por tela + fluxos de dados |

Legado / referência: **`Documentação Sistema/Ponto de Restauração v1.1.md`** e **`Documentação Sistema/Ponto de Restauração v1.1.docx`** (o `Ponto de Restauração v1.0.doc` na mesma pasta é baseline anterior). Para regenerar o `.docx` a partir do Markdown: `python Documentação Sistema/gerar_ponto_restauracao_docx.py`.

## Segurança

- `.env` não deve ser versionado (use `.gitignore`).
- Senhas armazenadas com hash (`bcrypt`).
- Rotas de negócio protegidas com JWT (`Authorization: Bearer …`).
- Rate limiting global no Express.

## Dependências Flutter relevantes

- `http` — cliente REST
- `flutter_map` / `latlong2` — mapa da wishlist

## Atualizacao 27/04/2026

- Listagem de transportes: companhia e localizador na mesma linha (destaque igual); datas/horas em negrito nos resumos de trecho.

## Atualizacao 06/05/2026

- **Produção:** fluxo principal **Render** (API `https://agente-viagens-api-backend.onrender.com`) + **Netlify** (Flutter Web). Removido o serviço de ficheiros estáticos em `backend/public/web/` no Express; **CORS** em fallback volta a incluir **`https://agentepessoaldaviagem.netlify.app`** e localhost.
- **`lib/services/api_service.dart`:** `API_BASE_URL` por omissão (sem `--dart-define`) = URL da API no Render acima.

## Atualizacao 05/05/2026

- Documentação Save in / opção Express em `public/web` (revertida em 06/05); histórico nas versões anteriores do Git se necessário.

## Atualizacao 04/05/2026

- Documentação de deploy na **Save in Cloud (Jelastic):** mesmo ambiente com **Postgres + Node (API) + site estático Flutter Web**; **Gestor de Implantação** + Git; **`ROOT_DIR=/home/jelastic/ROOT/backend`**; validação **`GET /health`**; Web SSH e `nodejs.log`.
- **CORS** em `backend/server.js`: lista **`CORS_ALLOWED_ORIGINS`** apenas (sem `origin: true` por `NODE_ENV` no código actual).

## Atualizacao 29/04/2026

- Modulo de **Documentos da viagem** implementado na aba da viagem (campos `tipo_arquivo` e `observacao`, upload de PDF e exclusao).
- Upload real de PDF para Google Drive com subpasta por viagem (`viagem_<id>`) dentro da pasta pai configurada por `DRIVE_PARENT_FOLDER_ID`.
- Fluxo OAuth do Google Drive no backend (`/api/drive/oauth/start` e `/api/drive/oauth/callback`) para uso com conta Google pessoal.
- Novos endpoints de documentos: listar, upload, abrir e excluir.
- CORS ajustado para **origens restritas** por `CORS_ALLOWED_ORIGINS` (separadas por vírgula).

## Atualizacao 26/04/2026

- Transportes migrados para modelo de reserva + trechos.
- Campo `observacoes` em reserva de transporte.
- Formulario Flutter de transportes atualizado (`meio_transporte_form_screen_v2`).
- Filtros na listagem de transportes:
  - tipo (todos/voo/carro/trem)
  - companhia aerea (somente quando tipo = voo).
- Home:
  - destaque da viagem mais proxima
  - ordenacao das demais por data inicial
  - exclusao de viagem com confirmacao.

### Deploy seguro backend (producao)

Depois de deploy da API, execute:

```bash
cd backend
npm run db:init
```

Isto garante aplicacao de alteracoes de schema/migracoes no banco de producao.
