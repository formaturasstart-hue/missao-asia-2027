# Missão Ásia & Emirados 2027 · Grupo Vision

Roteiro interativo da viagem de negócios de 11/04 a 02/05/2027: Hong Kong, Canton Fair em Guangzhou, Xangai, Tóquio e Dubai.

**Link oficial:** https://formaturasstart-hue.github.io/missao-asia-2027/

## Como funciona

| Parte | Onde fica |
|---|---|
| Página (roteiro, mapa, abas, diário) | `index.html`, publicada pelo GitHub Pages |
| Login, checklists, anotações, ideias, fornecedores, gastos, planos | Supabase, projeto **fila-estudios-start**, área separada `viagem` |
| Fotos e áudios | Supabase Storage, bucket privado `viagem-midias` (1 GB no plano grátis) |
| Envio de fotos e áudios | Edge Function `viagem-arquivos` (código em `supabase/funcao-viagem-arquivos`) |
| Câmbio, tempo e alertas | Tabela `viagem.live`, atualizada todo dia às 5h53 por uma tarefa agendada do Claude |
| Cópia sem nuvem | Artefato do Claude, salva só no celular de quem usa |

- Cada viajante entra com usuário e senha. Quem é administrador cria os acessos na aba **Equipe**.
- Sem internet, tudo fica guardado no celular e sobe sozinho quando a conexão volta.
- Nada da viagem encosta nas tabelas do sistema da fila: tudo está no schema `viagem`, nas funções `viagem_*`, no bucket `viagem-midias` e na função `viagem-arquivos`.

## Apagar tudo depois da viagem

1. No roteiro, aba **Equipe** → **Baixar cópia de tudo (JSON)**, se quiser guardar.
2. No Supabase, SQL Editor → rode `supabase/apagar-tudo.sql`.
3. No painel: Storage → `viagem-midias` → apague os arquivos e o bucket; Edge Functions → `viagem-arquivos` → Delete.

## Mudar de projeto Supabase (quando tiver um plano pago)

1. No projeto novo, SQL Editor → rode `supabase/instalar.sql`.
2. Copie os dados do projeto antigo para o novo:
   `pg_dump "<conexão do projeto antigo>" --schema=viagem --data-only > viagem-dados.sql` e depois `psql "<conexão do projeto novo>" -f viagem-dados.sql`.
   (As conexões ficam em Project Settings → Database → Connection string.)
3. Copie os arquivos do bucket `viagem-midias` para o bucket de mesmo nome no projeto novo (baixar e enviar pelo painel, ou peça ao Claude).
4. Publique a Edge Function `viagem-arquivos` no projeto novo com "Verify JWT" desligado.
5. No `index.html`, troque as duas linhas do `CLOUD` (url e chave anon do projeto novo) e publique.
6. Atualize a tarefa agendada do Claude para gravar na tabela `viagem.live` do projeto novo.
7. Depois de conferir, rode `supabase/apagar-tudo.sql` no projeto antigo.

## Planos futuros

- Cópia de segurança automática das fotos e áudios numa pasta do Google Drive.
- Relatório final da missão em PDF, com fornecedores, ideias e fotos, para apresentar ao Grupo Vision.
- Planilha de fornecedores sincronizada com o Google Planilhas.
- Instalar o roteiro como aplicativo no celular (PWA), funcionando sem internet.
- Botão "estou aqui" com o mapa da cidade e o caminho até o hotel.
- Votação das melhores ideias entre os 7 viajantes, com ranking.
- Lembrete no celular antes de cada compromisso do dia.
- Comparar preços FOB dos fornecedores do mesmo produto lado a lado.

A caixinha **Planos futuros**, na Visão geral do roteiro, guarda esta lista e o que o grupo for acrescentando.
