# Ponto de restauracao - App Viagens (v1.2)

**Tipo:** documento mestre (fonte unica de verdade operacional para retomada do projeto)  
**Data de referencia:** 16/04/2026  
**Relacao com versoes anteriores:** sucessor do arquivo `Ponto de Restauracao v1.0.doc` (mesma pasta); a **v1.2** incorpora o estado do codigo e da documentacao tecnica atual (`DOCUMENTACAO_ATUAL.md`, `README.md`, `PLANO_EVOLUCAO_V2.md`, `MANUAL_USUARIO.md`) sem substituir o ficheiro `.doc` original.

**Ambito:** apenas o que esta implementado ou explicitamente descrito no repositorio; especulacoes entram em **§7 Lacunas**.

---

## 1) Regras de negócio

### 1.1 Utilizadores e papéis

- Cada registo em `usuarios` tem **`tipo`**: `Usuario` ou `Agente de Viagem` (constraint SQL).
- O **`status`** da conta de utilizador admite: `Ativa`, `Cancelada`, `Finalizada` (valor por defeito na criação: `Ativa` no registo via API).
- **E-mail** é único no sistema.
- **Senha** é persistida apenas como hash (`bcrypt`); não é devolvida em respostas de API após registo (comportamento depende do `userModel`; o login devolve token + dados públicos do utilizador).

### 1.2 Agente de viagem e clientes

- A tabela `agente_clientes` modela vínculos **agente_id ↔ cliente_id** (chave composta).
- **Listagem de viagens** (`listViagens`):  
  - **Usuario:** apenas viagens com `viagens.user_id = id` do utilizador autenticado.  
  - **Agente de Viagem:** viagens em que `user_id` é o próprio agente **ou** o `user_id` é um `cliente_id` presente em `agente_clientes` com `agente_id` = utilizador autenticado.
- **Acesso a uma viagem concreta** (timeline, wishlist, sugestões): a mesma regra é aplicada via `userCanAccessViagem` — se não houver permissão, resposta **404** genérica (“Viagem não encontrada.”).

### 1.3 Viagens

- Uma **viagem** pertence a um utilizador dono (`viagens.user_id`).
- **`situacao`** da viagem: `Ativa`, `Cancelada`, `Finalizada` (constraint SQL).
- Intervalo **`data_inicial`** … **`data_final`** é obrigatório (tipo `DATE` no BD).

### 1.4 Hierarquia geográfica e entidades

- **Cidades** pertencem a uma viagem (`viagem_id`); podem ter `latitude` / `longitude` opcionais.
- **Hotéis**, **restaurantes** e **passeios** pertencem a uma **cidade** (`cidade_id`); eliminação em cascata a partir da viagem/cidade conforme FKs.

**Hotéis**

- `status_reserva`: `A Pagar` ou `Pago`.

**Passeios**

- `situacao` financeira: `A Pagar`, `Pago Parcial`, `Pago`, `Gratuito`.

### 1.5 Timeline (roteiro por blocos)

- Tabela `roteiro_blocos`: cada bloco está associado a uma **viagem** e a uma **data**.
- **`tipo`**: `Evento Fixo` ou `Tempo Livre` (constraint SQL).
- **Horários** `hora_inicio` / `hora_fim` são opcionais; a API valida que, se ambos existirem, **fim > início**.
- **Datas** aceites na API em formato brasileiro ou ISO; o backend normaliza para armazenamento.
- Blocos gerados automaticamente para “tempo livre” podem usar `descricao` interna `__gerado_sistema_tempo_livre__`, oculta na serialização para o cliente.
- **`local`** é texto livre (morada ou descrição humana; não obriga coordenadas).

### 1.6 Wishlist

- Itens em `wishlist_itens` associam **viagem**, **utilizador** (`user_id` do criador/contexto) e opcionalmente coordenadas.
- **`categoria`**: `Comer`, `Visitar`, `Comprar`, `Outras`.
- **`status`**: `nao_visitado`, `planejado`, `concluido`, `descartado` (default `nao_visitado`).
- Listagem pode filtrar por `categoria` e `status` (query string) com valores validados no servidor.

### 1.7 Sugestões e preferências de viagem

- Existe no máximo **um** registo de `travel_preferences` por `viagem_id` (constraint `UNIQUE`).
- O motor de sugestões (serviço em `suggestionsController`) combina blocos de **Tempo Livre**, itens da wishlist, distâncias (Haversine) e preferências gravadas para ranquear e propor aceitação/rejeição.
- **Aceitar** uma sugestão pode criar um bloco de timeline e atualizar o estado do item da wishlist para `planejado` (regra implementada no controller).

### 1.8 Autenticação e autorização

- Endpoints de negócio (exceto registo/login e health) exigem **JWT** no header `Authorization: Bearer <token>`.
- Token emitido no login com validade **12h** (campo `expiresIn` em `authController`).
- Payload JWT inclui pelo menos: `id`, `nome`, `tipo`, `email`.

### 1.9 Integrações externas

- **Google Places** e **Google Distance Matrix** são invocados **apenas no backend**; chaves em variáveis de ambiente. O cliente Flutter não contém chaves.

### 1.10 Tempo real (WebSocket)

- O servidor envia mensagens JSON com `event`, `payload` e `ts` após operações relevantes (viagens, entidades, timeline, wishlist).
- Não há autenticação no handshake nem subscrição por `viagem_id` no código atual — broadcast para todos os clientes ligados.

---

## 2) Estrutura de pastas

### 2.1 Raiz do projeto Flutter (`app_viagens/`)

Estrutura lógica (plataformas geradas pelo Flutter incluídas):

```text
app_viagens/
├── android/                 # Projeto Android nativo
├── ios/
├── linux/
├── macos/
├── windows/
├── web/                     # Bootstrap Flutter Web
├── backend/                 # API Node.js (ver §2.2)
├── lib/                     # Código Dart da aplicação (ver §2.3)
├── test/                    # Testes Flutter
├── Documentação Sistema/    # Documentos de restauração e afins
├── pubspec.yaml
├── README.md
├── DOCUMENTACAO_ATUAL.md
└── PLANO_EVOLUCAO_V2.md
```

*(Pastas `build/`, `.dart_tool/` são artefactos de compilação e não fazem parte do código-fonte versionável essencial.)*

### 2.2 Backend (`backend/`)

```text
backend/
├── config/
│   ├── db.js
│   └── googleApiConfig.js
├── controllers/
│   ├── authController.js
│   ├── viagensController.js
│   ├── placesController.js
│   ├── distanceController.js
│   ├── timelineController.js
│   ├── wishlistController.js
│   └── suggestionsController.js
├── middleware/
│   ├── auth.js
│   ├── errorHandler.js
│   └── rateLimiter.js
├── models/
│   ├── schema.sql
│   ├── userModel.js
│   └── viagemModel.js
├── routes/
│   ├── authRoutes.js
│   ├── viagensRoutes.js
│   ├── placesRoutes.js
│   ├── distanceRoutes.js
│   ├── timelineRoutes.js
│   ├── wishlistRoutes.js
│   └── suggestionsRoutes.js
├── scripts/
│   ├── initDb.js
│   └── migrateWishlistCategoriaOutras.sql
├── services/
│   ├── databaseService.js
│   ├── googlePlacesService.js
│   ├── googleDistanceService.js
│   └── websocketService.js
├── utils/
│   └── geo.js
├── package.json
├── package-lock.json
└── server.js
```

*(A pasta `node_modules/` contém dependências npm e não deve ser editada manualmente.)*

### 2.3 Frontend Flutter (`lib/`)

```text
lib/
├── main.dart
├── models/
│   ├── user.dart
│   └── viagem.dart
├── screens/
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart
│   ├── trip_detail_screen.dart
│   ├── city_detail_screen.dart
│   ├── timeline_screen.dart
│   ├── wishlist_screen.dart
│   ├── suggestions_bloco_screen.dart
│   └── places_search_results_screen.dart
├── services/
│   ├── api_service.dart
│   ├── auth_service.dart
│   ├── place_service.dart
│   └── distance_service.dart
├── theme/
│   └── app_theme.dart
└── widgets/
    ├── app_button.dart
    ├── app_card.dart
    ├── app_input.dart
    └── app_modal.dart
```

---

## 3) Estrutura da base de dados

Motor: **PostgreSQL**. Definição canónica: `backend/models/schema.sql`.

### 3.1 `usuarios`

| Campo        | Tipo        | Restrições / notas |
|-------------|-------------|--------------------|
| id          | SERIAL      | PK |
| nome        | TEXT        | NOT NULL |
| tipo        | VARCHAR(30) | NOT NULL; CHECK: `Usuario`, `Agente de Viagem` |
| email       | TEXT        | NOT NULL, UNIQUE |
| senha       | TEXT        | NOT NULL (hash) |
| status      | VARCHAR(20) | NOT NULL; CHECK: `Ativa`, `Cancelada`, `Finalizada`; default `Ativa` |
| created_at  | TIMESTAMP   | default NOW() |

### 3.2 `agente_clientes`

| Campo       | Tipo    | Restrições |
|------------|---------|------------|
| agente_id  | INTEGER | NOT NULL, FK → `usuarios(id)` ON DELETE CASCADE |
| cliente_id | INTEGER | NOT NULL, FK → `usuarios(id)` ON DELETE CASCADE |
| (composta) | —       | PRIMARY KEY (`agente_id`, `cliente_id`) |

**Cardinalidade:** N:M entre agentes e clientes, materializada nesta tabela de associação.

### 3.3 `viagens`

| Campo        | Tipo        | Restrições |
|-------------|-------------|------------|
| id          | SERIAL      | PK |
| descricao   | TEXT        | NOT NULL |
| data_inicial| DATE        | NOT NULL |
| data_final  | DATE        | NOT NULL |
| situacao    | VARCHAR(20) | NOT NULL; CHECK: `Ativa`, `Cancelada`, `Finalizada` |
| user_id     | INTEGER     | NOT NULL, FK → `usuarios(id)` ON DELETE CASCADE |

**Relação:** 1 utilizador → N viagens (donos). Índice `idx_viagens_user_id`.

### 3.4 `cidades`

| Campo     | Tipo          | Restrições |
|----------|---------------|------------|
| id       | SERIAL        | PK |
| descricao| TEXT          | NOT NULL |
| latitude | DECIMAL(10,7) | opcional |
| longitude| DECIMAL(10,7) | opcional |
| viagem_id| INTEGER       | NOT NULL, FK → `viagens(id)` ON DELETE CASCADE |

**Relação:** 1 viagem → N cidades. Índice `idx_cidades_viagem_id`.

### 3.5 `hoteis`

| Campo                 | Tipo          | Restrições |
|----------------------|---------------|------------|
| id                   | SERIAL        | PK |
| nome                 | TEXT          | NOT NULL |
| data_checkin/checkout| DATE          | opcional |
| endereco             | TEXT          | opcional |
| status_reserva       | VARCHAR(10)   | NOT NULL; CHECK: `A Pagar`, `Pago` |
| hora_checkin/out     | TIME          | opcional |
| cancelamento_gratuito| BOOLEAN       | opcional |
| latitude/longitude   | DECIMAL(10,7) | opcional |
| observacoes          | TEXT          | opcional |
| cidade_id            | INTEGER       | NOT NULL, FK → `cidades(id)` ON DELETE CASCADE |

**Relação:** 1 cidade → N hotéis. Índice `idx_hoteis_cidade_id`.

### 3.6 `restaurantes`

Campos principais: `nome` NOT NULL; `cidade_id` FK para `cidades`; campos opcionais de preço, reserva, geo, etc. Índice `idx_restaurantes_cidade_id`.

### 3.7 `passeios`

Campos principais: `nome` NOT NULL; `situacao` CHECK `A Pagar`|`Pago Parcial`|`Pago`|`Gratuito`; `cidade_id` FK. Índice `idx_passeios_cidade_id`.

### 3.8 `roteiro_blocos`

| Campo      | Tipo        | Restrições |
|-----------|-------------|------------|
| id        | SERIAL      | PK |
| viagem_id | INTEGER     | NOT NULL, FK → `viagens(id)` ON DELETE CASCADE |
| titulo    | TEXT        | NOT NULL |
| tipo      | VARCHAR(20) | NOT NULL; CHECK: `Evento Fixo`, `Tempo Livre` |
| data      | DATE        | NOT NULL |
| hora_inicio / hora_fim | TIME | opcional |
| local     | TEXT        | opcional |
| descricao | TEXT        | opcional |
| created_by| INTEGER     | FK → `usuarios(id)` ON DELETE SET NULL |
| created_at| TIMESTAMP   | default NOW() |

Índices: `idx_roteiro_blocos_viagem_id`, `idx_roteiro_blocos_data`.

### 3.9 `wishlist_itens`

| Campo     | Tipo          | Restrições |
|----------|---------------|------------|
| id       | SERIAL        | PK |
| viagem_id| INTEGER       | NOT NULL, FK → `viagens(id)` ON DELETE CASCADE |
| user_id  | INTEGER       | NOT NULL, FK → `usuarios(id)` ON DELETE CASCADE |
| categoria| VARCHAR(20)   | NOT NULL; CHECK: `Comer`, `Visitar`, `Comprar`, `Outras` |
| nome     | TEXT          | NOT NULL |
| endereco | TEXT          | opcional |
| lat/lng  | DECIMAL(10,7) | opcional |
| fonte, nota, rating, foto_url | diversos | opcional |
| status   | VARCHAR(20)   | NOT NULL; default `nao_visitado`; CHECK de estados |
| created_at | TIMESTAMP   | default NOW() |

Índices: `idx_wishlist_viagem_id`, `idx_wishlist_categoria`, `idx_wishlist_status`.

### 3.10 `travel_preferences`

| Campo             | Tipo        | Restrições |
|------------------|-------------|------------|
| id               | SERIAL      | PK |
| viagem_id        | INTEGER     | NOT NULL, UNIQUE, FK → `viagens(id)` ON DELETE CASCADE |
| user_id          | INTEGER     | FK → `usuarios(id)` ON DELETE SET NULL |
| prefer_categorias| TEXT        | opcional |
| dietary          | TEXT        | opcional |
| budget_level, pace, touristic_level, mobility_pref | VARCHAR(30) | opcional |
| updated_at       | TIMESTAMP   | default NOW() |

Índice `idx_travel_prefs_viagem`.

---

## 4) Programas / telas desenvolvidos (Flutter)

| Nome / ficheiro | Localização | Função resumida |
|-----------------|-------------|-----------------|
| Arranque da app | `lib/main.dart` | `MaterialApp`, estado login/registo, injeta `ApiService` e `AuthService`, encaminha para login, registo ou `HomeScreen`. |
| Login | `lib/screens/login_screen.dart` | Autenticação; navegação para registo ou home após sucesso. |
| Registo | `lib/screens/register_screen.dart` | Criação de conta. |
| Home | `lib/screens/home_screen.dart` | Lista e CRUD de viagens, destaque da viagem ativa. |
| Detalhe da viagem | `lib/screens/trip_detail_screen.dart` | Cidades, transportes/distâncias, navegação para cidade, timeline, wishlist, Places. |
| Detalhe da cidade | `lib/screens/city_detail_screen.dart` | Hotéis, restaurantes, passeios; formulários e exclusões. |
| Timeline | `lib/screens/timeline_screen.dart` | Blocos do roteiro por dia; CRUD; geração de tempo livre. |
| Wishlist | `lib/screens/wishlist_screen.dart` | Lista, filtros, mapa, criação manual e via Places. |
| Sugestões (bloco) | `lib/screens/suggestions_bloco_screen.dart` | Sugestões para bloco de tempo livre; preferências; aceitar/rejeitar. |
| Resultados Places | `lib/screens/places_search_results_screen.dart` | Seleção de resultados de pesquisa de locais. |
| Componentes UI | `lib/widgets/*.dart` | Botões, cartões, inputs, modais reutilizáveis. |
| Tema | `lib/theme/app_theme.dart` | Cores e estilos globais. |
| API / auth / Places / Distance | `lib/services/*.dart` | Chamadas HTTP e lógica de apoio ao cliente. |

Formulários de entidades (hotéis, restaurantes, passeios) estão integrados nas telas de detalhe conforme o código em `trip_detail_screen.dart` e `city_detail_screen.dart` (classes auxiliares no mesmo ficheiro ou importadas).

---

## 5) Definições técnicas

### 5.1 Stack

- **Cliente:** Flutter (Dart SDK ≥ 3.3), `http`, `flutter_map`, `latlong2`.
- **Servidor:** Node.js, Express, `pg`, `jsonwebtoken`, `bcrypt`, `ws`, `cors`, `dotenv`, `axios` (integrações Google via backend).
- **Base de dados:** PostgreSQL (ex.: Neon em ambiente remoto; `DATABASE_URL`).

### 5.2 Arquitetura observada

- API REST monolítica em Express; controladores por domínio; serviços para BD e integrações; middleware global de rate limit e tratamento de erros.
- Flutter em camadas simples: telas → serviços → HTTP; sem state management global além do estado local dos `StatefulWidget` no fluxo principal.

### 5.3 Ambiente e execução

- Backend: `npm run db:init` para aplicar schema; `npm start` ou `npm run dev`; porta padrão **5000** (`PORT`).
- Flutter: `flutter pub get`; `flutter run` com `--dart-define=API_BASE_URL=...` para apontar ao backend (ver `api_service.dart`).

### 5.4 Scripts de migração auxiliar

- `backend/scripts/migrateWishlistCategoriaOutras.sql` — evolução relacionada com categoria `Outras` na wishlist (aplicar manualmente em bases já existentes se necessário).

---

## 6) Links de acesso ao sistema (disponíveis no contexto local)

| Recurso | URL / forma de acesso |
|---------|------------------------|
| Health do backend | `http://localhost:5000/health` (ajustar host/porta conforme `PORT`) |
| API REST | Mesmo host/porta; prefixo `/api/...` |
| Aplicação Flutter | Execução local: `flutter run -d chrome` ou emulador/dispositivo; **não há URL pública fixa** no repositório |

Credenciais de produção ou URLs de deploy **não** constam do código; devem ser documentadas externamente se existirem.

---

## 7) Lacunas de informação (explicitas)

- Endereços/URLs de ambientes **cloud** (Neon, API em produção, app publicado) não estão no repositório como verdade única.
- O ficheiro `.env` real não é versionado; valores exatos de `JWT_SECRET` e chaves Google não devem ser reproduzidos em documentação pública.
- Políticas de **RGPD**, retenção de dados e termos de utilização não estão descritas no código.
- O documento **v1.0** em `.doc` pode conter nuances de redação diferentes; a **v1.1** prevalece para alinhamento técnico com o código na data indicada.
- Testes automatizados E2E e métricas de cobertura não estão consolidados neste ponto de restauração.

---

## Histórico de versões deste documento

| Versão | Ficheiro | Nota |
|--------|----------|------|
| v1.0 | `Ponto de Restauracao v1.0.doc` | Baseline historica (formato Word legado `.doc`). |
| v1.1 | `Ponto de Restauracao v1.1.md` | Atualizacao completa em Markdown, alinhada ao estado do repositorio em 15/04/2026. |
| v1.1 | `Ponto de Restauracao v1.1.docx` | Mesmo conteudo que o `.md`, em Word (estrutura por secoes, tabelas e listas; gerado por `gerar_ponto_restauracao_docx.py`). |
| v1.2 | `Ponto de Restauracao v1.1.md` | Marco incremental de retomada em 16/04/2026; inclui o manual funcional do utilizador em `MANUAL_USUARIO.md` e atualizacao de referencias cruzadas. |

Para evolução de produto futura, consultar `PLANO_EVOLUCAO_V2.md`; para detalhe de API e funcionalidades, `DOCUMENTACAO_ATUAL.md`.
