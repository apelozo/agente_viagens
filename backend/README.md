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
# Render: Netlify + domínio customizado (apex e www). Várias origens: vírgula, sem espaços.
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

Sem `API_BASE_URL`, o fallback em `api_service.dart` aponta para a API no Render (`https://agente-viagens-api-backend.onrender.com`) — ajuste com `--dart-define` para outro host.

### Build Android e Web (release)

Na raiz do projeto (defina a URL pública do backend; use `https` em produção):

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://seu-servidor.com
flutter build web --release --dart-define=API_BASE_URL=https://seu-servidor.com
```

- **APK Android:** `build/app/outputs/flutter-apk/app-release.apk` (instalação direta no telemóvel).
- **App Bundle (Google Play):** `flutter build appbundle --release --dart-define=API_BASE_URL=...` → `build/app/outputs/bundle/release/app-release.aab`.
- **Web estático:** pasta `build/web` → **Netlify** (ver **`README.md` na raiz**). O backend no **Render** deve ter **`CORS_ALLOWED_ORIGINS`** com a origem HTTPS exacta do site.
- **Assinatura Play Store:** copie `android/key.properties.example` para `android/key.properties`, coloque o `.jks` em `android/app/` e preencha as palavras-passe (ficheiros sensíveis já estão no `.gitignore`).

#### Render (backend API + Flutter Web) e Neon

O repositório inclui **`render.yaml`** (Blueprint) com dois serviços: **API** (`backend/`) e **site estático** (Flutter Web via `scripts/render-build-web.sh`). A base pode ficar só no **[Neon](https://neon.tech)** — cola o connection string em **`DATABASE_URL`** na API (não precisas de Postgres no Render).

**Resumo:** `server.js` usa `PORT` do Render e **`GET /health`**. O **Static Site** precisa da variável de build **`API_BASE_URL`** = URL `https` do teu backend (mesmo valor que usas no app).

1. **GitHub:** envia o projeto para um repositório (vê secção “Git” abaixo). Repositório **público** costuma ser necessário para **plano free** no Render — confirma as regras atuais na tua conta.
2. **Neon:** copia o **connection string** PostgreSQL → no Render, no serviço da API, define **`DATABASE_URL`**.
3. **Blueprint:** no Render, **New → Blueprint**, liga o repo e deixa detetar `render.yaml`, ou cria manualmente os dois serviços com os mesmos valores do ficheiro.
4. **Segredos no painel** (o assistente pede os marcados `sync: false`):
   - API: **`JWT_SECRET`**, **`APP_BASE_URL`** = `https://agente-viagens-api-backend.onrender.com` (ou a URL real da tua API).
   - Site estático Render: **`API_BASE_URL`** = a mesma URL base da API.
5. **Schema na base:** após a API estar no ar com `DATABASE_URL` correto, **Shell** no Web Service da API → `npm run db:init` (ou corre `npm run db:init` localmente com o mesmo `DATABASE_URL` do Neon).
6. **Google / SMTP:** opcional — adiciona no painel da API (como no `.env` de exemplo).
7. **WebSocket / CORS:** cliente com `https` na API → `wss`. CORS restrito a **`CORS_ALLOWED_ORIGINS`** (lista separada por vírgulas); incluir a origem HTTPS exacta do site na **Netlify**.

#### Netlify (Flutter Web)

Instruções: **`README.md` na raiz**, secção *Netlify (site estático)*.

O primeiro build do **site Flutter** no Render descarrega o SDK (demorado). Se falhar por timeout, volta a **Deploy** manual ou considera gerar `build/web` noutro CI e publicar só os ficheiros estáticos.

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

**Health**

- `GET /health`

### Documentação

| Documento | Conteúdo |
|-----------|----------|
| **`DOCUMENTACAO_ATUAL.md`** (raiz) | Estado técnico; deploy Render + Netlify §18 |
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
