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

### Build Android e Web (release)

Na raiz do projeto (defina a URL pública do backend; use `https` em produção):

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://seu-servidor.com
flutter build web --release --dart-define=API_BASE_URL=https://seu-servidor.com
```

- **APK Android:** `build/app/outputs/flutter-apk/app-release.apk` (instalação direta no telemóvel).
- **App Bundle (Google Play):** `flutter build appbundle --release --dart-define=API_BASE_URL=...` → `build/app/outputs/bundle/release/app-release.aab`.
- **Web estático:** pasta `build/web` (servir com qualquer servidor HTTP(S); o backend deve permitir **CORS** para o domínio onde o site fica).
- **Assinatura Play Store:** copie `android/key.properties.example` para `android/key.properties`, coloque o `.jks` em `android/app/` e preencha as palavras-passe (ficheiros sensíveis já estão no `.gitignore`).

#### Netlify (site estático)

1. Na máquina de desenvolvimento, com a URL **HTTPS** do teu backend:  
   `flutter build web --release --dart-define=API_BASE_URL=https://api.teudominio.com`
2. A pasta a enviar é `build/web` (já inclui `web/_redirects` → regra SPA para não dar 404 ao recarregar).
3. **Opção A — Netlify Drop:** [app.netlify.com/drop](https://app.netlify.com/drop) → arrasta a pasta `build/web`.
4. **Opção B — Netlify CLI:** instala a CLI, na raiz do projeto:  
   `netlify deploy --dir=build/web` (pré-visualização) ou `netlify deploy --dir=build/web --prod` (produção). Na primeira vez faz login e associa um site.
5. O Netlify **não inclui Flutter** no ambiente de build por omissão. Para deploy **a partir do Git** com build automático, usa **GitHub Actions** (ou outro CI) para correr `flutter build web` e enviar `build/web`, ou um script que instale o SDK Flutter no CI.

#### Render (backend API + Flutter Web) e Neon

O repositório inclui **`render.yaml`** (Blueprint) com dois serviços: **API** (`backend/`) e **site estático** (Flutter Web via `scripts/render-build-web.sh`). A base pode ficar só no **[Neon](https://neon.tech)** — cola o connection string em **`DATABASE_URL`** na API (não precisas de Postgres no Render).

**Resumo:** `server.js` usa `PORT` do Render e **`GET /health`**. O **Static Site** precisa da variável de build **`API_BASE_URL`** = URL `https` do teu backend (mesmo valor que usas no app).

1. **GitHub:** envia o projeto para um repositório (vê secção “Git” abaixo). Repositório **público** costuma ser necessário para **plano free** no Render — confirma as regras atuais na tua conta.
2. **Neon:** copia o **connection string** PostgreSQL → no Render, no serviço da API, define **`DATABASE_URL`**.
3. **Blueprint:** no Render, **New → Blueprint**, liga o repo e deixa detetar `render.yaml`, ou cria manualmente os dois serviços com os mesmos valores do ficheiro.
4. **Segredos no painel** (o assistente pede os marcados `sync: false`):
   - API: **`JWT_SECRET`**, **`APP_BASE_URL`** = `https://<nome-api>.onrender.com` (URL real após o primeiro deploy).
   - Site estático: **`API_BASE_URL`** = a mesma URL base do API (ex.: `https://<nome-api>.onrender.com`).
5. **Schema na base:** após a API estar no ar com `DATABASE_URL` correto, **Shell** no Web Service da API → `npm run db:init` (ou corre `npm run db:init` localmente com o mesmo `DATABASE_URL` do Neon).
6. **Google / SMTP:** opcional — adiciona no painel da API (como no `.env` de exemplo).
7. **WebSocket / CORS:** cliente com `https` na API → `wss`; `cors()` aberto permite o site no outro domínio `.onrender.com`.

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
| **`DOCUMENTACAO_ATUAL.md`** | Estado técnico do sistema (API, schema, Flutter, WebSocket, design) |
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
