// _shared/auth.ts — Shared authorization utilities
// Verifies caller identity and role-based access using features_config

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2"

// ── Types ─────────────────────────────────────────────────────────────────

export interface CallerProfile {
  id: string
  user_id: string
  nome_completo: string
  papel_sistema: string
  condominio_id: string
}

export type AuthResult =
  | { authorized: true; profile: CallerProfile }
  | { authorized: false; status: number; error: string }

// ── Role normalization ────────────────────────────────────────────────────
// Must match the Flutter _normalizeRole() in configure_menu_screen.dart

const ROLE_ALIASES: Record<string, string> = {
  porteiro: "portaria",
  "porteiro (a)": "portaria",
  sindico: "sindico",
  síndico: "sindico",
  "síndico (a)": "sindico",
  sub_sindico: "sub_sindico",
  "sub síndico": "sub_sindico",
  "sub_síndico": "sub_sindico",
  admin: "admin",
  zelador: "zelador",
  funcionario: "funcionario",
  funcionário: "funcionario",
  morador: "morador",
  "morador (a)": "morador",
  proprietario: "proprietario",
  proprietário: "proprietario",
  proprietário_não_morador: "proprietario_nao_morador",
  proprietario_nao_morador: "proprietario_nao_morador",
  inquilino: "inquilino",
  locatario: "locatario",
  locatário: "locatario",
  locador: "locador",
  afiliado: "afiliado",
  terceirizado: "terceirizado",
  financeiro: "financeiro",
  servicos: "servicos",
  serviços: "servicos",
}

export function normalizeRole(raw: string): string {
  const key = raw
    .toLowerCase()
    .replace(/\s*\(.*?\)/g, "") // remove (a)/(o)
    .replace(/[^a-záàéíóúãõâêôç_]/g, "_")
    .trim()
  return ROLE_ALIASES[key] ?? key
}

// ── Secret key detection ──────────────────────────────────────────────────
// Supabase sb_secret_ keys are NOT JWTs, so we check against known prefixes

function isSecretKey(token: string): boolean {
  return token.startsWith("sb_secret_")
}

// ── Get caller profile from JWT ───────────────────────────────────────────

export async function getCallerProfile(
  supabase: SupabaseClient,
  req: Request
): Promise<CallerProfile | null> {
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) return null

  const token = authHeader.replace("Bearer ", "")

  // Verify JWT and get user
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser(token)

  if (userError || !user) {
    console.error("Auth error:", userError?.message)
    return null
  }

  // Fetch profile
  const { data: profile, error: profileError } = await supabase
    .from("perfil")
    .select("id, user_id, nome_completo, papel_sistema, condominio_id")
    .eq("user_id", user.id)
    .single()

  if (profileError || !profile) {
    console.error("Profile not found for user:", user.id)
    return null
  }

  return profile as CallerProfile
}

// ── Check function access via features_config ─────────────────────────────

export async function checkFunctionAccess(
  supabase: SupabaseClient,
  condominioId: string,
  papelSistema: string,
  functionId: string
): Promise<boolean> {
  // Fetch features_config from condominios
  const { data: condo, error } = await supabase
    .from("condominios")
    .select("features_config")
    .eq("id", condominioId)
    .single()

  if (error || !condo) {
    console.error("Condo not found:", condominioId, error?.message)
    return false
  }

  const config = condo.features_config
  if (!config) {
    const normalizedRole = normalizeRole(papelSistema)
    return ["sindico", "admin", "sub_sindico"].includes(normalizedRole)
  }

  const parsed =
    typeof config === "string" ? JSON.parse(config) : config

  const functions = parsed.functions as Array<{
    id: string
    roles: Record<string, { visible: boolean }>
  }> | undefined

  if (!functions) {
    const normalizedRole = normalizeRole(papelSistema)
    return ["sindico", "admin", "sub_sindico"].includes(normalizedRole)
  }

  const fnConfig = functions.find((f) => f.id === functionId)
  if (!fnConfig) {
    const normalizedRole = normalizeRole(papelSistema)
    return ["sindico", "admin", "sub_sindico"].includes(normalizedRole)
  }

  const normalizedRole = normalizeRole(papelSistema)
  const roleConfig = fnConfig.roles[normalizedRole]
  return roleConfig?.visible === true
}

// ── Full authorization check (convenience) ────────────────────────────────

export async function authorizeRequest(
  supabase: SupabaseClient,
  req: Request,
  condominioId: string,
  functionId: string
): Promise<AuthResult> {
  // 0. Service role / secret key bypass — for DB triggers via pg_net
  const authHeader = req.headers.get("Authorization")
  if (authHeader) {
    const token = authHeader.replace("Bearer ", "")
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")

    // Match against service_role JWT or sb_secret_ key
    if (
      (serviceRoleKey && token === serviceRoleKey) ||
      isSecretKey(token)
    ) {
      console.log(`Service/secret key call → ${functionId} (bypassing user auth)`)
      return {
        authorized: true,
        profile: {
          id: "system",
          user_id: "system",
          nome_completo: "Sistema",
          papel_sistema: "service_role",
          condominio_id: condominioId,
        },
      }
    }
  }

  // 1. Get caller profile
  const profile = await getCallerProfile(supabase, req)
  if (!profile) {
    return {
      authorized: false,
      status: 401,
      error: "Não autenticado ou perfil não encontrado",
    }
  }

  // 2. Verify condominium ownership
  if (profile.condominio_id !== condominioId) {
    console.error(
      `Cross-condo attempt: user ${profile.id} (condo ${profile.condominio_id}) → target ${condominioId}`
    )
    return {
      authorized: false,
      status: 403,
      error: "Sem permissão para este condomínio",
    }
  }

  // 3. Check function access
  const hasAccess = await checkFunctionAccess(
    supabase,
    condominioId,
    profile.papel_sistema,
    functionId
  )

  if (!hasAccess) {
    console.error(
      `Access denied: user ${profile.id} (${profile.papel_sistema}) → function ${functionId}`
    )
    return {
      authorized: false,
      status: 403,
      error: `Perfil "${profile.papel_sistema}" não tem acesso a esta função`,
    }
  }

  return { authorized: true, profile }
}

// ── Create admin Supabase client ──────────────────────────────────────────

export function createAdminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )
}
