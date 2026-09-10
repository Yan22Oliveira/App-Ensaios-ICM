# Frequência ICM

Aplicativo mobile para **gestão de frequência** de membros de louvor da Igreja Cristã Maranata (ICM). Organiza cadastro de membros, eventos (ensaio, culto, seminário e demais atividades), chamada e relatórios, sempre no **escopo geográfico** de quem está logado.

Versão: **1.0.3+15**  
Uso interno. Distribuição externa depende de autorização da organização.

Regras de domínio (hierarquia, quem entra na chamada, fórmula de presença): [`lib/src/domain/business_rules.md`](lib/src/domain/business_rules.md).

---

## Como o app funciona hoje

1. O secretário (ou líder) **entra com e-mail e senha**. Sem perfil ativo em `users`, permanece em **acesso pendente** até um administrador aprovar a solicitação.
2. A Home mostra atalhos de **Eventos**, **Membros** e **Relatórios**. Administradores também veem **Acessos**. Há calendário, próximo evento e totais do dia/mês.
3. Em **Eventos**, cria-se uma atividade com tipo, nível (Maanaim, Região, Área ou Polo), data, local e quem entra na chamada (todos da estrutura ou lista escolhida).
4. A **chamada** lista só os membros convocados. Cada um pode ficar **Pendente**, **Presente**, **Falta** ou **Justificada**. Depois da primeira marca (ou ao finalizar), a lista congela.
5. Em **Relatórios**, o recorte (período, tipo, geo) alimenta duas visões: **por evento** e **por pessoa**. O toque no membro abre o **relatório individual** (só eventos em que aquela pessoa foi convocada). A lista principal exporta CSV e PDF.

**Membro** (`people`) e **usuário** (`users`) são entidades distintas: quem canta na chamada não precisa ter login; quem tem login não entra automaticamente na chamada.

No código o evento ainda se chama `Rehearsal`. Na interface o nome é **Evento**.

---

## Perfis de acesso

| Papel | Escopo | Home |
|--------|--------|------|
| **Administrador** | Toda a organização | + Acessos (solicitações e usuários) |
| **Maanaim** | Maanaim e regiões/áreas/polos vinculados | Eventos, Membros, Relatórios |
| **Região** | Região e níveis abaixo | Idem |
| **Área** | Área e polos | Idem |
| **Polo** | Somente o polo | Idem |
| **Somente leitura** | Consulta no escopo do perfil | Idem, sem Acessos |

O que cada secretário **pode criar de evento** e **quem entra em cada chamada** está em [`business_rules.md`](lib/src/domain/business_rules.md). Relatórios travam região/área/polo conforme o papel (Polo não troca de polo; Admin não tem trava).

---

## Requisitos funcionais

### RF01 — Autenticação e sessão

- Login com e-mail e senha (Firebase Auth).
- Recuperação de senha por e-mail.
- Logout a partir do menu da conta.
- Sem documento `users/{uid}` ativo, o app não abre a Home: mostra **acesso pendente**.

### RF02 — Solicitação e gestão de acesso

- Qualquer pessoa pode solicitar acesso (nome, e-mail, senha mínima de 6 caracteres, telefone opcional), com verificação de e-mail.
- Administrador aprova (papel + Maanaim/região/área/polo + ativa o perfil) ou rejeita (motivo opcional).
- Administrador lista e edita usuários: papel, escopo, ativo, nome e telefone.
- O próprio usuário altera apenas nome, telefone e foto no perfil.

### RF03 — Geografia

- Hierarquia Maanaim → Região → Área → Polo carregada do Firestore e usada em cadastros, eventos, filtros e relatórios.
- Nomes amigáveis na UI (não ids).

### RF04 — Membros

- Cadastrar, editar e **desativar** (soft delete) membros: nome, papéis/vozes, nível de louvor, geo, telefone e e-mail opcionais.
- Listar e buscar no escopo do usuário; Maanaim/Região/Área podem restringir à “faixa” do próprio nível ou incluir níveis abaixo.
- Pelo menos um papel/voz no cadastro; geo obrigatória conforme o nível de louvor.

### RF05 — Eventos

- Criar, listar, filtrar, editar e excluir eventos no escopo.
- Tipos: Ensaio, Culto, Vigília, Evangelização, Assistência, Seminário, Reunião, Cantata, Mutirão, Outro.
- Níveis: Maanaim, Região, Área, Polo — com restrição de criação por papel.
- Participantes: todos da estrutura **ou** seleção explícita.
- Relatório textual do evento (pauta, responsável, conclusão), distinto do relatório de frequência.

### RF06 — Chamada

- Abrir a chamada de um evento e marcar P / J / F, com ciclo de toque e justificativa quando couber.
- Indicador de quantos ainda estão pendentes.
- Marcar todos presentes.
- Finalizar a chamada (não permite novas marcas).
- Lista congelada após o início efetivo da chamada.

### RF07 — Relatórios de frequência

- Filtro por período (padrão: mês atual), tipo de evento e geo (com travas por papel).
- Visão **por evento** e **por pessoa**.
- Frequência = presentes / (P + F + J); justificada no denominador; pendente fora do percentual.
- Distinção entre **participações** e **participantes únicos**.
- Relatório individual: só eventos com registro da pessoa na chamada; histórico; faixas qualitativas (≥90% excelente, ≥75% boa, ≥60% regular, &lt;60% baixa).
- Exportar CSV e PDF da tela principal de Relatórios.

### RF08 — Home

- Atalhos dos módulos permitidos.
- Calendário com dias que têm evento.
- Acesso rápido ao próximo evento / chamada do dia.
- Contadores de eventos hoje e no mês.

---

## Requisitos não funcionais

| ID | Tema | Requisito |
|-----|------|-----------|
| **RNF01** | Plataforma | Flutter, iOS e Android. Idioma **pt-BR**. |
| **RNF02** | Backend | Firebase Authentication + Cloud Firestore. Operação **online**; persistência local (Hive) está prevista no `pubspec`, **não implementada**. |
| **RNF03** | Estado | `flutter_bloc` (Cubits). Sem camada de use case: telas → repositórios → Firestore. |
| **RNF04** | Navegação | `Navigator.push` / `MaterialPageRoute`. Sem rotas nomeadas. |
| **RNF05** | UI | `AppTheme`; cor primária / header `#00759A`. Sem `DesignSystem.of(context)`. |
| **RNF06** | Segurança | Firestore Rules + perfil `active`. Escopo de eventos nas queries. Usuário só altera o próprio nome/telefone/foto. Delete de `users` bloqueado nas rules. |
| **RNF07** | Isolamento de dados | Cada papel vê e opera só o recorte geográfico correspondente, na aplicação e (em ensaios) nas rules. |
| **RNF08** | Consistência de métricas | A mesma fórmula P/(P+F+J) em lista, detalhe, exportação e testes. Pendente nunca infla o %. |
| **RNF09** | Observabilidade de domínio | Regras de chamada e frequência cobertas por testes unitários (`flutter test`). |
| **RNF10** | Privacidade / uso | Dados de membros e presença de uso interno ICM; não há fluxo público de cadastro liberando o app sozinho (depende de admin). |
| **RNF11** | Acessibilidade | Listas e resumos de relatório com `Semantics` (nome, percentual, totais). |
| **RNF12** | Manutenibilidade | Entidade `Rehearsal` permanece no código/Firestore; vocabulário de produto é “evento”. Membro ≠ usuário. |

---

## Stack

- Flutter `^3.7.2`
- Firebase Auth + Cloud Firestore
- flutter_bloc, pdf / printing, share_plus, csv, shared_preferences

---

## Estrutura

```
lib/
├── main.dart
└── src/
    ├── core/                 # Tema e utilitários
    ├── data/                 # Repositórios Firestore
    ├── domain/               # Entidades, contratos, business_rules.md
    └── presentation/
        ├── admin/            # Hub Acessos (solicitações e usuários)
        ├── attendance/       # Chamada
        ├── auth/             # Login e solicitação de acesso
        ├── home/             # Home
        ├── people/           # Membros
        ├── profile/          # Perfil
        ├── rehearsals/       # Eventos
        └── reports/          # Relatórios de frequência
```

Rules: [`firestore.rules`](firestore.rules).

---

## Como executar

```bash
flutter pub get
flutter run
```

Pré-requisitos: Flutter SDK, projeto Firebase e `firebase_options.dart` (FlutterFire CLI).

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

```bash
flutter test
```

---

## Licença

Projeto de uso interno — Igreja Cristã Maranata (ICM).
