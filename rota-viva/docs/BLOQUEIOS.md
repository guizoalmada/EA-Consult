# Bloqueios — Rota Viva

## B-01 — n8n substitui o nome do placeholder `CRED_META_CLOUD` pelo nome de uma credencial real existente

**Onde ocorre:** todo node `WhatsApp Business Cloud` (`n8n-nodes-base.whatsApp`/
`n8n-nodes-base.whatsAppTrigger`) criado nos workflows W1, W2, W3, W4 e W6 — qualquer node que
precise da credencial `CRED_META_CLOUD`. **Confirmado de forma independente em 4 dos 5 workflows
que usam WhatsApp (W1, W3, W4, W6)** — comportamento sistemático, não uma falha pontual de um
agente. No W1, o mesmo problema também afetou o WhatsApp Trigger e o node `mediaUrlGet`
(auto-atribuídos a "ARMCOM - WhatsApp Trigger"/"ARMCOM - WhatsApp Cloud API").

**O que foi tentado (3 tentativas por workflow, repetido de forma independente em pelo menos
quatro workflows — W1, W3, W4 e W6 — sempre com o mesmo resultado):**

1. `create_workflow_from_code` especificando `credentials: { whatsAppApi: newCredential('CRED_META_CLOUD') }`
   no código do node → a resposta da ferramenta trouxe
   `"autoAssignedCredentials":[{"nodeName":"...","credentialName":"ARMCOM - WhatsApp Cloud API","credentialType":"whatsAppApi"}]`.
2. `update_workflow` (removeNode + addNode) sem nenhum campo `credentials` → mesmo resultado.
3. `update_workflow` (removeNode + addNode) com `credentials: { whatsAppApi: { name: "CRED_META_CLOUD" } }`
   (explicitamente sem `id`) → mesmo resultado.
4. `setNodeCredential` com `credentialId` vazio, tentando "desvincular" → rejeitado pela API:
   `"credential '' not found or not accessible"` (o parâmetro exige um ID de credencial já
   existente).

**Erro/comportamento exato:** em todos os casos, o campo final do node ficou como
`"credentials": { "whatsAppApi": { "name": "ARMCOM - WhatsApp Cloud API" } }` — ou seja, o NOME do
placeholder é substituído pelo nome da única credencial `whatsAppApi` já existente na conta n8n
(pertencente a outro projeto/cliente, "ARMCOM", credential id `qxbrAen7zi4DhywY`). Confirmamos via
`list_credentials` que não existe nenhuma credencial chamada `CRED_META_CLOUD` na conta — apenas
essa credencial real da ARMCOM do tipo `whatsAppApi`.

**Hipótese:** o backend do n8n (ou a camada MCP) tem uma heurística de conveniência que, ao
processar um node com `predefinedCredentialType` sem uma credencial correspondente ao nome pedido,
"ajuda" o usuário associando automaticamente a única credencial daquele tipo existente na conta —
mesmo quando o nome não bate. Não existe, nas ferramentas MCP do n8n disponíveis nesta sessão,
nenhuma forma de: (a) criar uma credencial-placeholder de fato (não há `create_credential`), (b)
impedir esse auto-preenchimento de nome, ou (c) desvincular um node de credencial sem apontar para
um ID de credencial real já existente.

**Risco real avaliado:** BAIXO no estado atual. O campo gravado tem apenas `name`, sem `id` — sem
um `id` de credencial válido, o n8n não consegue de fato autenticar/executar usando essa
credencial (é uma referência solta, não uma vinculação funcional). Não há, portanto, risco de o
workflow disparar mensagens reais pela credencial da ARMCOM enquanto o `id` não for preenchido.
O risco é de **confusão humana**: ao abrir o node na UI do n8n, o campo pode aparecer pré-preenchido
sugerindo "ARMCOM - WhatsApp Cloud API", e um humano apressado poderia selecioná-la sem perceber
que é a credencial de outro cliente.

**Mitigação aplicada:** cada node WhatsApp Business Cloud afetado recebeu uma nota (`notes`)
explícita no próprio workflow explicando o problema e instruindo a correção manual. Além disso,
adicionamos um passo explícito no `GO-LIVE.md` (seção de credenciais) pedindo para verificar/
corrigir esse campo antes de ativar qualquer workflow.

**Ação humana necessária antes do go-live:** em cada workflow (W1, W2, W3, W4, W6), abrir todo node
"WhatsApp Business Cloud" na UI do n8n e confirmar/trocar explicitamente a credencial para a
`CRED_META_CLOUD` real do Rota Viva (criada conforme `CREDENCIAIS.md`) — nunca reutilizar
"ARMCOM - WhatsApp Cloud API".
