---
description: Especifica uma feature e gera a spec legível (.spec/features/<feature>/) com histórias, critérios, suposições e perguntas.
---

# Specs — Especifica uma feature

Carregue a skill `specs` e execute a **Fase 1 (Especificação)**.

$ARGUMENTS

Passos:
1. Nomeie a feature (peça se não foi dada): `specs new "nome da feature"`.
2. Escreva `spec.md` LEGÍVEL: histórias de usuário `U-###` (ator/ação/motivo;
   detalhe técnico entre parênteses) e referências aos critérios `AC-###`.
3. Registre em `criteria.reg`: `AC-id`, `U-id`, descrição, dono `T-###`.
4. Escreva `assumptions.reg` com TODAS as suposições `A-###` (status `aberto`) e
   perguntas `Q-###` (status `aberto`) que você TIVER que assumir.
5. **Confesse na conversa** as suposições e perguntas em aberto; peça ao usuário
   o que ele precisa confirmar antes de planejar.
6. Mostre o caminho da spec e pergunte se está certa.

Nunca silencie suposição — o gate falha com A-/Q- em aberto.