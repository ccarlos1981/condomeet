package br.app.condomeet.home

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant

/**
 * Modelos de dados para apresentação desacoplada e 100% testável.
 */
data class CredentialPayload(
    val countAbertas: Int,
    val moradorNome: String,
    val condominioNome: String,
    val validadeHora: String,
    val validityDateIso: String?,
    val invitationId: String?,
    val codigoAcesso: String?,
    val visitanteNome: String?,
    val codigosAbertos: List<String>,
    val outrasAbertas: Int
)

data class NotificationPresentation(
    val title: String,
    val collapsedContent: String,
    val expandedBigText: String,
    val publicContent: String,
    val deepLinkUri: String
)

/**
 * Funções puras de formatação, parsing defensivo e regras de apresentação da Credencial.
 * Isoladas do framework Android para permitir testes unitários em JVM sem mocks complexos.
 */
object EntryCredentialFormatter {
    const val SCHEME = "condomeet"
    const val HOST_AUTORIZACAO = "autorizacao"
    const val HOST_AUTORIZACOES = "autorizacoes"

    @Suppress("UNCHECKED_CAST")
    fun parsePayload(args: Any?): CredentialPayload {
        val map = (args as? Map<*, *>) ?: emptyMap<String, Any?>()

        val countAbertas = when (val c = map["countAbertas"]) {
            is Number -> c.toInt()
            is String -> c.toIntOrNull() ?: 0
            else -> 0
        }

        val moradorNome = (map["moradorNome"] as? String)?.trim().takeUnless { it.isNullOrEmpty() } ?: "Morador"
        val condominioNome = (map["condominioNome"] as? String)?.trim().takeUnless { it.isNullOrEmpty() } ?: "Condomínio"
        val validadeHora = (map["validadeHora"] as? String)?.trim().takeUnless { it.isNullOrEmpty() } ?: "23:59"
        val validityDateIso = (map["validityDateIso"] as? String)?.trim()

        val invitationId = (map["invitationId"] as? String)?.trim()
        val codigoAcesso = (map["codigoAcesso"] as? String)?.trim()
        val visitanteNome = (map["visitanteNome"] as? String)?.trim().takeUnless { it.isNullOrEmpty() }

        val codigosList = when (val raw = map["codigosAbertos"]) {
            is List<*> -> raw.mapNotNull { (it as? String)?.trim() }.filter { it.isNotEmpty() }
            else -> emptyList()
        }

        val outrasAbertas = when (val o = map["outrasAbertas"]) {
            is Number -> o.toInt()
            is String -> o.toIntOrNull() ?: 0
            else -> 0
        }

        return CredentialPayload(
            countAbertas = countAbertas,
            moradorNome = moradorNome,
            condominioNome = condominioNome,
            validadeHora = validadeHora,
            validityDateIso = validityDateIso,
            invitationId = invitationId,
            codigoAcesso = codigoAcesso,
            visitanteNome = visitanteNome,
            codigosAbertos = codigosList,
            outrasAbertas = outrasAbertas
        )
    }

    fun buildPresentation(payload: CredentialPayload): NotificationPresentation {
        val title = "CONDOMEET"
        val count = payload.countAbertas

        val deepLinkUri = if (count == 1 && !payload.invitationId.isNullOrEmpty()) {
            "$SCHEME://$HOST_AUTORIZACAO/${payload.invitationId}"
        } else {
            "$SCHEME://$HOST_AUTORIZACOES"
        }

        val publicContent = if (count == 1) {
            "Autorização de entrada ativa"
        } else {
            "$count autorizações ativas"
        }

        val collapsedContent: String
        val expandedBigText: String

        when {
            count <= 0 -> {
                collapsedContent = ""
                expandedBigText = ""
            }
            count == 1 -> {
                val codigo = payload.codigoAcesso ?: ""
                collapsedContent = "CÓDIGO: $codigo • Válido até ${payload.validadeHora}"

                val sb = StringBuilder()
                sb.append("AUTORIZAÇÃO DE ENTRADA\n")
                sb.append("Morador: ${payload.moradorNome}\n")
                if (!payload.visitanteNome.isNullOrEmpty()) {
                    sb.append("Visitante: ${payload.visitanteNome}\n")
                }
                sb.append("Condomínio: ${payload.condominioNome}\n\n")
                sb.append("CÓDIGO: $codigo\n")
                sb.append("Válido até ${payload.validadeHora}")
                expandedBigText = sb.toString()
            }
            count == 2 -> {
                val c1 = payload.codigosAbertos.getOrNull(0) ?: ""
                val c2 = payload.codigosAbertos.getOrNull(1) ?: ""
                val codigosStr = "$c1  |  $c2"
                collapsedContent = "ÚLTIMOS CÓDIGOS: $c1 | $c2 • Válido até ${payload.validadeHora}"

                val sb = StringBuilder()
                sb.append("ÚLTIMOS CÓDIGOS\n")
                sb.append("$codigosStr\n\n")
                sb.append("Morador: ${payload.moradorNome}\n")
                sb.append("Condomínio: ${payload.condominioNome}\n")
                sb.append("Válido até ${payload.validadeHora}")
                expandedBigText = sb.toString()
            }
            count == 3 -> {
                val c1 = payload.codigosAbertos.getOrNull(0) ?: ""
                val c2 = payload.codigosAbertos.getOrNull(1) ?: ""
                val c3 = payload.codigosAbertos.getOrNull(2) ?: ""
                val codigosStr = "$c1  |  $c2  |  $c3"
                collapsedContent = "ÚLTIMOS CÓDIGOS: $c1 | $c2 | $c3"

                val sb = StringBuilder()
                sb.append("ÚLTIMOS CÓDIGOS\n")
                sb.append("$codigosStr\n\n")
                sb.append("Morador: ${payload.moradorNome}\n")
                sb.append("Condomínio: ${payload.condominioNome}\n")
                sb.append("Válido até ${payload.validadeHora}")
                expandedBigText = sb.toString()
            }
            else -> { // count >= 4
                val c1 = payload.codigosAbertos.getOrNull(0) ?: ""
                val c2 = payload.codigosAbertos.getOrNull(1) ?: ""
                val c3 = payload.codigosAbertos.getOrNull(2) ?: ""
                val codigosStr = "$c1  |  $c2  |  $c3"
                collapsedContent = "ÚLTIMOS CÓDIGOS: $c1 | $c2 | $c3 (+ ${payload.outrasAbertas})"

                val sb = StringBuilder()
                sb.append("ÚLTIMOS CÓDIGOS\n")
                sb.append("$codigosStr\n")
                sb.append("+ ${payload.outrasAbertas} outras autorizações\n\n")
                sb.append("Morador: ${payload.moradorNome}\n")
                sb.append("Condomínio: ${payload.condominioNome}\n")
                sb.append("Válido até ${payload.validadeHora}")
                expandedBigText = sb.toString()
            }
        }

        return NotificationPresentation(
            title = title,
            collapsedContent = collapsedContent,
            expandedBigText = expandedBigText,
            publicContent = publicContent,
            deepLinkUri = deepLinkUri
        )
    }

    fun calculateTimeoutMillis(validityDateIso: String?, currentEpochMs: Long = System.currentTimeMillis()): Long? {
        if (validityDateIso.isNullOrBlank()) return null
        return try {
            val targetEpoch = Instant.parse(validityDateIso).toEpochMilli()
            val diff = targetEpoch - currentEpochMs
            if (diff > 0) diff else 0L
        } catch (_: Exception) {
            null
        }
    }
}

/**
 * Plugin nativo Android para gerenciamento da Credencial de Entrada via notificação persistente.
 */
class EntryCredentialPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val METHOD_CHANNEL_NAME = "br.app.condomeet/entry_credential"
        const val NOTIFICATION_ID = 88001
        const val CHANNEL_ID = "credencial_entrada"
        const val CHANNEL_NAME = "Credencial de Entrada"
        const val CHANNEL_DESCRIPTION = "Exibe credenciais e autorizações ativas na tela de bloqueio e painel de notificações"
    }

    private var channel: MethodChannel? = null
    private var pendingDeepLink: String? = null

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
        createNotificationChannel()
    }

    fun unregister() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            val existing = notificationManager?.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val newChannel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = CHANNEL_DESCRIPTION
                    enableLights(false)
                    enableVibration(false)
                    vibrationPattern = null
                    setSound(null, null)
                    setShowBadge(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
                notificationManager?.createNotificationChannel(newChannel)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "syncCredentialState" -> {
                try {
                    val payload = EntryCredentialFormatter.parsePayload(call.arguments)
                    val success = handleSync(payload)
                    result.success(mapOf("success" to success, "count" to payload.countAbertas))
                } catch (e: Exception) {
                    result.error("SYNC_ERROR", e.localizedMessage, null)
                }
            }
            "endCredential" -> {
                try {
                    cancelNotification()
                    result.success(mapOf("success" to true))
                } catch (e: Exception) {
                    result.error("CANCEL_ERROR", e.localizedMessage, null)
                }
            }
            "isCredentialSupported" -> {
                val areNotificationsEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
                result.success(areNotificationsEnabled)
            }
            "getInitialDeepLink" -> {
                val deepLink = pendingDeepLink
                pendingDeepLink = null
                result.success(deepLink)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    internal fun handleSync(payload: CredentialPayload): Boolean {
        if (payload.countAbertas <= 0) {
            cancelNotification()
            return true
        }

        // Checar timeout prévio
        val timeoutMs = EntryCredentialFormatter.calculateTimeoutMillis(payload.validityDateIso)
        if (timeoutMs != null && timeoutMs <= 0L) {
            // Já expirou de acordo com a validade recebida
            cancelNotification()
            return true
        }

        val presentation = EntryCredentialFormatter.buildPresentation(payload)
        postNotification(presentation, timeoutMs)
        return true
    }

    private fun postNotification(presentation: NotificationPresentation, timeoutMs: Long?) {
        val notificationManager = NotificationManagerCompat.from(context)

        val smallIcon = context.applicationInfo.icon.takeIf { it != 0 }
            ?: android.R.drawable.ic_dialog_info

        val deepLinkIntent = Intent(Intent.ACTION_VIEW, Uri.parse(presentation.deepLinkUri)).apply {
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            deepLinkIntent,
            flags
        )

        // Versão pública segura para Lock Screen quando ocultar dados confidenciais estiver ativado
        val publicNotification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(smallIcon)
            .setContentTitle(presentation.title)
            .setContentText(presentation.publicContent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .build()

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(smallIcon)
            .setContentTitle(presentation.title)
            .setContentText(presentation.collapsedContent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(presentation.expandedBigText))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicNotification)
            .setContentIntent(pendingIntent)

        if (timeoutMs != null && timeoutMs > 0) {
            builder.setTimeoutAfter(timeoutMs)
        }

        try {
            notificationManager.notify(NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // Em Android 13+ (Tiramisu), notify pode lançar SecurityException se POST_NOTIFICATIONS não for concedida
        }
    }

    fun cancelNotification() {
        val notificationManager = NotificationManagerCompat.from(context)
        notificationManager.cancel(NOTIFICATION_ID)
    }

    /**
     * Intercepta intents de deep link vindos de toques na notificação ou links externos.
     */
    fun handleIntent(intent: Intent) {
        val data: Uri? = intent.data
        if (data != null && data.scheme == EntryCredentialFormatter.SCHEME) {
            val target: String
            val isList: Boolean
            if (data.host == EntryCredentialFormatter.HOST_AUTORIZACAO) {
                val id = data.lastPathSegment
                if (!id.isNullOrBlank()) {
                    target = id
                    isList = false
                } else {
                    target = "list"
                    isList = true
                }
            } else if (data.host == EntryCredentialFormatter.HOST_AUTORIZACOES) {
                target = "list"
                isList = true
            } else {
                return
            }

            pendingDeepLink = target
            channel?.invokeMethod("onDeepLink", mapOf(
                "invitationId" to target,
                "isList" to isList
            ))
        }
    }
}
