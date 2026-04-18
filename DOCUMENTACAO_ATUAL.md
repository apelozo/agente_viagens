# App Viagens — Documento de referência do estado atual

**Consolidação:** 15/04/2026  
**Objetivo:** descrever fielmente o que está implementado no repositório (backend + Flutter), para planejamento e onboarding.

**Índice de documentos:** estado detalhado (este ficheiro) · entregas vs pendências: `ENTREGAS_E_PENDENCIAS.md` · roadmap: `PLANO_EVOLUCAO_V2.md` · identidade visual (guia rápido): `GUIA_IDENTIDADE_VISUAL.md`.

---

## 1) Visão geral

Solução full-stack para **gerenciar viagens** e entidades relacionadas (cidades, hotéis, restaurantes, passeios), com **timeline por blocos** (evento fixo / tempo livre), **wishlist** com mapa, **sugestões** a partir de blocos de tempo livre e preferências por viagem, **proxy** para Google Places e Distance Matrix (chaves só no servidor), **JWT** e **WebSocket** para broadcast de eventos de CRUD.

---

## 2) Estrutura do repositório

| Área | Conteúdo |
|------|-----------|
| `lib/` | App Flutter: telas, serviços HTTP, tema, widgets |
| `backend/` | API Express: rotas, controllers, serviços DB/Places/Distance/WebSocket |
| `backend/models/schema.sql` | Schema PostgreSQL único (inclui tabelas de timeline, wishlist e preferências) |
| `web/` | Bootstrap Flutter Web |

### Frontend (`lib/`)

- **`main.dart`** — fluxo login/cadastro → `HomeScreen`; `ApiService` + `AuthService`
- **`screens/`** — `login_screen`, `register_screen`, `home_screen`, `trip_detail_screen`, `city_detail_screen`, `timeline_screen`, `wishlist_screen`, `suggestions_bloco_screen`, `places_search_results_screen`
- **`services/`** — `api_service`, `auth_service`, `place_service`, `distance_service`
- **`models/`** — `viagem`, `user`
- **`theme/`** — `app_theme` (cores, tema Material, **tokens** `AppGradients`, `AppLayout`, `AppDecor`)
- **`widgets/`** — `app_button`, `app_card`, `app_input`, `app_modal`, **`app_screen_chrome`** (`AppGradientBackground`, `AppScreenChrome.appBar`), `timeline_mobility_segment`

Formulários de entidades (hotéis, restaurantes, passeios) estão integrados ao fluxo de detalhe da viagem/cidade dentro de `trip_detail_screen.dart` / `city_detail_screen.dart`.

### Backend

- **`server.js`** — Express, CORS, JSON, rate limit, rotas, WebSocket no mesmo `http.Server`
- **`routes/`** — `auth`, `viagens`, `places`, `distance`, `timeline`, `wishlist`, `suggestions`
- **`controllers/`** — lógica dos endpoints
- **`services/`** — PostgreSQL (`databaseService`), Places, Distance Matrix, WebSocket
- **`middleware/`** — JWT (`authRequired`), rate limit, error handler

---

## 3) Stack tecnológica

| Camada | Tecnologia |
|--------|------------|
| App | Flutter 3.x, Dart ≥ 3.3, `http`, `flutter_map` + `latlong2` (mapas da wishlist) |
| API | Node.js, Express |
| BD | PostgreSQL (`pg`) |
| Auth | JWT (`jsonwebtoken`), senhas com `bcrypt` |
| Tempo real | `ws` — broadcast para todos os clientes conectados (sem tópicos por viagem) |
| Externas | Google Places / Distance Matrix via backend (Axios) |

---

## 4) Modelo de dados (schema)

Definido em `backend/models/schema.sql`. Principais tabelas:

- **`usuarios`** — `tipo`: `Usuario` \| `Agente de Viagem`; `status` da conta
- **`agente_clientes`** — vínculo agente ↔ cliente (o agente enxerga viagens dos clientes vinculados)
- **`viagens`** — pertence a `usuarios` via `user_id`
- **`cidades`**, **`hoteis`**, **`restaurantes`**, **`passeios`** — hierarquia viagem → cidade → demais entidades
- **`roteiro_blocos`** — blocos da timeline: `tipo` `Evento Fixo` \| `Tempo Livre`; data/horários; `created_by`
- **`wishlist_itens`** — por viagem e usuário; categoria, coordenadas, status, rating, etc.
- **`travel_preferences`** — preferências por viagem (uma linha por `viagem_id`, usadas no motor de sugestões)

Índices relevantes: viagens por usuário, cidades por viagem, blocos por viagem/data, wishlist por viagem/categoria/status.

---

## 5) Regras de acesso às viagens

- **Usuário comum:** apenas viagens onde `user_id` = seu id.
- **Agente de Viagem:** viagens próprias **ou** de clientes presentes em `agente_clientes`.

Timeline, wishlist e sugestões validam acesso com `userCanAccessViagem` (mesma regra).

---

## 6) API REST — referência

Todas as rotas abaixo (exceto health e auth de registro/login) exigem header `Authorization: Bearer <token>` quando indicado.

### Health

- `GET /health` → `{ ok: true }`

### Autenticação

- `POST /api/auth/register`
- `POST /api/auth/login`

### Viagens e entidades aninhadas

- `GET /api/viagens` — query opcional: `page`, `pageSize`
- `POST /api/viagens`
- `PUT /api/viagens/:id`
- `DELETE /api/viagens/:id`

Entidades: `cidades` (pai = id da viagem), `hoteis` / `restaurantes` / `passeios` (pai = id da cidade):

- `GET /api/viagens/:entity/:parentId`
- `POST /api/viagens/:entity/:parentId`
- `PUT /api/viagens/:entity/item/:id`
- `DELETE /api/viagens/:entity/item/:id`

### Integrações (proxy)

- `POST /api/places/search`
- `POST /api/distance/calculate`

### Timeline (`roteiro_blocos`)

- `GET /api/timeline/:viagemId` — lista blocos da viagem
- `POST /api/timeline/:viagemId` — cria bloco
- `PUT /api/timeline/item/:id` — atualiza
- `DELETE /api/timeline/item/:id` — remove
- `POST /api/timeline/:viagemId/gerar-tempo-livre-dias` — gera blocos de tempo livre por dia (rota registrada explicitamente em `server.js`)

### Wishlist

- `GET /api/wishlist/:viagemId` — query opcional: `categoria`, `status`
- `POST /api/wishlist/:viagemId` — cria item manual
- `POST /api/wishlist/:viagemId/import-place` — importa a partir de lugar (Places)
- `PUT /api/wishlist/item/:id`
- `DELETE /api/wishlist/item/:id`

### Sugestões e preferências

- `GET /api/suggestions/for-bloco/:blocoId` — ranqueia itens da wishlist para um bloco de tempo livre
- `POST /api/suggestions/accept` — aceita sugestão (cria/atualiza bloco, atualiza status do item)
- `POST /api/suggestions/reject`
- `GET /api/suggestions/preferences/:viagemId`
- `PUT /api/suggestions/preferences/:viagemId`

---

## 7) WebSocket

- Servidor: mesmo host/porta do HTTP (pacote `ws`).
- Ao conectar, o cliente recebe uma mensagem JSON `{ type: "connected", ... }`.
- Em mudanças relevantes, o servidor envia `{ event, payload, ts }`.

Eventos emitidos (não exaustivo): `viagem_created` / `viagem_updated` / `viagem_deleted`; `cidades_*`, `hoteis_*`, `restaurantes_*`, `passeios_*`; `timeline_block_*`; `wishlist_*`.

**Estado no Flutter:** `RealtimeService` abre WebSocket após login (`HomeScreen` chama `connect()`). Várias telas subscrevem `pushes` (home, detalhe da viagem, wishlist, timeline): atualizam listas ou mostram *SnackBars*. A home exibe estado da ligação (ex.: “Ao vivo”). **Não** há ainda autenticação no handshake nem subscrição por `viagem_id` (broadcast global no servidor).

---

## 8) Frontend — funcionalidades entregues

- Login e cadastro
- Home: viagem em destaque, lista paginada, CRUD de viagem, estado vazio
- Detalhe da viagem: cidades, busca Places, atalhos para **Timeline** e **Wishlist**
- Detalhe da cidade: hotéis, restaurantes, passeios (formulários e mapas auxiliares conforme tela)
- **Timeline:** blocos por dia, tipos fixo/tempo livre, geração de tempo livre, CRUD de blocos; estimativa de deslocamento **só** entre dois “Evento Fixo”, **após** toque num ícone (evita chamadas em massa); trechos que envolvem “Tempo Livre” **não** disparam Places/Distance Matrix
- **Wishlist:** lista, filtros, criação manual e via Places, **mapa** com pins
- **Sugestões:** para bloco de tempo livre, preferências por viagem, aceitar sugestão (integração com timeline/wishlist)

### Configuração da URL da API (Flutter)

Em `lib/services/api_service.dart`, a base URL vem de `--dart-define=API_BASE_URL`, com **fallback** embutido para desenvolvimento. Para outro host/porta:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:5000
```

---

## 9) Design e UX (identidade visual)

A **dashboard** (`HomeScreen`) define o padrão: gradiente vertical `AppColors.lightBlue` → branco, títulos com `headlineLarge` / `titleLarge`, CTA laranja (`AppButton`), cartões brancos com borda suave (`AppCard`).

Esse padrão foi **generalizado** a todas as telas principais:

| Token / componente | Ficheiro | Uso |
|--------------------|----------|-----|
| `AppGradients.screenBackground` | `lib/theme/app_theme.dart` | Fundo em gradiente (igual à dashboard) |
| `AppLayout.screenPadding` | idem | Margens horizontais 24 e verticais 16/24 |
| `AppDecor.whiteTopSheet()` | idem | Painel branco com cantos superiores arredondados + sombra (ex.: detalhe viagem, resultados Places) |
| `AppGradientBackground` | `lib/widgets/app_screen_chrome.dart` | Envolve o corpo do ecrã com o gradiente |
| `AppScreenChrome.appBar(...)` | idem | AppBar com faixa `lightBlue`, título alinhado ao tema |

O tema global (`AppTheme.theme`) inclui AppBar em `lightBlue`, *SnackBar* flutuante arredondada e `TabBar` com indicador laranja. Detalhe: `GUIA_IDENTIDADE_VISUAL.md`.

Outros ajustes de UX: Enter no login, fluxos de detalhe e formulários de entidade com secções em `titleLarge`.

---

## 10) Scripts e execução local

### Backend

```bash
cd backend
npm install
npm run db:init
npm start
```

Porta padrão: **`5000`** (`PORT` no `.env`). Desenvolvimento com reload: `npm run dev`.

### Flutter

```bash
flutter pub get
flutter run -d chrome
# ou dispositivo móvel/emulador
```

Garantir que o app aponte para o mesmo host/porta do backend (`API_BASE_URL`).

Variáveis de ambiente do backend: ver `README.md` na raiz (Google, `DATABASE_URL`, `JWT_SECRET`, `PORT`).

---

## 11) Qualidade e testes

- Há `flutter_test` no projeto; convém manter `flutter analyze` limpo ao evoluir o código.
- O plano mestre de evolução (TripWeave / fases v2) está em `PLANO_EVOLUCAO_V2.md`, com nota de alinhamento ao que já foi entregue fora do prefixo `/api/v2`.
- Lista consolidada do que está entregue e do que falta: `ENTREGAS_E_PENDENCIAS.md`.

---

## 12) Lacunas em relação à visão de longo prazo

Ainda **não** estão no escopo atual do código (ou só parcialmente no plano):

- API versionada em `/api/v2/...` (hoje rotas estáveis em `/api/timeline`, `/api/wishlist`, etc.)
- Importação de roteiro por link/QR/código
- WebSocket autenticado, tópicos por `viagem_id` e consumo no Flutter
- Colaboração multiusuário com papéis (owner/editor/viewer) e convites
- Modo offline robusto e sincronização
- PostGIS / geoespacial avançado no banco

Para detalhamento de fases futuras, usar `PLANO_EVOLUCAO_V2.md`.
