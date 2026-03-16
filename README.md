# 📞 Validador de Telefone de Fornecedores com IA Conversacional

> Trabalho de Conclusão de Curso (TCC) — Sistema web para validação de telefones de fornecedores utilizando IA conversacional.

---

## 📋 Sobre o Projeto

Este projeto consiste em um sistema web que permite aos usuários validar telefones de fornecedores por meio de uma IA conversacional integrada. A plataforma oferece uma interface amigável para acesso ao serviço, com controle de autenticação de usuários e gestão de planos de assinatura.

O frontend é construído com **Vue.js integrado ao Rails**, sem separação em aplicação independente.

---

## 🚀 Tecnologias Utilizadas

- **Ruby on Rails** — Framework principal (backend e renderização de views)
- **Vue.js** — Componentes interativos integrados ao Rails
- **PostgreSQL** — Banco de dados relacional
- **IA Conversacional** — Serviço externo integrado via API para validação dos telefones

---

## ✨ Funcionalidades

- [x] Autenticação e controle de acesso de usuários (login/logout/registro)
- [ ] Gerenciamento de planos de assinatura *(em desenvolvimento)*
- [ ] Integração com serviço de IA conversacional *(em desenvolvimento)*
- [ ] Validação de telefones de fornecedores via chat com IA *(em desenvolvimento)*
- [ ] Dashboard de histórico de validações *(em desenvolvimento)*
- [ ] Relatórios e exportação de dados *(planejado)*

---

## 🏗️ Arquitetura do Sistema

```
┌──────────────────────────────────┐        ┌──────────────────────┐
│         Ruby on Rails            │ ──────▶│  Serviço de IA       │
│  (Views + Vue.js + API interna)  │        │  Conversacional      │
└──────────────────┬───────────────┘        └──────────────────────┘
                   │
          ┌────────▼────────┐
          │   PostgreSQL    │
          └─────────────────┘
```

---

## ⚙️ Como Executar o Projeto

### Pré-requisitos

- Ruby >= 3.3.10
- Rails >= 8.1.2
- Node.js >= 18.19.1
- PostgreSQL >= 16.13
- Yarn ou npm

### Instalação

```bash
# Clone o repositório
git clone https://github.com/CaikLacerda/leadpulse.git
cd leadpulse
```

```bash
bundle install
npm install        # ou yarn install
cp .env.example .env   # configure as variáveis de ambiente
rails db:create db:migrate db:seed
rails server
```

---

## 📁 Estrutura do Projeto

```
.
├── app/
│   ├── controllers/
│   ├── models/
│   ├── services/
│   ├── views/
│   └── javascript/       # Componentes Vue.js
│       └── components/
├── config/
├── db/
└── README.md
```

---

## 👤 Autor

Desenvolvido como Trabalho de Conclusão de Curso.

- **Responsável pelo sistema web:** Caik Lacerda
- **Instituição:** FHO - Uniararas
- **Curso:** Sistemas de Informacao
- **Ano:** 2026

---