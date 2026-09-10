# Regras de negócio — Frequência ICM

Documento de domínio. Descreve o comportamento atual do app (código + Firestore), não um roadmap.

No código, o evento continua na entidade `Rehearsal` e na coleção `rehearsals`. Na interface o usuário vê **Evento**.

---

## 1. Conceitos que não se misturam

| Conceito | Coleção | O que é |
|----------|---------|---------|
| **Usuário** | `users` | Conta que entra no app (Firebase Auth + perfil) |
| **Membro** (`Person`) | `people` | Pessoa que aparece na chamada |
| **Evento** | `rehearsals` | Ensaio, culto, seminário etc. |
| **Chamada** | `attendance` | Marca P / F / J / Pendente de um membro em um evento |
| **Relatório de frequência** | calculado no app | Agregados por período (não é um documento persistido) |
| **Relatório do evento** | `eventReports` | Texto (pauta, conclusão) vinculado a um evento |

Membro e usuário **não** são a mesma entidade. Ter cadastro em `people` não dá login; ter login não coloca a pessoa na chamada.

---

## 2. Hierarquia geográfica

Do maior para o menor:

**Maanaim** ⊃ **Região** ⊃ **Área** ⊃ **Polo**

Coleções: `maanains`, `regions`, `areas`, `polos`. Regiões de um Maanaim também existem em `maanains/{id}/regions`.

### Escopo no perfil do usuário

O campo `regionId` do **usuário** significa coisas diferentes conforme o papel:

- **Maanaim:** `regionId` é o **id do Maanaim** (não uma região geográfica).
- **Região / Área / Polo:** `regionId` é a região geográfica; Área e Polo preenchem também `areaId` / `poloId`.
- **Admin / somente leitura:** podem operar sem lock geográfico (admin vê tudo; readonly lista conforme o que estiver no perfil).

Ensaio de nível Maanaim usa o mesmo critério: `Rehearsal.regionId` = id do Maanaim.

---

## 3. Nível de louvor do membro (`worshipLevel`)

O nível da **pessoa** (`RehearsalLevel`: `maanaim | region | area | polo`) define em quais eventos ela entra. Não é o papel de login.

### Geografia obrigatória no cadastro

| Nível da pessoa | Obrigatório | Não precisa |
|-----------------|----------------|-------------|
| Maanaim | Região, Área e Polo | — |
| Região | Região, Área e Polo | Não precisa ser Maanaim |
| Área | Área e Polo | Não precisa ser Região (como nível de louvor) |
| Polo | Polo | Não precisa ser Área (como nível de louvor) |

Na prática o formulário também pede a cadeia geográfica necessária para localizar o membro.

O secretário que cadastra **não pode** atribuir `worshipLevel` acima do próprio papel (polo só cadastra Polo; área até Área; …; admin até Maanaim).

Membro inativo (`active: false`) sai das listas filtradas. Não há exclusão definitiva na interface.

---

## 4. Quem entra na chamada

Função: `personBelongsToEventStructure` (`event_structure_membership.dart`).

| Nível do evento | Entram membros com `worshipLevel` | Filtro geográfico |
|-----------------|--------------------------------------|-------------------|
| **Maanaim** | somente **Maanaim** | mesma `regionId` (id do Maanaim). Se `regionId` vazio, todos os Maanaim |
| **Região** | **Região** ou **Maanaim** | mesma região |
| **Área** | **Área**, **Região** ou **Maanaim** | mesma área |
| **Polo** | **Polo**, **Área**, **Região** ou **Maanaim** | mesmo polo |

Nível **maior** sobe na estrutura: quem é Maanaim entra em evento de Polo do seu polo; quem é só Polo **não** entra em evento de Área/Região/Maanaim.

### Modo de participantes

- **Todos os membros** (`all`): lista resolvida pela regra acima.
- **Selecionar participantes** (`selected`): só os ids em `expectedParticipants`.

### Congelamento da lista (`participantsSnapshot`)

Depois da primeira marca P/F/J (ou ao finalizar a chamada), a lista de participantes é **congelada** no evento. Inclusões posteriores no cadastro de membros **não** entram naquela chamada já iniciada.

---

## 5. Tipos e níveis de evento

**Nível** (`RehearsalLevel`) = escopo geográfico.  
**Tipo** (`EventType`) = natureza da atividade, independente do nível:

Ensaio, Culto, Vigília, Evangelização, Assistência, Seminário, Reunião, Cantata, Mutirão, Outro.

Registro antigo sem `eventType` é tratado como **Ensaio**. Valor desconhecido vira **Outro**.

Campos típicos: data/hora, local, título opcional (senão usa o rótulo do tipo), descrição, nível, geo, modo de participantes, `closed` / `closedAt`.

### Quem pode criar evento de qual nível (secretários)

| Papel do usuário | Níveis que cria |
|-----------------|-----------------|
| Admin | Maanaim, Região, Área, Polo |
| Maanaim | somente Maanaim |
| Região | Região, Área, Polo |
| Área | Área, Polo |
| Polo | somente Polo |

A listagem de eventos também respeita o escopo (Maanaim vê o próprio Maanaim e região/área/polo das regiões vinculadas; Polo só o próprio polo).

---

## 6. Chamada (presença)

### Status

| Valor | Na chamada | Nos relatórios |
|-------|------------|----------------|
| `unmarked` | ainda não marcado (“Falta marcar”) | **Pendente** |
| `present` | P | Presença |
| `unjustifiedAbsence` | F | Falta |
| `justifiedAbsence` | J (pode ter texto) | Justificada |

Ciclo de toque: sem marca → P → J → F → sem marca.

Chamada **finalizada** (`closed`) não aceita novas marcas na interface.

### Cálculo de frequência (regra única do produto)

```
frequência = presentes / (presentes + faltas + justificadas)
```

- Justificada **entra no denominador**.
- **Pendente** (`unmarked`) **não entra** nem no numerador nem no denominador.
- Sem nenhuma participação P/F/J, a taxa é **0%** (não é NaN).

Participações ≠ participantes únicos:

- **Participações** = soma de P+F+J em todos os eventos do recorte.
- **Participantes únicos** = pessoas distintas com pelo menos uma marca P/F/J no recorte.

---

## 7. Relatórios de frequência

### Recorte

- Período (padrão: mês corrente).
- Tipo de evento (opcional).
- Região / Área / Polo, **travados** conforme o papel:
  - Polo: região + área + polo
  - Área: região + área
  - Região: região
  - Maanaim: escolhe região dentre as do próprio Maanaim
  - Admin: sem trava
- **Somente com registros** (aba por pessoa, ligado por padrão): só quem tem P/F/J no período.

### Por evento / por pessoa

Aba **Por evento**: totais do evento (P, F, J, %) e lista.  
Aba **Por pessoa**: um card por membro convocado no recorte, com % e totais.

Exportação **CSV** e **PDF** existe na tela principal de Relatórios (não no relatório individual). O CSV atual é agregado por evento (`P|F|J`), não linha a linha por pessoa.

### Relatório individual (toque no membro)

- Entram **somente** eventos em que o membro **tem registro** na chamada (foi convocado). Evento da estrutura em que a pessoa não estava na lista **não** conta.
- Pendente aparece no histórico e **não** entra no %.
- Sem PDF/CSV nesta tela.

### Faixas de leitura

**Insights** (card qualitativo, só se houver eventos previstos):

| Faixa | Texto |
|-------|--------|
| ≥ 90% | Frequência excelente |
| ≥ 75% | Boa frequência |
| ≥ 60% | Frequência regular |
| &lt; 60% | Frequência baixa |

**Cores da lista** (percentual):

| Faixa | Nível |
|-------|--------|
| ≥ 80% | Alta (verde) |
| ≥ 60% | Média (âmbar) |
| &lt; 60% | Baixa (vermelho) |

---

## 8. Autenticação e papéis de login

Papéis (`UserRole`): `admin | maanaim | region | area | polo | readonly`.

Só entra na Home quem está autenticado **e** tem documento em `users` com `active: true`. Sem perfil ativo, o fluxo é **acesso pendente**.

### Solicitação de acesso

1. Cadastro (nome, e-mail, senha ≥ 6, telefone opcional) cria conta Firebase e `accessRequests/{uid}` com `status: pending`.
2. E-mail de verificação; sessão é encerrada até aprovação.
3. **Admin** aprova (define papel + escopo, cria/atualiza `users/{uid}` com `active: true`) ou rejeita (motivo opcional).
4. Status: `pending | approved | rejected`.

### Hub Acessos (somente admin)

- **Solicitações:** fila de aprovação.
- **Usuários:** listar e editar papel, escopo, ativo, nome e telefone. Admin que se desativa ou tira o próprio papel admin é avisado.

O próprio usuário só altera nome, telefone, foto e `updatedAt` no perfil.

### Módulos na Home

Todos os usuários ativos: **Eventos**, **Membros**, **Relatórios**.  
Somente **admin**: **Acessos** (com badge de pendências).

Também: calendário dos próximos dias, atalho para o próximo evento/chamada, totais do dia e do mês.

---

## 9. Segurança (Firestore)

- Quase todas as coleções de operação exigem usuário **autenticado e ativo**.
- `users`: o próprio lê o seu documento; listar/criar/editar papel é admin; delete de usuário **não** é permitido pelas rules.
- `accessRequests`: **qualquer um** pode criar (wizard); ler/alterar só admin ativo.
- `rehearsals`: get/alterar/excluir segundo `canSeeRehearsal` (papel + geo). Listagem de Maanaim é mais frouxa nas rules de `list` (o cliente ainda filtra as regiões do Maanaim).
- `people` e `attendance`: leitura/gravação para qualquer usuário **ativo** (o recorte fino é na aplicação).
- Geografia (`regions`, `areas`, `polos`) e `roles`: leitura para ativo (Maanaim também para autenticado, para o wizard).

---

## 10. Relatório textual do evento

Documento em `eventReports` ligado a um `eventId`. Campos: título, responsável, panorama, conclusão, notas, status rascunho/finalizado. **Não** substitui o relatório de frequência e **não** duplica data/local/tipo — esses vêm do evento.
