# Documentação da estrutura do projeto — App de Viagens

**Nome do produto (UI):** Agente Pessoal da Viagem  
**Pacote Flutter:** `app_viagens`  
**Tipo:** aplicação full-stack — cliente multiplataforma (Flutter) + API REST (Node.js) + base de dados relacional (PostgreSQL).

Este documento descreve a **arquitetura em alto nível**, as **tecnologias** utilizadas e a **organização das pastas** do repositório.

---

## 1. Visão geral da arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter (Android / Web / iOS*)                                  │
│  • UI Material • HTTP (REST) • WebSocket (tempo real)            │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTPS / WSS
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Backend Node.js (Express)                                        │
│  • JWT • CORS • Rate limiting • Proxy Google (Places / Distance) │
│  • WebSocket (broadcast de eventos)                               │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PostgreSQL (ex.: Neon, local, ou outro hospedeiro)               │
└─────────────────────────────────────────────────────────────────┘
                             ▲
┌────────────────────────────┴────────────────────────────────────┐
│  APIs externas (chaves só no servidor)                           │
│  Google Places API • Google Distance Matrix API                  │
└─────────────────────────────────────────────────────────────────┘
```

\* *iOS pode ser alvo Flutter se o projeto for configurado para essa plataforma.*

---

## 2. Stack tecnológico

### 2.1 Frontend (cliente)

| Tecnologia | Uso |
|------------|-----|
| **Flutter** | Framework UI multiplataforma (Material Design). |
| **Dart** | Linguagem (SDK ≥ 3.3). |
| **pacote `http`** | Chamadas HTTP à API REST. |
| **pacote `web_socket_channel`** | Ligação WebSocket para eventos em tempo real. |
| **pacote `flutter_map` + `latlong2`** | Mapas (ex.: wishlist). |
| **pacote `url_launcher`** | Abrir URLs externas (navegador, apps). |
| **pacote `geolocator`** | Localização do dispositivo quando aplicável. |
| **pacote `mask_text_input_formatter`** | Máscaras em campos (datas, horas, etc.). |

**Estado da aplicação:** gestão principal com `StatefulWidget` e serviços partilhados (`ApiService`, `AuthService`, `RealtimeService`), sem framework de estado global obrigatório (ex.: Riverpod) no código atual.

**Configuração da URL da API:** constante de compilação `API_BASE_URL` (`String.fromEnvironment`), definida em tempo de build com `--dart-define=API_BASE_URL=...`.

### 2.2 Backend (servidor)

| Tecnologia | Uso |
|------------|-----|
| **Node.js** (≥ 18 em produção recomendado) | Runtime JavaScript. |
| **Express** | Servidor HTTP, rotas REST, middleware. |
| **PostgreSQL** | Persistência relacional (`pg` / connection pool). |
| **bcrypt** | Hash de palavras-passe. |
| **jsonwebtoken** | Tokens JWT para sessões autenticadas. |
| **cors** | Política de origens cruzadas (browser / Flutter Web). |
| **ws** | Servidor WebSocket no mesmo processo HTTP. |
| **axios** | Chamadas HTTP saídas (ex.: integrações). |
| **nodemailer** | Envio de e-mail (recuperação de password, convites). |
| **dotenv** | Variáveis de ambiente em desenvolvimento local. |

### 2.3 Base de dados e integrações

| Componente | Função |
|------------|--------|
| **PostgreSQL** | Esquema definido em `backend/models/schema.sql` (utilizadores, viagens, cidades, entidades, timeline, wishlist, preferências, meios de transporte, etc.). |
| **Google Places** (via backend) | Pesquisa de locais; chaves em variáveis de ambiente no servidor. |
| **Google Distance Matrix** (via backend) | Cálculo de distâncias / tempos entre pontos. |

### 2.4 Infraestrutura e deploy (referência)

| Ferramenta | Papel típico neste projeto |
|------------|----------------------------|
| **Git / GitHub** | Controlo de versões e origem do código. |
| **Render** (ou similar) | Hospedagem do backend e/ou site estático gerado pelo Flutter Web. |
| **Neon** (ou similar) | PostgreSQL gerido na nuvem. |
| **Netlify / Render Static** | Servir ficheiros estáticos do `flutter build web`. |

Ficheiros de apoio na raiz: `render.yaml`, `scripts/render-build-web.sh`, `web/_redirects`.

---

## 3. Estrutura do repositório (pastas principais)

```
app_viagens/
├── android/                 # Projeto Android (Gradle, Kotlin, manifestos)
├── web/                     # Entrada Flutter Web (index.html, manifest PWA, _redirects)
├── assets/                  # Recursos estáticos (imagens)
├── backend/                 # API Node.js + SQL + scripts de base de dados
├── lib/                     # Código Dart da aplicação Flutter
├── test/                    # Testes Flutter (widget_test, etc.)
├── pubspec.yaml             # Dependências e metadados Flutter
├── render.yaml              # Blueprint Render (API + site estático)
├── README.md                # Setup e referência rápida
└── DOCUMENTACAO_*.md        # Documentação complementar (incluindo este ficheiro)
```

---

## 4. Frontend — organização em `lib/`

| Pasta / ficheiro | Responsabilidade |
|-------------------|------------------|
| **`main.dart`** | Ponto de entrada: `MaterialApp`, tema, fluxo login/registo/home, injeção de `ApiService`, `AuthService`, `RealtimeService`. |
| **`screens/`** | Ecrãs: login, registo, home (lista de viagens), detalhe da viagem (cidades, transportes), detalhe da cidade (hotéis, restaurantes, passeios), timeline, formulários de blocos, wishlist, sugestões, preferências de mobilidade, pesquisa Places, conta, formulários de transporte e itens wishlist. |
| **`services/`** | **`api_service.dart`** — cliente HTTP e URL base; **`auth_service.dart`** — login/registo/logout; **`realtime_service.dart`** — WebSocket e pushes; **`place_service.dart`**, **`distance_service.dart`**, **`trip_preferences_service.dart`** — chamadas de domínio. |
| **`models/`** | Modelos Dart (`viagem.dart`, `user.dart`) alinhados à API. |
| **`theme/`** | **`app_theme.dart`** — cores, gradientes, decorações (identidade visual). |
| **`widgets/`** | Componentes reutilizáveis: `app_button`, `app_card`, `app_modal`, `app_input`, `app_screen_chrome`, `timeline_mobility_segment`, etc. |

**Fluxo típico:** o utilizador autentica-se → `HomeScreen` lista viagens → navegação para detalhe, timeline, wishlist e restantes ecrãs, sempre comunicando com o backend via `ApiService` (JWT no header quando existir token).

---

## 5. Backend — organização em `backend/`

| Área | Conteúdo |
|------|----------|
| **`server.js`** | Arranque: Express, middlewares, montagem das rotas `/api/...`, criação do servidor HTTP e inicialização do WebSocket. |
| **`config/`** | **`db.js`** — pool PostgreSQL (com SSL para bases não locais); **`googleApiConfig.js`** — chaves e URLs das APIs Google. |
| **`routes/`** | Definição de rotas: `auth`, `viagens` (inclui cidades, entidades, meios de transporte), `places`, `distance`, `timeline`, `wishlist`, `suggestions`. |
| **`controllers/`** | Lógica HTTP por domínio (viagens, auth, timeline, wishlist, places, distance, sugestões, meios de transporte). |
| **`models/`** | **`schema.sql`** — DDL completo; **`userModel`**, **`viagemModel`** — acesso a dados relacionado a utilizadores/viagens. |
| **`middleware/`** | Autenticação JWT (`auth.js`), rate limiting, tratamento de erros. |
| **`services/`** | **`databaseService.js`** — camada de query; **`websocketService.js`** — broadcast; **`googlePlacesService`**, **`googleDistanceService`**, **`emailService`**. |
| **`utils/`** | Funções auxiliares (ex.: geo). |
| **`scripts/`** | **`initDb.js`** — aplica `schema.sql`; migrações SQL pontuais. |

**Endpoints** seguem o prefixo `/api` (ver `README.md` para lista resumida). O WebSocket partilha o mesmo host/porta que a API; o cliente Flutter deriva `ws`/`wss` a partir de `API_BASE_URL`.

---

## 6. Modelo de dados (resumo)

O ficheiro `backend/models/schema.sql` é a fonte de verdade. Inclui, entre outras:

- **Utilizadores** (`usuarios`) e relação agente–cliente (`agente_clientes`).
- **Viagens** (`viagens`) e **membros / convites** (`viagem_membros`, `convites_viagem`) para cenários colaborativos.
- **Cidades** e entidades por cidade: **hotéis**, **restaurantes**, **passeios**.
- **Roteiro** (`roteiro_blocos`) — blocos por dia (evento fixo / tempo livre).
- **Wishlist**, **preferências de viagem**, **meios de transporte** (com assentos em JSON quando aplicável).
- Tabelas de apoio às funcionalidades de sugestões e mobilidade, conforme evolução do schema.

---

## 7. Tempo real (WebSocket)

- O servidor emite mensagens JSON com `event`, `payload` e `ts`.
- O cliente `RealtimeService` liga quando há token JWT e escuta atualizações; vários ecrãs reagem (home, detalhe de viagem, wishlist, timeline).
- Não há, no estado atual, “salas” por `viagem_id` no servidor — é um broadcast geral a clientes ligados.

---

## 8. Segurança e configuração

- **JWT** no header `Authorization: Bearer …` para rotas protegidas.
- **Chaves Google** e **credenciais de base** apenas no backend (nunca embutidas no cliente).
- **CORS** configurado no Express para permitir chamadas a partir do domínio onde o Flutter Web está servido (em produção deve ser restrito ao domínio real).
- **Variáveis de ambiente** no backend: `DATABASE_URL`, `JWT_SECRET`, `APP_BASE_URL`, chaves Google, SMTP, `PORT`, etc.

---

## 9. Documentos relacionados no repositório

| Ficheiro | Tema |
|----------|------|
| `README.md` | Setup local, builds, Netlify, Render, variáveis `.env`. |
| `DOCUMENTACAO_ATUAL.md` | Estado técnico detalhado (se existir e estiver atualizado). |
| `ENTREGAS_E_PENDENCIAS.md` | Entregas vs backlog. |
| `PLANO_EVOLUCAO_V2.md` | Roadmap de produto. |
| `MANUAL_USUARIO.md` | Manual funcional para utilizadores. |

---

## 10. Resumo

O projeto **App de Viagens** é uma solução **Flutter + Node.js + PostgreSQL**, com **autenticação JWT**, **integrações Google** via servidor, **WebSocket** para atualizações em tempo real e uma **UI** organizada em ecrãs e serviços Dart. A estrutura de pastas separa claramente **cliente** (`lib/`), **servidor** (`backend/`) e **ficheiros de plataforma** (`android/`, `web/`), facilitando deploy independente do API e do frontend estático ou mobile.

---

*Documento gerado para descrever a estrutura e tecnologias do projeto; ajustar sempre que o repositório evoluir.*
