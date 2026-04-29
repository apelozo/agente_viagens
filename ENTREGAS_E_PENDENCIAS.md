# Entregas realizadas e trabalho pendente

**Última atualização:** 27/04/2026  
**Objetivo:** registo único do que já foi implementado no projeto e do que continua em aberto, alinhado a `DOCUMENTACAO_ATUAL.md` e `PLANO_EVOLUCAO_V2.md`.

---

## 1. Resumo executivo

| Área | Estado |
|------|--------|
| Autenticação (JWT), viagens, cidades, hotéis, restaurantes, passeios | Entregue |
| Timeline (`roteiro_blocos`, evento fixo / tempo livre, geração por dia) | Entregue |
| Wishlist (lista, mapa, Places, filtros) | Entregue |
| Sugestões para blocos de tempo livre + preferências por viagem | Entregue (v1 por regras) |
| Proxy Google Places e Distance Matrix no backend | Entregue |
| WebSocket: servidor com broadcast; cliente Flutter conecta e reage em várias telas | Entregue (sem tópicos por viagem) |
| Documentos por viagem (upload PDF no Google Drive, abrir e excluir) | Entregue |
| Identidade visual unificada (gradiente, AppBar, tokens, telas) | Entregue |
| Estimativa de deslocamento na timeline (entre eventos fixos) | Entregue com cálculo **sob demanda** (ícone); **sem** chamadas API em trechos com tempo livre |
| Fase C (próximo marco de produto) | **Não iniciada** — definir escopo no backlog |

---

## 2. Entregas por domínio

### 2.1 Backend

- API Express com rotas em `/api/...` (sem prefixo `/api/v2` por decisão de simplicidade).
- PostgreSQL: schema em `backend/models/schema.sql` (usuários, viagens, cidades, entidades, `roteiro_blocos`, `wishlist_itens`, `travel_preferences`, etc.).
- Autenticação JWT, `bcrypt`, rate limiting, CORS.
- Controllers para viagens, timeline, wishlist, sugestões, Places, distância.
- WebSocket (`ws`) no mesmo processo HTTP, broadcast de eventos de CRUD.
- Regras de acesso: utilizador vê só as suas viagens; agente vê também viagens de clientes ligados em `agente_clientes`.
- Documentos por viagem com upload de PDF (`multipart`) para Google Drive e metadados em `viagem_documentos`.
- Fluxo OAuth no backend para Google Drive (`/api/drive/oauth/start` e `/api/drive/oauth/callback`) para conta pessoal.
- CORS de produção por lista de origens via `CORS_ALLOWED_ORIGINS`.

### 2.2 Frontend (Flutter)

- Fluxo: login / registo → home com lista de viagens e viagem em destaque.
- Detalhe da viagem: cidades, transporte entre cidades (coordenadas), atalhos Timeline e Wishlist, formulários de entidades.
- Detalhe da cidade: hotéis, restaurantes, passeios.
- **Timeline:** blocos por dia, CRUD, geração de blocos “Tempo livre” por dia, integração com sugestões e preferências de mobilidade.
- **Wishlist:** abas lista/mapa, filtros, importação Places, itens manuais.
- **Sugestões:** ecrã por bloco de tempo livre, preferências de viagem, aceitar sugestão (integração com timeline/wishlist).
- **Resultados Places:** listagem após busca para escolha de local.
- Serviços: `ApiService`, `AuthService`, `RealtimeService`, `DistanceService`, `TripPreferencesService`, etc.
- **Tempo real:** `HomeScreen` chama `realtime.connect()`; home, detalhe de viagem, wishlist e timeline subscrevem `pushes` e atualizam dados ou mostram *snackbars*; indicador “Ao vivo” na home.

### 2.3 Mobilidade na timeline (refinamento “Fase B”)

- Entre dois blocos **Evento Fixo**, o utilizador vê um ícone de rota; só após toque é feita geocodificação (Places) + `POST /api/distance/calculate`.
- Se **qualquer** dos dois blocos for **Tempo Livre**, o segmento de mobilidade **não é mostrado** (evita chamadas e tráfego sem sentido de negócio).

### 2.4 Identidade visual (dashboard → resto da app)

- Tokens em `lib/theme/app_theme.dart`: `AppGradients.screenBackground`, `AppLayout`, `AppDecor.whiteTopSheet`.
- Componentes em `lib/widgets/app_screen_chrome.dart`: `AppGradientBackground`, `AppScreenChrome.appBar(...)`.
- Tema: AppBar com faixa `lightBlue`, `SnackBar` flutuante, `TabBar` com indicador laranja.
- Telas alinhadas ao padrão da dashboard: home, login, registo, detalhe viagem, detalhe cidade, wishlist, timeline, sugestões, resultados Places, formulário de entidades (`EntityFormScreen`).

---

## 3. O que falta ou está parcial (backlog)

### 3.1 Plano TripWeave (`PLANO_EVOLUCAO_V2.md`)

| Fase | Tema | Situação |
|------|------|----------|
| 0 | Preparação (migrations, `/api/v2`, arquitetura) | Pendente |
| 1–3 | Timeline, wishlist, sugestões | **Entregue** no código atual (rotas sem `/api/v2`) |
| 4 | Mobilidade “realista” (ETA dedicado, comparador, picos) | **Parcial:** Distance Matrix genérico + UX na timeline; faltam endpoints `/api/v2/mobility/*` e comparador rico do plano |
| 5 | Colaboração (membros, convites, papéis) | Pendente (sem tabelas `viagem_membros`, etc.) |
| 6 | Offline e sincronização | Pendente |
| Transversal | WebSocket autenticado + salas por `viagem_id` | Pendente |
| Transversal | API versionada `/api/v2` e migrations SQL versionadas | Pendente |
| Transversal | State management em camadas (ex. Riverpod), testes automatizados alargados | Pendente |

### 3.2 Lacunas já listadas em `DOCUMENTACAO_ATUAL.md`

- Importação de roteiro por link/QR/código.
- Colaboração multiutilizador com papéis e convites.
- Modo offline robusto.
- PostGIS / geoespacial avançado no servidor.

### 3.3 Melhorias opcionais recentemente mencionadas

- Alinhar **modais** (`app_modal.dart`) e **diálogos** ao mesmo sistema de cores e raios do tema.
- **Fase C:** o próximo bloco de funcionalidades deve ser descrito e priorizado no backlog (nome “Fase C” é interno ao processo de desenvolvimento; não corresponde necessariamente a uma única linha do plano v2).

### 3.4 Documentação e qualidade

- Manter `dart analyze` / testes ao evoluir o código.
- Atualizar este ficheiro e `DOCUMENTACAO_ATUAL.md` quando uma fase fechar.

---

## 4. Ficheiros de referência no repositório

| Ficheiro | Conteúdo |
|----------|----------|
| `DOCUMENTACAO_ATUAL.md` | Estado técnico detalhado (API, schema, frontend, configuração) |
| `PLANO_EVOLUCAO_V2.md` | Roadmap TripWeave, fases 0–6, riscos, DoD |
| `README.md` | Setup rápido, variáveis de ambiente, links |
| `Documentação Sistema/Ponto de Restauração v1.1.md` | Documento mestre legado do sistema |
| `MANUAL_USUARIO.md` | Manual funcional do utilizador (telas + fluxos de dados) |
| `ENTREGAS_E_PENDENCIAS.md` | Este ficheiro — entregas vs pendências |

---

*Este documento deve ser atualizado sempre que uma entrega relevante fechar ou o backlog mudar de prioridade.*

### 3.5 Transportes (novo direcionamento para pr�xima itera��o)

**Atualiza��o:** 25/04/2026

Direcionamento acordado para resolver conex�es no m�dulo de transportes:

- Introduzir uma entidade de **reserva de transporte** (pai) identificada por localizador.
- Tratar cada conex�o/perna como **trecho** vinculado � reserva.
- Manter assentos em n�vel de trecho para voo/trem.
- Agrupar visualmente na UI por localizador, com resumo do primeiro trecho para facilitar identifica��o.

Impacto esperado por tipo:

- **Voo:** passa a suportar m�ltiplos trechos e assentos distintos por conex�o.
- **Trem:** suporta conex�es sob mesmo localizador quando necess�rio.
- **Carro:** mant�m fluxo simples (reserva �nica com trecho �nico na maioria dos casos).

Situacao: **implementado** no codigo em 26/04/2026.

---

## 5. Atualizacao 26/04/2026 (consolidacao)

### 5.1 Entregas concluidas neste ciclo

- Refatoracao de transportes para modelo de **reserva + trechos + assentos por trecho**.
- Campo `observacoes` adicionado no nivel da reserva de transporte.
- Formulario de transportes v2 no Flutter com:
  - multiplos trechos para voo/trem
  - fluxo simples para carro
  - lista fixa de companhias aereas para voo
  - Enter para avancar foco e salvar no ultimo campo.
- Listagem de transportes com:
  - filtro por tipo
  - filtro por companhia aerea (apenas quando tipo = voo)
  - exibicao de trechos, assentos por trecho e observacoes
  - reset de filtros ao abrir aba de transportes.
- Home/dashboard:
  - viagem principal selecionada pela mais proxima (regra por data)
  - demais viagens ordenadas por data inicial
  - exclusao de viagem com confirmacao.

### 5.2 Ajustes operacionais e deploy

- CORS ajustado para producao no backend.
- Processo de deploy reforcado:
  1) push do backend
  2) deploy no Render
  3) execucao de `npm run db:init` no ambiente da API
  4) validacao por endpoint (`/api/viagens/:id/meios-transporte`).

### 5.3 Riscos residuais

- Divergencia entre frontend deployado e backend deployado pode mascarar funcionalidades novas.
- Divergencia de `DATABASE_URL` entre ambiente esperado e ambiente em execucao pode causar leitura parcial.

---

## 6. Atualização 27/04/2026

- **Listagem de transportes** (`trip_detail_screen.dart`): companhia e localizador na **mesma linha** (localizador à direita), tipografia igual entre os dois em destaque; valores de **data e hora** de saída/chegada em **negrito**.
- **CORS** (`backend/server.js`): em **desenvolvimento** (`NODE_ENV` diferente de `production`), aceita qualquer origem (`origin: true`); em **produção**, mantém lista restrita de domínios.

---

## 7. Atualização 29/04/2026

- **Documentos da viagem**: nova aba no detalhe da viagem com listagem simplificada (`tipo_arquivo` e `observacao`).
- **Upload real de PDF**: envio de arquivo local (desktop/mobile) para Google Drive, com subpasta automática por viagem (`viagem_<id>`).
- **Google OAuth**: autorização via conta Google pessoal implementada no backend (`/api/drive/oauth/start` e `/api/drive/oauth/callback`).
- **Abertura e exclusão**: clique no tipo abre o documento; exclusão remove registro no banco e tenta remover o arquivo no Drive.
- **CORS de produção**: backend passou a usar `CORS_ALLOWED_ORIGINS` (lista por vírgula) para origens permitidas.
