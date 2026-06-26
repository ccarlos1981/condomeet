import type { SupabaseClient } from '@supabase/supabase-js'

/**
 * Traduz erros técnicos do Supabase/rede para mensagens amigáveis em português.
 * Também loga o erro técnico original no console para debugging.
 */
export function translateEstoqueError(err: unknown): string {
  const raw =
    err instanceof Error
      ? err.message
      : typeof err === 'object' && err !== null && 'message' in err
        ? String((err as { message: unknown }).message)
        : String(err)

  // Loga o erro técnico no console para o desenvolvedor
  console.error('[Estoque] Erro técnico:', raw, err)

  // --- Sessão / Autenticação ---
  if (
    raw.includes('JWT') ||
    raw.includes('401') ||
    raw.includes('not authenticated') ||
    raw.includes('session_not_found') ||
    raw.includes('invalid claim') ||
    raw.includes('token is expired')
  ) {
    return '⏱️ Sua sessão expirou. Recarregue a página e faça login novamente antes de salvar.'
  }

  // --- RLS / Permissão ---
  if (
    raw.includes('row-level security') ||
    raw.includes('violates row') ||
    raw.includes('permission denied') ||
    raw.includes('403')
  ) {
    return '🔒 Você não tem permissão para realizar esta ação. Contate o síndico.'
  }

  // --- Chave duplicada / conflito ---
  if (raw.includes('duplicate key') || raw.includes('unique constraint') || raw.includes('23505')) {
    return '⚠️ Já existe um registro com estas informações. Verifique os dados e tente novamente.'
  }

  // --- Chave estrangeira / referência inválida ---
  if (raw.includes('foreign key') || raw.includes('23503')) {
    return '⚠️ O espaço físico, categoria ou fornecedor selecionado não é mais válido. Recarregue a página.'
  }

  // --- NOT NULL / campo obrigatório ---
  if (raw.includes('null value') || raw.includes('23502') || raw.includes('violates not-null')) {
    return '⚠️ Um campo obrigatório não foi preenchido. Verifique todos os campos e tente novamente.'
  }

  // --- CHECK constraint (tipo_controle inválido etc) ---
  if (raw.includes('check constraint') || raw.includes('23514')) {
    return '⚠️ Um valor inválido foi enviado. Verifique os campos selecionados e tente novamente.'
  }

  // --- Rede / timeout ---
  if (
    raw.includes('Failed to fetch') ||
    raw.includes('NetworkError') ||
    raw.includes('timeout') ||
    raw.includes('net::ERR')
  ) {
    return '📡 Erro de conexão. Verifique sua internet e tente novamente.'
  }

  // --- Erro genérico com mensagem técnica → esconde do usuário ---
  return 'Erro ao salvar. Tente novamente. Se o problema persistir, recarregue a página.'
}

/**
 * Verifica se a sessão do Supabase ainda é válida antes de uma operação de escrita.
 * Retorna null se estiver ok, ou uma string de erro para exibir ao usuário.
 *
 * Uso:
 *   const sessionError = await checkEstoqueSession(supabase)
 *   if (sessionError) { setError(sessionError); return }
 */

export async function checkEstoqueSession(supabase: SupabaseClient): Promise<string | null> {
  try {
    const { data: { session }, error } = await supabase.auth.getSession()
    if (error || !session) {
      return '⏱️ Sua sessão expirou. Recarregue a página e faça login novamente antes de salvar.'
    }
    // Verifica se o token expira em menos de 60 segundos
    const expiresAt = session.expires_at ?? 0
    const nowInSeconds = Math.floor(Date.now() / 1000)
    if (expiresAt - nowInSeconds < 60) {
      // Tenta renovar automaticamente
      const { error: refreshError } = await supabase.auth.refreshSession()
      if (refreshError) {
        return '⏱️ Sua sessão expirou. Recarregue a página e faça login novamente antes de salvar.'
      }
    }
    return null
  } catch {
    return null // Se não conseguiu checar, deixa prosseguir (erro será tratado depois)
  }
}
