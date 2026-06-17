# Regras de negócio – níveis e geografia

## Hierarquia (do maior para o menor)

- **Maanaim** engloba várias **regiões**
- **Região** engloba várias **áreas**
- **Área** engloba vários **polos**

## Pertencimento por nível (pessoa / worshipLevel)

| Nível   | Obrigatório na pessoa        | Não obrigatório            |
|---------|-----------------------------|-----------------------------|
| Maanaim | Região, Área e Polo         | -                           |
| Região  | Região, Área e Polo         | Não precisa ser Maanaim     |
| Área    | Área e Polo                 | Não precisa ser Região      |
| Polo    | Polo                        | Não precisa ser Área        |

## Quem entra em qual ensaio (chamada)

- **Ensaio Maanaim** (de uma região): pessoas com nível **Maanaim** da **mesma região**.
- **Ensaio Região**: pessoas **Região** ou **Maanaim** da mesma região.
- **Ensaio Área**: pessoas **Área**, **Região** ou **Maanaim** da mesma área.
- **Ensaio Polo**: pessoas **Polo**, **Área**, **Região** ou **Maanaim** do mesmo polo.
