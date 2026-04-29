# App Viagens — Documento de referência do estado atual

**Consolidação:** 27/04/2026  
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
| `backend/models/schema.sql` | Schema PostgreSQL único (inclui tabelas de timeline, wishlist, preferências e documentos) |
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
- **`routes/`** — `auth`, `viagens`, `places`, `distance`, `timeline`, `wishlist`, `suggestions`, `drive`
- **`controllers/`** — lógica dos endpoints
- **`services/`** — PostgreSQL (`databaseService`), Places, Distance Matrix, Google Drive, WebSocket
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
- **`viagem_documentos`** — documentos por viagem com metadados de upload no Google Drive

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

### Documentos por viagem

- `GET /api/viagens/:viagemId/documentos`
- `POST /api/viagens/:viagemId/documentos/upload` (multipart; campo `arquivo`; PDF <= 20MB)
- `GET /api/viagens/:viagemId/documentos/:documentoId/open`
- `DELETE /api/viagens/:viagemId/documentos/:documentoId`

### Google Drive OAuth

- `GET /api/drive/oauth/start`
- `GET /api/drive/oauth/callback`

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
- **Documentos:** upload de PDF por viagem para Google Drive (subpasta `viagem_<id>`), listagem por `tipo_arquivo`/`observacao`, abertura por link e exclusão

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

Variáveis de ambiente do backend: ver `README.md` na raiz (Google, `DATABASE_URL`, `JWT_SECRET`, `PORT`, `DRIVE_PARENT_FOLDER_ID`, OAuth e `CORS_ALLOWED_ORIGINS`).

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

---

## 13) Decis�o de arquitetura em discuss�o: Transportes (conex�es por localizador)

**Atualiza��o:** 25/04/2026

Para suportar cen�rios de voo com m�ltiplas conex�es (inclusive com companhias diferentes no mesmo localizador), a proposta priorizada para a pr�xima itera��o � introduzir uma entidade de **reserva** acima dos trechos:

- Nova entidade pai: `viagem_reservas_transporte` (ou nome equivalente) com `viagem_id`, `tipo`, `codigo_localizador` e metadados da reserva.
- A tabela de trechos (`viagem_meios_transporte`) passa a representar cada perna/segmento e referencia a reserva pai (`reserva_id`).
- Assentos continuam por trecho em `viagem_meio_transporte_assentos` (n�o por reserva), permitindo classes/assentos diferentes por conex�o.

Impacto funcional esperado por tipo:

- **Voo:** uma reserva pode ter m�ltiplos trechos e assentos distintos por trecho (principal ganho da mudan�a).
- **Trem:** suporta um ou mais trechos sob o mesmo localizador quando houver conex�o.
- **Carro:** continua simples (tipicamente 1 reserva -> 1 trecho retirada/devolu��o).

Impacto de UX previsto:

- Listagem de transportes agrupada por localizador/reserva.
- Cart�o de reserva com resumo de �algum trecho� (ex.: `GRU -> MIA`) para identifica��o visual r�pida.
- Expans�o para visualizar todos os trechos da reserva e a��es de editar/excluir por trecho.

Nota: os dados existentes s�o poucos e podem ser recriados manualmente, reduzindo risco de migra��o complexa.

---

## 14) Atualizacao 26/04/2026

### 14.1 Transportes (implementado no codigo)

O modulo de transportes foi migrado para arquitetura de reserva + trechos:

- Reserva (pai): `viagem_reservas_transporte`
  - campos principais: `viagem_id`, `tipo`, `companhia`, `codigo_localizador`, `observacoes`
- Trecho (filho): `viagem_reserva_trechos`
  - campos principais: `reserva_id`, `ordem`, `ponto_a`, `ponto_b`, `data_a`, `hora_a`, `data_b`, `hora_b`
- Assentos por trecho: `viagem_reserva_trecho_assentos`

Compatibilidade:

- Controller de transportes mantem fallback para leitura de dados legados (`viagem_meios_transporte`) quando necessario.
- API continua em `/api/viagens/:viagemId/meios-transporte`, retornando `trechos` e campos de compatibilidade para telas antigas.

### 14.2 UX de transportes

- Formulario novo: `lib/screens/meio_transporte_form_screen_v2.dart`
- `carro`: fluxo simples com 1 trecho
- `voo` e `trem`: suportam multiplos trechos
- Assentos por trecho para `voo`/`trem`
- Campo de observacoes no nivel da reserva
- Lista fixa de companhias aereas para tipo `voo`
- Enter avanca para o proximo campo e, no ultimo, executa salvar

### 14.3 Listagem de transportes

`trip_detail_screen.dart`:

- filtro por tipo (`todos`, `voo`, `carro`, `trem`)
- filtro por companhia aerea visivel apenas quando tipo = `voo`
- exibicao de trechos e assentos por trecho
- exibicao de observacoes da reserva
- reset de filtros ao entrar na aba Transportes para evitar "sumi�o" por filtro antigo
- exibicao de erro de carga de transportes na tela (nao fica mais silencioso)
- **Linha da reserva:** `Companhia:` e `Localizador:` na **mesma linha** (companhia à esquerda, localizador à direita), mesma tipografia em destaque (negrito, fonte uniforme entre os dois campos).
- **Datas e horas:** valores de saída/chegada em **negrito** nos textos `Saída/retirada` / `Chegada/devolução` (sem trechos e com lista de trechos).

### 14.4 Home / dashboard

`home_screen.dart`:

- viagem em destaque selecionada automaticamente pela mais proxima:
  1) viagem em andamento
  2) proxima viagem futura
  3) viagens passadas
- "outras viagens" ordenadas por `dataInicial`
- exclusao de viagem implementada com confirmacao:
  - mensagem: `Confirma exclusao da viagem e todos os seus cadastros ?`
- formulario de viagem com fluxo de Enter:
  - descricao -> data inicial -> data final -> salvar

### 14.5 CORS (desenvolvimento vs producao)

Em `backend/server.js`:

- **Producao** (`NODE_ENV=production`): CORS com **lista restrita** de origens (ex.: site Netlify).
- **Desenvolvimento** (qualquer valor de `NODE_ENV` que **nao** seja `production`): `origin: true`, aceitando **qualquer origem** para facilitar testes locais (Flutter Web em portas diferentes, IP da rede, etc.).

Fluxo recomendado apos deploy do backend em producao: executar `npm run db:init` para aplicar alteracoes de schema/migracao.

## 15) Atualizacao 29/04/2026

### 15.1 Documentos com Google Drive

- Upload real de PDF implementado no backend e Flutter (apenas PDF, limite 20MB).
- Upload cria/usa subpasta por viagem no Drive (`viagem_<id>`) dentro da pasta pai configurada por `DRIVE_PARENT_FOLDER_ID`.
- Arquivo recebe permissao publica por link na criacao.
- Cadastro e listagem na aba Documentos da viagem exibem apenas `tipo_arquivo` e `observacao`.
- Exclusao de documento remove no banco e tenta remover no Drive.

### 15.2 OAuth Google Drive (conta pessoal)

- Rotas adicionadas:
  - `GET /api/drive/oauth/start`
  - `GET /api/drive/oauth/callback`
- Backend suporta OAuth (`GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `GOOGLE_OAUTH_REDIRECT_URI`) com persistencia local do token (`GOOGLE_OAUTH_TOKEN_PATH`).

### 15.3 CORS em producao

- CORS agora usa lista de origens permitidas por variavel de ambiente `CORS_ALLOWED_ORIGINS` (separadas por virgula), com fallback para o dominio Netlify.
