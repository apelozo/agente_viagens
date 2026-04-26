# Manual do Usuario - App Viagens

Data: 16/04/2026

## 1) Objetivo do aplicativo

O App Viagens ajuda voce a planejar e acompanhar viagens em um unico lugar:

- cadastrar viagens e cidades;
- organizar roteiro por blocos de tempo (eventos fixos e tempo livre);
- guardar ideias na wishlist (com lista e mapa);
- receber sugestoes com base no seu tempo livre e preferencias.

---

## 2) Como os dados funcionam (visao simples)

Fluxo geral:

1. Voce interage com uma tela no app (ex.: cria um evento).
2. O app envia a informacao para a API (backend).
3. A API valida permissoes e grava no banco de dados.
4. A API devolve o resultado para o app.
5. O app atualiza a tela e, quando aplicavel, recebe evento em tempo real para sincronizar outras telas abertas.

### Regras importantes de acesso

- Usuario comum: enxerga e edita apenas as proprias viagens.
- Agente de viagem: tambem pode acessar viagens de clientes vinculados.

---

## 3) Fluxo principal de uso (passo a passo)

1. Fazer login ou cadastro.
2. Criar uma viagem na Home.
3. Abrir detalhe da viagem e cadastrar cidades.
4. Em cada cidade, cadastrar hoteis, restaurantes e passeios.
5. Montar o roteiro em Eventos da Viagem (timeline).
6. Alimentar a wishlist com ideias (manual ou importacao por Places).
7. Usar sugestoes nos blocos de tempo livre para transformar ideias em eventos do roteiro.

---

## 4) Manual por tela

## 4.1 Login (`login_screen.dart`)

Para que serve:

- autenticar no sistema com email e senha.

O que voce encontra:

- campos de email e senha;
- botao de entrar;
- atalho para cadastro.

Fluxo de dados:

- app envia credenciais para autenticacao;
- recebendo sucesso, guarda token de sessao;
- redireciona para a Home.

---

## 4.2 Cadastro (`register_screen.dart`)

Para que serve:

- criar conta nova.

O que voce encontra:

- dados basicos de usuario;
- escolha de tipo de perfil (quando habilitado no fluxo).

Fluxo de dados:

- app envia dados de cadastro;
- backend cria usuario;
- voce passa a poder fazer login.

---

## 4.3 Home (`home_screen.dart`)

Para que serve:

- ser o painel principal de viagens.

O que voce encontra:

- viagem em destaque;
- lista de viagens;
- criar, editar e excluir viagem;
- indicador de conexao "Ao vivo".

Fluxo de dados:

- app consulta lista de viagens;
- operacoes de CRUD atualizam o banco;
- eventos em tempo real podem atualizar a lista automaticamente.

---

## 4.4 Detalhe da Viagem (`trip_detail_screen.dart`)

Para que serve:

- centralizar tudo que pertence a uma viagem especifica.

O que voce encontra:

- dados da viagem;
- cidades cadastradas;
- atalhos para Eventos da Viagem (timeline) e Wishlist;
- busca por locais via Places (quando aplicavel ao fluxo).

Fluxo de dados:

- app consulta cidades e dados da viagem;
- criar/editar/excluir cidade atualiza banco;
- tela pode reagir a atualizacoes em tempo real.

---

## 4.5 Detalhe da Cidade (`city_detail_screen.dart`)

Para que serve:

- cadastrar e organizar pontos por cidade.

O que voce encontra:

- secoes de hoteis, restaurantes e passeios;
- formularios para criar/editar/excluir cada item.

Fluxo de dados:

- app envia CRUD das entidades da cidade;
- backend persiste vinculado a viagem/cidade correta;
- retorno atualiza listas da tela.

---

## 4.6 Eventos da Viagem / Timeline (`timeline_screen.dart`)

Para que serve:

- planejar a agenda por dia com blocos de tempo.

Tipos de bloco:

- Evento Fixo: compromisso definido (ex.: museu 10:00-12:00).
- Tempo Livre: janela para sugestoes e planejamento flexivel.

O que voce encontra:

- lista por dia;
- filtros por dia;
- criar, editar e remover bloco;
- geracao de tempo livre por dia;
- segmento de rota entre eventos (quando aplicavel).

Regras importantes:

- data do evento deve estar dentro do periodo da viagem;
- rota entre eventos aparece apenas com dois eventos fixos e ambos com endereco;
- se houver tempo livre no trecho, o segmento de mobilidade nao e mostrado.

Fluxo de dados:

- CRUD de blocos grava em `roteiro_blocos`;
- ao tocar no icone de rota, o app calcula distancia/tempo sob demanda;
- atualizacoes tambem podem chegar por WebSocket.

---

## 4.7 Formulario de Evento (`timeline_block_form_screen.dart`)

Para que serve:

- criar ou editar um bloco da timeline em tela dedicada.

O que voce encontra:

- tipo do bloco (fixo/livre);
- data e horario;
- titulo/descritivo;
- endereco (quando evento fixo);
- link relacionado (quando usado no fluxo).

Fluxo de dados:

- validacoes locais antes de enviar;
- backend valida e salva;
- timeline recarrega com o novo estado.

---

## 4.8 Wishlist (`wishlist_screen.dart`)

Para que serve:

- guardar ideias e locais de interesse da viagem.

O que voce encontra:

- aba Lista e aba Mapa;
- filtros por categoria e status;
- criar item manual;
- importacao de local por Places;
- abrir link do item (quando preenchido).

Fluxo de dados:

- itens sao gravados em `wishlist_itens`;
- lista e mapa usam as mesmas coordenadas/dados;
- mudancas de status impactam o motor de sugestoes.

---

## 4.9 Formulario da Wishlist (`wishlist_item_form_screen.dart`)

Para que serve:

- cadastrar ou editar item da wishlist em tela padrao.

O que voce encontra:

- nome, categoria, endereco;
- status e observacoes;
- link do local.

Fluxo de dados:

- app envia payload para criar/atualizar item;
- backend persiste e devolve item atualizado;
- tela principal da wishlist recarrega.

---

## 4.10 Sugestoes para bloco livre (`suggestions_bloco_screen.dart`)

Para que serve:

- recomendar o que fazer em um bloco de tempo livre.

O que voce encontra:

- lista de sugestoes vindas da wishlist;
- filtros por categoria e status;
- ordenacao (incluindo "mais proximo de mim");
- acoes de aceitar/rejeitar;
- acesso a preferencias da viagem.

Ao aceitar uma sugestao:

- bloco pode virar evento fixo na timeline;
- item da wishlist e atualizado de status;
- link pode ser copiado automaticamente para o evento.

Fluxo de dados:

- app consulta sugestoes por bloco;
- backend calcula ranking por regras;
- aceite/rejeicao atualiza timeline + wishlist.

---

## 4.11 Preferencias de Mobilidade (`mobility_preferences_screen.dart`)

Para que serve:

- ajustar preferencia de deslocamento usada no contexto de sugestoes/mobilidade.

Fluxo de dados:

- app salva preferencia por viagem;
- backend grava em preferencias da viagem;
- sugestoes futuras podem considerar essa preferencia.

---

## 4.12 Resultado de busca de locais (`places_search_results_screen.dart`)

Para que serve:

- escolher um local retornado pela busca Places.

O que voce encontra:

- lista de resultados com dados de localizacao;
- acao para importar para wishlist/entidade conforme fluxo de origem.

Fluxo de dados:

- app solicita busca ao backend;
- backend consulta Google Places (chave protegida no servidor);
- app exibe resultados para selecao.

---

## 5) Fluxos de dados detalhados (negocio)

## 5.1 Fluxo "Criar viagem"

1. Usuario cria viagem na Home.
2. Backend salva em `viagens`.
3. Home atualiza lista local.
4. Evento em tempo real pode atualizar outras sessoes abertas.

## 5.2 Fluxo "Adicionar evento na timeline"

1. Usuario preenche formulario de evento.
2. App valida periodo da viagem.
3. Backend grava em `roteiro_blocos`.
4. Timeline agrupa/mostra por dia.

## 5.3 Fluxo "Calcular rota entre eventos"

1. Segmento so aparece quando ha dois eventos fixos com endereco.
2. Usuario toca no icone de rota.
3. App dispara calculo sob demanda.
4. Resultado de tempo/distancia e exibido no segmento.

## 5.4 Fluxo "Wishlist -> Sugestao -> Timeline"

1. Usuario cria/importa item na wishlist.
2. Bloco de tempo livre consulta sugestoes.
3. Usuario aceita sugestao.
4. Backend atualiza status do item e transforma/insere evento na timeline.
5. Timeline e wishlist refletem o novo estado.

## 5.5 Fluxo de tempo real (WebSocket)

1. App conecta apos login.
2. Backend emite eventos de alteracao (CRUD).
3. Telas inscritas reagem com refresh e/ou aviso visual.

Observacao:

- no estado atual, o broadcast e global (sem salas por viagem).

---

## 6) Dicas de uso para o usuario final

- Comece cadastrando cidades antes de montar os eventos.
- Use "Tempo Livre" para abrir espaco de recomendacoes.
- Mantenha endereco preenchido em eventos fixos para habilitar rota.
- Use categorias/status na wishlist para melhorar sugestoes.
- Salve links nos itens/eventos para acesso rapido durante a viagem.

---

## 7) Limites conhecidos (estado atual)

- Nao ha colaboracao completa por convites e papeis ainda.
- Offline robusto com sincronizacao ainda nao esta implementado.
- Realtime ainda nao usa autenticacao no handshake e sala por viagem.

---

## 8) Glossario rapido

- Viagem: plano principal do usuario.
- Cidade: agrupador interno da viagem.
- Evento Fixo: compromisso com horario definido.
- Tempo Livre: janela para decidir depois.
- Wishlist: banco de ideias/lugares.
- Sugestao: recomendacao para ocupar um bloco livre.

