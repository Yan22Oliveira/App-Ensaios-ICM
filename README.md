# Ensaios ICM

Aplicativo mobile para **gestão de presença em ensaios de louvor**, desenvolvido para grupos organizados em estrutura geográfica hierárquica (Maanaim → Região → Área → Polo). O sistema centraliza o cadastro de membros, o agendamento de ensaios, o registro de chamada e a geração de relatórios consolidados.

---

## Visão geral

O **Ensaios ICM** foi criado para secretários e líderes que precisam acompanhar a frequência dos participantes com agilidade e confiabilidade. A aplicação respeita o escopo de cada usuário logado, garantindo que cada perfil visualize e gerencie apenas os dados pertinentes ao seu nível de atuação.

### Principais funcionalidades

| Módulo | Descrição |
|--------|-----------|
| **Membros** | Cadastro, edição e desativação de participantes, com vozes/funções, nível de louvor e vínculo geográfico |
| **Ensaios** | Criação e listagem de ensaios por nível (Polo, Área, Região ou Maanaim), com calendário e filtros |
| **Chamada** | Registro de presença, falta e falta justificada por ensaio |
| **Relatórios** | Indicadores de frequência por período, com exportação em **CSV** e **PDF** |
| **Solicitações de acesso** | Fluxo de aprovação de novos usuários (administradores) |
| **Perfil** | Dados do usuário logado, escopo e configurações da conta |

---

## Perfis de acesso

O app opera com perfis hierárquicos, cada um com escopo definido:

| Perfil | Escopo típico |
|--------|----------------|
| **Admin** | Acesso amplo à gestão e aprovação de solicitações |
| **Maanaim** | Visão sobre as regiões vinculadas ao Maanaim |
| **Região** | Gestão dentro da região e níveis abaixo |
| **Área** | Gestão dentro da área e polos associados |
| **Polo** | Gestão restrita ao polo |
| **Somente leitura** | Consulta sem alterações |

As regras de quem participa de cada ensaio seguem o nível de louvor do membro e a hierarquia geográfica. Detalhes em [`lib/src/domain/business_rules.md`](lib/src/domain/business_rules.md).

---

## Stack tecnológica

- **Flutter** — interface multiplataforma (iOS e Android)
- **Firebase Authentication** — autenticação de usuários
- **Cloud Firestore** — persistência em tempo real
- **flutter_bloc** — gerenciamento de estado
- **pdf / printing** — geração e compartilhamento de relatórios em PDF

---

## Estrutura do projeto

```
lib/
├── main.dart                 # Bootstrap e injeção de dependências
└── src/
    ├── core/                 # Tema e utilitários
    ├── data/                 # Repositórios Firestore
    ├── domain/               # Entidades, contratos e regras de negócio
    └── presentation/         # Telas, controllers e widgets
        ├── admin/            # Solicitações de acesso
        ├── attendance/       # Chamada de presença
        ├── auth/             # Login e solicitação de acesso
        ├── home/             # Dashboard principal
        ├── people/           # Módulo de membros
        ├── profile/          # Perfil do usuário
        ├── rehearsals/       # Ensaios
        └── reports/          # Relatórios e exportações
```

---

## Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `^3.7.2`
- Conta e projeto configurados no **Firebase**
- Arquivo `firebase_options.dart` gerado via FlutterFire CLI

---

## Como executar

```bash
# Instalar dependências
flutter pub get

# Executar em modo debug
flutter run
```

### Build de release

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

---

## Testes

```bash
flutter test
```

---

## Versão

Versão atual: **1.0.1+4**

---

## Licença

Projeto de uso interno — Igreja Cristã Maranata (ICM).  
Distribuição e uso externo sujeitos à autorização da organização responsável.
