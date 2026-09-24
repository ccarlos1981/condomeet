package br.app.condomeet.home

import org.junit.Assert.*
import org.junit.Test
import java.time.Instant

class EntryCredentialPluginTest {

    @Test
    fun testConstantsCompliance() {
        assertEquals("br.app.condomeet/entry_credential", EntryCredentialPlugin.METHOD_CHANNEL_NAME)
        assertEquals(88001, EntryCredentialPlugin.NOTIFICATION_ID)
        assertEquals("credencial_entrada", EntryCredentialPlugin.CHANNEL_ID)
        assertEquals("Credencial de Entrada", EntryCredentialPlugin.CHANNEL_NAME)
        assertEquals("condomeet", EntryCredentialFormatter.SCHEME)
        assertEquals("autorizacao", EntryCredentialFormatter.HOST_AUTORIZACAO)
        assertEquals("autorizacoes", EntryCredentialFormatter.HOST_AUTORIZACOES)
    }

    @Test
    fun testParsePayloadDefensiveWithNulls() {
        val payload = EntryCredentialFormatter.parsePayload(null)
        assertEquals(0, payload.countAbertas)
        assertEquals("Morador", payload.moradorNome)
        assertEquals("Condomínio", payload.condominioNome)
        assertEquals("23:59", payload.validadeHora)
        assertNull(payload.validityDateIso)
        assertNull(payload.invitationId)
        assertNull(payload.codigoAcesso)
        assertNull(payload.visitanteNome)
        assertTrue(payload.codigosAbertos.isEmpty())
        assertEquals(0, payload.outrasAbertas)
    }

    @Test
    fun testParsePayloadSingleAuthorization() {
        val map = mapOf(
            "countAbertas" to 1,
            "moradorNome" to "Carlos Silva",
            "condominioNome" to "Residencial Real Park",
            "validadeHora" to "23:59",
            "validityDateIso" to "2026-09-23T23:59:59.000Z",
            "invitationId" to "inv-12345",
            "codigoAcesso" to "ABC",
            "visitanteNome" to "Maria Oliveira"
        )
        val payload = EntryCredentialFormatter.parsePayload(map)
        assertEquals(1, payload.countAbertas)
        assertEquals("Carlos Silva", payload.moradorNome)
        assertEquals("Residencial Real Park", payload.condominioNome)
        assertEquals("23:59", payload.validadeHora)
        assertEquals("inv-12345", payload.invitationId)
        assertEquals("ABC", payload.codigoAcesso)
        assertEquals("Maria Oliveira", payload.visitanteNome)
    }

    @Test
    fun testPresentationSingleAuthorization() {
        val payload = CredentialPayload(
            countAbertas = 1,
            moradorNome = "Carlos Silva",
            condominioNome = "Residencial Real Park",
            validadeHora = "23:59",
            validityDateIso = "2026-09-23T23:59:59.000Z",
            invitationId = "inv-abc",
            codigoAcesso = "XYZ",
            visitanteNome = "João Visitante",
            codigosAbertos = emptyList(),
            outrasAbertas = 0
        )
        val presentation = EntryCredentialFormatter.buildPresentation(payload)

        assertEquals("CONDOMEET", presentation.title)
        assertTrue(presentation.collapsedContent.contains("CÓDIGO: XYZ"))
        assertTrue(presentation.collapsedContent.contains("Válido até 23:59"))

        // Expanded BigText
        assertTrue(presentation.expandedBigText.contains("AUTORIZAÇÃO DE ENTRADA"))
        assertTrue(presentation.expandedBigText.contains("Morador: Carlos Silva"))
        assertTrue(presentation.expandedBigText.contains("Visitante: João Visitante"))
        assertTrue(presentation.expandedBigText.contains("Condomínio: Residencial Real Park"))
        assertTrue(presentation.expandedBigText.contains("CÓDIGO: XYZ"))
        assertTrue(presentation.expandedBigText.contains("Válido até 23:59"))

        // Deep Link individual
        assertEquals("condomeet://autorizacao/inv-abc", presentation.deepLinkUri)

        // Lock Screen segura (publicVersion)
        assertEquals("Autorização de entrada ativa", presentation.publicContent)
        assertFalse(presentation.publicContent.contains("XYZ"))
    }

    @Test
    fun testPresentationTwoAuthorizations() {
        val payload = CredentialPayload(
            countAbertas = 2,
            moradorNome = "Carlos Silva",
            condominioNome = "Residencial Real Park",
            validadeHora = "04:00",
            validityDateIso = "2026-09-24T04:00:00.000Z",
            invitationId = null,
            codigoAcesso = null,
            visitanteNome = null,
            codigosAbertos = listOf("C01", "C02"),
            outrasAbertas = 0
        )
        val presentation = EntryCredentialFormatter.buildPresentation(payload)

        assertEquals("CONDOMEET", presentation.title)
        assertTrue(presentation.collapsedContent.contains("ÚLTIMOS CÓDIGOS"))
        assertTrue(presentation.collapsedContent.contains("C01 | C02"))
        assertTrue(presentation.collapsedContent.contains("04:00"))

        assertTrue(presentation.expandedBigText.contains("ÚLTIMOS CÓDIGOS"))
        assertTrue(presentation.expandedBigText.contains("C01  |  C02"))
        assertTrue(presentation.expandedBigText.contains("Morador: Carlos Silva"))
        assertTrue(presentation.expandedBigText.contains("Condomínio: Residencial Real Park"))
        assertTrue(presentation.expandedBigText.contains("Válido até 04:00"))

        assertEquals("condomeet://autorizacoes", presentation.deepLinkUri)
        assertEquals("2 autorizações ativas", presentation.publicContent)
    }

    @Test
    fun testPresentationThreeAuthorizations() {
        val payload = CredentialPayload(
            countAbertas = 3,
            moradorNome = "Carlos Silva",
            condominioNome = "Residencial Real Park",
            validadeHora = "05:55",
            validityDateIso = "2026-09-24T05:55:00.000Z",
            invitationId = null,
            codigoAcesso = null,
            visitanteNome = null,
            codigosAbertos = listOf("K1", "K2", "K3"),
            outrasAbertas = 0
        )
        val presentation = EntryCredentialFormatter.buildPresentation(payload)

        assertEquals("CONDOMEET", presentation.title)
        assertTrue(presentation.collapsedContent.contains("K1 | K2 | K3"))

        assertTrue(presentation.expandedBigText.contains("ÚLTIMOS CÓDIGOS"))
        assertTrue(presentation.expandedBigText.contains("K1  |  K2  |  K3"))
        assertFalse(presentation.expandedBigText.contains("outras autorizações"))

        assertEquals("condomeet://autorizacoes", presentation.deepLinkUri)
        assertEquals("3 autorizações ativas", presentation.publicContent)
    }

    @Test
    fun testPresentationFourOrMoreAuthorizations() {
        val payload = CredentialPayload(
            countAbertas = 7,
            moradorNome = "Carlos Silva",
            condominioNome = "Residencial Real Park",
            validadeHora = "23:59",
            validityDateIso = "2026-09-23T23:59:59.000Z",
            invitationId = null,
            codigoAcesso = null,
            visitanteNome = null,
            codigosAbertos = listOf("A1", "B2", "C3"),
            outrasAbertas = 4
        )
        val presentation = EntryCredentialFormatter.buildPresentation(payload)

        assertEquals("CONDOMEET", presentation.title)
        assertTrue(presentation.collapsedContent.contains("A1 | B2 | C3 (+ 4)"))

        assertTrue(presentation.expandedBigText.contains("ÚLTIMOS CÓDIGOS"))
        assertTrue(presentation.expandedBigText.contains("A1  |  B2  |  C3"))
        assertTrue(presentation.expandedBigText.contains("+ 4 outras autorizações"))
        assertTrue(presentation.expandedBigText.contains("Morador: Carlos Silva"))
        assertTrue(presentation.expandedBigText.contains("Condomínio: Residencial Real Park"))

        assertEquals("condomeet://autorizacoes", presentation.deepLinkUri)
        assertEquals("7 autorizações ativas", presentation.publicContent)
    }

    @Test
    fun testZeroAuthorizationsCancelsContent() {
        val payload = CredentialPayload(
            countAbertas = 0,
            moradorNome = "Carlos",
            condominioNome = "Condo",
            validadeHora = "23:59",
            validityDateIso = null,
            invitationId = null,
            codigoAcesso = null,
            visitanteNome = null,
            codigosAbertos = emptyList(),
            outrasAbertas = 0
        )
        val presentation = EntryCredentialFormatter.buildPresentation(payload)
        assertEquals("", presentation.collapsedContent)
        assertEquals("", presentation.expandedBigText)
        assertEquals("condomeet://autorizacoes", presentation.deepLinkUri)
    }

    @Test
    fun testTimeoutCalculation() {
        val now = Instant.now()
        val future = now.plusSeconds(3600)
        val past = now.minusSeconds(3600)

        val timeoutFuture = EntryCredentialFormatter.calculateTimeoutMillis(future.toString(), now.toEpochMilli())
        assertNotNull(timeoutFuture)
        assertEquals(3600000L, timeoutFuture)

        val timeoutPast = EntryCredentialFormatter.calculateTimeoutMillis(past.toString(), now.toEpochMilli())
        assertNotNull(timeoutPast)
        assertEquals(0L, timeoutPast)

        assertNull(EntryCredentialFormatter.calculateTimeoutMillis(null, now.toEpochMilli()))
        assertNull(EntryCredentialFormatter.calculateTimeoutMillis("invalid-iso-date", now.toEpochMilli()))
    }
}
