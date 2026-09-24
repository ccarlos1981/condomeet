package br.app.condomeet.home

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Harness de homologação e teste local da Credencial de Entrada.
 * ATENÇÃO SOBERANA: Este receiver reside EXCLUSIVAMENTE no source set src/debug.
 * Ele é fisicamente excluído e ausente de compilações release.
 */
class EntryCredentialTestReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        if (intent.action != ACTION_TEST_CREDENTIAL) return

        val count = intent.getIntExtra("count", 1)
        val morador = intent.getStringExtra("morador") ?: "Carlos Silva"
        val condominio = intent.getStringExtra("condominio") ?: "Residencial Real Park"
        val validade = intent.getStringExtra("validade") ?: "23:59"
        val codigo = intent.getStringExtra("codigo") ?: "KJ9"
        val visitante = intent.getStringExtra("visitante")
        val rawCodigos = intent.getStringExtra("codigos")
        val codigosList = if (!rawCodigos.isNullOrEmpty()) {
            rawCodigos.split(",").map { it.trim() }.filter { it.isNotEmpty() }
        } else {
            listOf("KJ9", "9BE", "I38")
        }
        val outras = intent.getIntExtra("outras", 0)

        val payload = CredentialPayload(
            countAbertas = count,
            moradorNome = morador,
            condominioNome = condominio,
            validadeHora = validade,
            validityDateIso = intent.getStringExtra("validityDateIso"),
            invitationId = if (count == 1) "test-inv-id" else null,
            codigoAcesso = if (count == 1) codigo else null,
            visitanteNome = if (count == 1) visitante else null,
            codigosAbertos = if (count >= 2) codigosList.take(3) else emptyList(),
            outrasAbertas = outras
        )

        val plugin = EntryCredentialPlugin(context)
        plugin.handleSync(payload)
    }

    companion object {
        const val ACTION_TEST_CREDENTIAL = "br.app.condomeet.TEST_CREDENTIAL"
    }
}
