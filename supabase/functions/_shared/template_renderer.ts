/**
 * template_renderer.ts — Módulo centralizado de renderização de templates Meta
 * 
 * Responsabilidades:
 *   - Interpretação da estrutura definition_payload (components, body, header, footer, buttons)
 *   - Substituição de placeholders {{1}}, {{2}}, ... por parâmetros do contrato
 *   - Validação estrutural do payload de definição
 *   - Renderização de texto final a partir do contrato estruturado FASE 2
 * 
 * Consumidores:
 *   - whatsapp-outbox-worker (BotConversa text transport)
 *   - Futuros consumidores que necessitem de texto renderizado a partir de templates Meta
 * 
 * Contrato:
 *   Nenhum consumidor deste módulo deverá conhecer a estrutura interna de definition_payload.
 *   Toda interação com definition_payload deve passar por funções exportadas deste módulo.
 */

// ── Types ────────────────────────────────────────────────────────────────────

/** Estrutura de um componente do template Meta conforme armazenado em definition_payload */
export interface TemplateComponent {
  type: string       // "body" | "BODY" | "header" | "HEADER" | "footer" | "FOOTER" | "BUTTONS"
  text?: string      // Texto do componente com placeholders {{1}}, {{2}}, ...
  example?: any      // Exemplos fornecidos para aprovação na Meta
  buttons?: any[]    // Botões (para componentes do tipo BUTTONS)
}

/** Payload de definição completo do template conforme armazenado em whatsapp_meta_templates */
export interface TemplateDefinitionPayload {
  template_name?: string
  category?: string
  language?: string
  components?: TemplateComponent[]
}

/** Resultado da renderização */
export interface RenderResult {
  success: boolean
  text: string | null
  error?: string
}

// ── Core Rendering ───────────────────────────────────────────────────────────

/**
 * Substitui placeholders {{1}}, {{2}}, ... em um texto-modelo com os parâmetros fornecidos.
 * 
 * @param templateText - Texto com placeholders no formato {{N}} (1-indexed)
 * @param parameters   - Array de parâmetros a substituir (posição 0 → {{1}}, posição 1 → {{2}}, ...)
 * @returns Texto com placeholders substituídos
 */
export function substitutePlaceholders(templateText: string, parameters: string[]): string {
  let rendered = templateText
  for (let i = 0; i < parameters.length; i++) {
    rendered = rendered.replace(`{{${i + 1}}}`, String(parameters[i] ?? ""))
  }
  return rendered
}

/**
 * Extrai o texto do componente BODY de um definition_payload.
 * 
 * @param definitionPayload - Payload de definição do template (de whatsapp_meta_templates)
 * @returns Texto do body com placeholders, ou null se não encontrado
 */
export function extractBodyText(definitionPayload: TemplateDefinitionPayload | any): string | null {
  if (!definitionPayload?.components || !Array.isArray(definitionPayload.components)) {
    return null
  }

  const bodyComponent = definitionPayload.components.find(
    (c: TemplateComponent) => c.type === "body" || c.type === "BODY"
  )

  return bodyComponent?.text ?? null
}

/**
 * Renderiza o texto final de um template Meta a partir do definition_payload e parâmetros do contrato.
 * 
 * Esta é a função principal de consumo. Consumidores (ex: worker) não precisam conhecer
 * a estrutura interna de definition_payload — apenas passam o payload e os parâmetros.
 * 
 * @param definitionPayload - Payload de definição do template (de whatsapp_meta_templates.definition_payload)
 * @param parameters        - Array de parâmetros do contrato estruturado (de message_content.template.parameters)
 * @returns RenderResult com texto renderizado ou erro descritivo
 * 
 * @example
 * ```typescript
 * const result = renderTemplateText(templateRow.definition_payload, ["123456"])
 * // result.text → "Seu código de verificação é 123456. Expira em 5 minutos."
 * ```
 */
export function renderTemplateText(
  definitionPayload: TemplateDefinitionPayload | any,
  parameters: string[]
): RenderResult {
  // 1. Validar payload
  if (!definitionPayload) {
    return { success: false, text: null, error: "definition_payload ausente ou nulo" }
  }

  // 2. Extrair body text
  const bodyText = extractBodyText(definitionPayload)
  if (!bodyText) {
    return { success: false, text: null, error: "Componente BODY não encontrado no definition_payload" }
  }

  // 3. Validar parâmetros
  if (!Array.isArray(parameters) || parameters.length === 0) {
    return { success: false, text: null, error: "Array de parâmetros vazio ou inválido" }
  }

  // 4. Renderizar
  const rendered = substitutePlaceholders(bodyText, parameters)

  return { success: true, text: rendered }
}
