/**
 * run_password_reset_smoke_test.ts — CLI Smoke Test Runner
 * 
 * Permite executar o Smoke Test oficial via CLI (Deno):
 *   deno run --allow-net --allow-env supabase/functions/tests/run_password_reset_smoke_test.ts
 */

import { runPasswordResetE2ETests } from "./password_reset_whatsapp_e2e_test.ts"

console.log("=================================================================")
console.log("🚀 EXECUTANDO SMOKE TEST OFICIAL VIA CLI — RECUPERAÇÃO DE SENHA")
console.log("=================================================================")

try {
  await runPasswordResetE2ETests()
  console.log("✅ SMOKE TEST EXECUTADO COM SUCESSO E SEM ERROS!")
} catch (err: any) {
  console.error("❌ SMOKE TEST FALHOU:", err.message)
  Deno.exit(1)
}
