# App Viagens - Plano Completo de Evolucao v2.0 (TripWeave)

Data: 15/04/2026

## Estado atual em relacao a este plano (consolidado em 15/04/2026)

Varias capacidades previstas nas **Fases 1 a 3** ja existem no codigo, com rotas **sem** o prefixo `/api/v2` (mantendo simplicidade operacional). Referencia tecnica: `DOCUMENTACAO_ATUAL.md`.

| Fase no plano | Situacao resumida |
|---------------|-------------------|
| Fase 1 - Timeline | **Entregue:** tabela `roteiro_blocos`, API `/api/timeline/...`, tela Flutter `timeline_screen.dart`, blocos `Evento Fixo` / `Tempo Livre`, geracao de tempo livre por dia. |
| Fase 2 - Wishlist | **Entregue:** tabela `wishlist_itens`, API `/api/wishlist/...`, import via Places, filtros, tela com lista e mapa (`flutter_map`). |
| Fase 3 - Sugestoes | **Entregue (v1):** motor por regras em `suggestionsController`, preferencias em `travel_preferences`, endpoints `/api/suggestions/...`, tela `suggestions_bloco_screen.dart`. |
| Fase 4 - Mobilidade | **Parcial:** backend `POST /api/distance/calculate`; na timeline, estimativa **sob demanda** entre dois “Evento Fixo” (`timeline_mobility_segment`). Falta comparador rico, rotas `/api/v2/mobility/*` e previsão por pico conforme plano. |
| Fase 5 - Colaboracao | **Pendente** (sem `viagem_membros` / convites no schema atual). |
| Fase 6 - Offline / sync | **Pendente.** |
| Backlog transversal | **Parcial:** WebSocket existe com **broadcast global**; falta auth no handshake, topicos por viagem e **consumo no Flutter**. Migrations versionadas e `/api/v2` ainda nao padronizados como no texto original do plano. |

Este documento continua valido como **roadmap** para as fases restantes e para evolucoes transversais; ajuste mental: implementacoes atuais usam os paths listados em `DOCUMENTACAO_ATUAL.md`.

## 1) Objetivo da Versao 2.0

Evoluir o produto atual para o conceito "Roteiro Vivo" com:

- Timeline dinamica (eventos fixos + tempo livre)
- Wishlist geolocalizada
- Sugestoes inteligentes para blocos livres
- Mobilidade realista (rotas e tempo por modal)
- Colaboracao entre co-viajantes
- Base para offline-first e sincronizacao

Meta principal: manter compatibilidade com o que ja existe, entregando valor em fases curtas e validaveis.

## 2) Principios de Implementacao

- Evolucao incremental, sem reescrita completa
- Compatibilidade retroativa das rotas atuais
- Entregas por modulo com criterios de aceite claros
- Observabilidade e testes desde o inicio
- Feature flags para ativar modulos gradualmente

## 3) Roadmap Macro (Fases)

## Fase 0 - Preparacao (1 semana)

### Entregaveis

- Definicao final de escopo MVP v2
- Documento de arquitetura tecnica (backend + app + dados)
- Padrao de versionamento de API (`/api/v2/...`)
- Convencao de migrations SQL
- Instrumentacao minima de logs por request/erro

### Criterio de aceite

- Time alinhado em backlog tecnico priorizado
- Infra local/homolog pronta para v2

## Fase 1 - Espinha Dorsal: Timeline (2 a 3 semanas)

### Novas capacidades

- Modelo de roteiro por dia e blocos
- Distincao visual e semantica:
  - `evento_fixo`
  - `tempo_livre`

### Banco (novas tabelas)

- `roteiros` (metadados e origem/importacao)
- `roteiro_dias` (dia da viagem)
- `roteiro_blocos` (inicio/fim/tipo/status)
- `roteiro_eventos` (descricao, local, coordenadas, origem)

### Backend (novas rotas)

- `GET /api/v2/viagens/:id/timeline`
- `POST /api/v2/viagens/:id/roteiro/import`
- `POST /api/v2/roteiro/blocos`
- `PUT /api/v2/roteiro/blocos/:id`
- `DELETE /api/v2/roteiro/blocos/:id`

### Frontend

- Tela Timeline por dia
- Destaque visual para blocos livres
- Leitura inicial do roteiro importado

### Criterios de aceite

- Usuario consegue visualizar agenda diaria completa
- Blocos livres aparecem claramente em relacao aos eventos fixos
- Dados persistem e recarregam sem inconsistencias

## Fase 2 - Wishlist Geolocalizada (2 semanas)

### Novas capacidades

- Captura de desejos (manual e via Places)
- Categorizacao (`Comer`, `Visitar`, `Comprar`)
- Status (`nao_visitado`, `planejado`, `concluido`, `descartado`)
- Mapa com pins da wishlist

### Banco

- `wishlist_itens`
  - `viagem_id`, `user_id`, `categoria`, `nome`, `endereco`
  - `latitude`, `longitude`, `fonte`, `nota`, `rating`, `foto_url`
- indices por viagem, categoria e geolocalizacao basica

### Backend

- `GET /api/v2/viagens/:id/wishlist`
- `POST /api/v2/viagens/:id/wishlist`
- `PUT /api/v2/wishlist/:id`
- `DELETE /api/v2/wishlist/:id`
- `POST /api/v2/wishlist/import/places`

### Frontend

- Tela Wishlist (lista)
- Tela Mapa da Wishlist
- Filtros por categoria e status

### Criterios de aceite

- Usuario adiciona item em <= 20 segundos
- Item aparece em lista e mapa
- Filtro por categoria funcional

## Fase 3 - Sugestoes Inteligentes (2 a 3 semanas)

### Novas capacidades

- Motor de recomendacao para blocos de tempo livre
- Ranking por:
  - distancia/tempo
  - categoria preferida
  - janela de tempo disponivel
  - status do item

### Banco

- `travel_preferences`
  - `dietary`, `budget_level`, `pace`, `touristic_level`, `mobility_pref`
- `suggestion_runs` (auditoria de sugestoes geradas)

### Backend

- `POST /api/v2/suggestions/generate`
- `GET /api/v2/viagens/:id/suggestions?blocoId=...`
- `POST /api/v2/suggestions/:id/accept`
- `POST /api/v2/suggestions/:id/reject`

### Algoritmo v1 (regras deterministicas)

- Filtra por preferencias obrigatorias
- Remove itens inviaveis por janela de tempo
- Ordena por score ponderado (tempo + preferencia + proximidade)

### Criterios de aceite

- Sugestoes coerentes com tempo livre e localizacao
- Usuario consegue aceitar sugestao e inserir no roteiro

## Fase 4 - Mobilidade Realista (1 a 2 semanas)

### Novas capacidades

- ETA por modal (a pe, transporte publico, carro)
- Comparador de opcoes de deslocamento
- Ajuste de previsao por horario de pico (se API suportar)

### Backend

- `POST /api/v2/mobility/estimate`
- `POST /api/v2/mobility/compare`

### Frontend

- Componente de mobilidade no detalhe do bloco/sugestao
- Preferencia de transporte por usuario/viagem

### Criterios de aceite

- App exibe tempo de deslocamento por modal com consistencia
- Usuario define modal padrao

## Fase 5 - Colaboracao (2 a 3 semanas)

### Novas capacidades

- Convite de co-viajantes
- Permissoes por papel:
  - owner
  - editor
  - viewer
- Wishlist compartilhada e timeline compartilhada
- Sincronizacao near-real-time via WebSocket

### Banco

- `viagem_membros` (user_id, viagem_id, role, invited_by, status)
- `convites_viagem` (token, expira_em, status)
- trilha de auditoria opcional (`activity_log`)

### Backend

- `POST /api/v2/viagens/:id/invite`
- `POST /api/v2/invites/:token/accept`
- `GET /api/v2/viagens/:id/members`
- `PATCH /api/v2/viagens/:id/members/:memberId`

### Frontend

- Tela de membros
- Fluxo de convite/aceite
- Atualizacao em tempo real de mudancas criticas

### Criterios de aceite

- Membro convidado acessa roteiro compartilhado
- Regras de permissao respeitadas em CRUD

## Fase 6 - Offline First e Sync (3 semanas)

### Novas capacidades

- Cache local de timeline/wishlist
- Fila de operacoes offline (create/update/delete)
- Sincronizacao ao reconectar
- Resolucao basica de conflito (last-write + aviso ao usuario)

### Tecnica sugerida

- Flutter:
  - `isar` ou `drift` para cache local
  - repositorio com estrategia `local-first + sync`
- Backend:
  - suporte a `updated_at` e `version`/`etag`
  - endpoint de delta sync por viagem

### Criterios de aceite

- Usuario consulta roteiro sem internet
- Alteracoes offline sincronizam sem perda ao reconectar

## 4) Backlog Tecnico Consolidado

## 4.1 Banco e Migrations

- Introduzir `migrations/` versionadas
- Criar novas tabelas v2
- Adicionar `created_at`, `updated_at` padrao
- Adicionar soft delete onde fizer sentido (`deleted_at`)
- Planejar futura extensao PostGIS (fase posterior)

## 4.2 API e Dominio

- Criar camada de servicos por modulo (timeline, wishlist, suggestion, collaboration)
- Validacao de payload com schema (`zod`/`joi`)
- Padronizar erros (`code`, `message`, `details`)
- Versionar API sem quebrar endpoints atuais

## 4.3 Frontend Flutter

- Introduzir state management escalavel (Riverpod recomendado)
- Separar `data`, `domain`, `presentation`
- Criar design tokens centralizados no tema
- Padronizar formularios com validacoes reutilizaveis

## 4.4 Realtime

- Evoluir canal WebSocket:
  - autenticacao no handshake
  - topicos por `viagem_id`
  - reconexao e re-sync

## 4.5 Seguranca

- Rate limit por endpoint sensivel
- Rotacao de JWT secret em ambiente controlado
- Revisao de CORS por ambiente
- Sanitizacao de entrada e output encoding

## 4.6 Observabilidade

- Logs estruturados (request_id, user_id, endpoint, latency)
- Metricas de erro/latencia
- Alertas para falhas de API externa (Places/Distance)

## 5) Plano de Testes Completo

## 5.1 Backend

- Testes unitarios de servicos (score de sugestao, regras de permissao)
- Testes de integracao de rotas com DB de teste
- Testes de contrato para payloads v2

## 5.2 Frontend

- Widget tests de telas criticas (timeline, wishlist, sugestoes)
- Golden tests para consistencia visual dos componentes principais
- Testes de fluxo (login -> timeline -> adicionar wishlist -> sugestao)

## 5.3 E2E

- Cenarios end-to-end com dados seed:
  - importacao de roteiro
  - bloco livre + sugestao + aceite
  - colaboracao com 2 usuarios
  - comportamento offline/reconexao

## 5.4 Criterio de saida por fase

- Sem regressao no fluxo atual
- Cobertura minima acordada (ex.: 70% servicos criticos)
- Sem blockers de seguranca

## 6) Cronograma Sugerido (estimativa)

- Fase 0: 1 semana
- Fase 1: 2-3 semanas
- Fase 2: 2 semanas
- Fase 3: 2-3 semanas
- Fase 4: 1-2 semanas
- Fase 5: 2-3 semanas
- Fase 6: 3 semanas

Total estimado: 13 a 17 semanas (dependendo do tamanho do time e paralelizacao).

## 7) Riscos e Mitigacoes

- Dependencia de APIs externas (latencia/cota)
  - mitigar com cache e fallback
- Complexidade de offline + conflito
  - iniciar com estrategia simples, evoluir por iteracao
- Escopo muito amplo no MVP
  - priorizar fases 1-3 para validacao de produto

## 8) Priorizacao Recomendada (MVP v2 realista)

Prioridade 1:

- Fase 1 (Timeline)
- Fase 2 (Wishlist)
- Fase 3 (Sugestoes v1)

Prioridade 2:

- Fase 4 (Mobilidade)
- Fase 5 (Colaboracao)

Prioridade 3:

- Fase 6 (Offline robusto)

## 9) Definicao de Pronto (Definition of Done) para cada historia

- Codigo revisado
- Testes adicionados e verdes
- Logs minimos e tratamento de erro
- UI responsiva mobile
- Documentacao de endpoint atualizada
- Sem regressao no fluxo existente

## 10) Proximos Passos Imediatos

1. Priorizar backlog **apos** timeline/wishlist/sugestoes v1 ja entregues: por exemplo **mobilidade (Fase 4)**, **colaboracao (Fase 5)** ou **offline/sync (Fase 6)** conforme produto.
2. Decidir se havera **convivencia** entre rotas atuais (`/api/timeline`, etc.) e futuras rotas `/api/v2/...`, ou migracao com deprecacao.
3. Evoluir **WebSocket**: autenticacao, rooms por `viagem_id`, reconexao; **cliente Flutter** para atualizacao em tempo quase real.
4. (Opcional) Introduzir **migrations** SQL versionadas e logs estruturados conforme secao 4 do plano.
5. Validar com usuarios e refinar escopo das fases pendentes.

---

Este documento e o plano mestre de evolucao do projeto, podendo ser refinado a cada fim de fase com base em aprendizado real de uso.

