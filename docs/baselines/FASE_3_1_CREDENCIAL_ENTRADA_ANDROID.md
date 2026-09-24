# BASELINE OFICIAL — FASE 3.1
## CREDENCIAL DE ENTRADA ANDROID

> **STATUS:** `CLOSED` / `HOMOLOGATED` / `SAFE_FOR_RELEASE` / `FROZEN`  
> **DATA DE CONGELAMENTO:** 2026-09-24  
> **DISPOSITIVO DE HOMOLOGAÇÃO:** Pixel 8 AVD (Android 15 / API 35 / arm64-v8a)  
> **CLASSIFICAÇÃO DE SEGURANÇA:** `SAFE_FOR_RELEASE` (Isolamento Físico por Source Set)

---

## 1. ESCOPO E INFRAESTRUTURA COMPARTILHADA

A Fase 3.1 implementa a **Credencial de Entrada Persistente no Android**, utilizando a infraestrutura unificada do Flutter originada no ecossistema das Fases 3.0 e 3.1. 

A camada Dart (`LiveActivityService`) atua como fonte canônica de tempo e estado compartilhado entre as plataformas móveis:
- **iOS:** Live Activities via ActivityKit (`br.app.condomeet/live_activity`);
- **Android:** Notificação Persistente de Sistema via NotificationManagerCompat (`br.app.condomeet/entry_credential`).

A infraestrutura Flutter compartilhada não é classificada como exclusivamente Android, preservando a interoperabilidade e a integridade de ambas as plataformas.

---

## 2. ARQUITETURA PRODUTIVA ANDROID

O fluxo de dados e controle opera de ponta a ponta de forma reativa:

```
[InvitationBloc / App Lifecycle / UI Screens]
                       │
                       ▼
             [LiveActivityService]
                       │ (MethodChannel: br.app.condomeet/entry_credential)
                       ▼
            [EntryCredentialPlugin]
                       │
                       ▼
          [NotificationManagerCompat]
                       │
        ┌──────────────┴──────────────┐
        ▼                             ▼
[Channel: credencial_entrada]  [Notification ID: 88001]
```

### Parâmetros e Especificações Técnicas de Notificação:
- **Notification ID Fixo:** `88001` (garante idempotência estrita e atualização in-place sem duplicação de cards).
- **Canal de Notificação:** `credencial_entrada` (`Nome: "Credencial de Entrada"`, `Importance: HIGH`).
- **Comportamento Contínuo:** `setOngoing(true)` (impede descarte acidental por swipe enquanto houver autorizações abertas).
- **Alerta Único:** `setOnlyAlertOnce(true)` (evita interrupções sonoras ou vibrações repetitivas durante atualizações de contagem).
- **Estilo Visual:** `BigTextStyle` (suporte a expansão no painel de notificações para visualização dos códigos e status).
- **Privacidade em Lock Screen:** `setPublicVersion(publicNotification)` com `VISIBILITY_PUBLIC`, ocultando códigos sensíveis quando o aparelho estiver bloqueado.
- **TTL de Segurança:** `setTimeoutAfter(timeoutMillis)` calculado com base na expiração canônica da credencial.

---

## 3. COMPORTAMENTO FUNCIONAL POR QUANTIDADE DE AUTORIZAÇÕES

A credencial reage em tempo real à coleção de autorizações do morador:

- **0 autorizações abertas:** Cancelamento imediato e remoção da notificação do sistema (`NotificationManagerCompat.cancel(88001)`).
- **1 autorização aberta:** Credencial individual detalhada com o nome do morador, condomínio, horário limite e código de acesso destacado em fonte monoespaçada.
- **2 autorizações abertas:** Exibição dos 2 códigos de acesso abertos no painel e badge de 2 autorizações ativas.
- **3 autorizações abertas:** Exibição dos 3 códigos de acesso abertos no painel e badge de 3 autorizações ativas.
- **4 ou mais autorizações abertas:** Exibição dos 3 códigos mais recentes com o sufixo "+N outras", acompanhado do contador agregado de excedentes.

---

## 4. REGRA TEMPORAL CANÔNICA (CENTRALIZADA NO FLUTTER)

A regra de vigência da credencial é estritamente centralizada no Flutter (`LiveActivityService.calculateEffectiveExpiration`), garantindo paridade temporal matemática entre Android e iOS:

1. **Autorização criada antes das 22:00:**
   - Expiração canônica fixada às **23:59:59 do mesmo dia**.
2. **Autorização criada a partir das 22:00:**
   - Expiração canônica estendida para **`createdAt` + 6 horas** (virada da madrugada).
3. **Múltiplas autorizações:**
   - A validade do card agregado adota deterministicamente a **maior validade** entre as autorizações elegíveis do lote.

---

## 5. CICLO DE VIDA, DEEP LINKS E GUARDRAILS DE SEGURANÇA

- **Reconciliação no Primeiro Plano:**  
  No evento `AppLifecycleState.resumed` em `lib/main.dart`, a rotina `_reconcileLiveActivityOnForeground()` reavalia a coleção de convites no cache/banco e ressincroniza a credencial ativa.
- **Deep Links Nativos:**  
  O toque na notificação dispara o intent `condomeet://credentials?id=<invitationId>` (ou `target=list`), tratado pelo canal `onDeepLink`.
- **Guardrail de Ownership Pré-Navegação:**  
  Em `lib/main.dart`, qualquer deep link passa por validação mandatória de propriedade (`resident_id == authState.userId` e `condominio_id == authState.condominiumId`) antes de navegar para a tela ou renderizar dados, mitigando qualquer risco de IDOR (Insecure Direct Object Reference).

---

## 6. ISOLAMENTO FÍSICO DO TEST HARNESS (ZERO RELEASE RESIDUE)

O mecanismo de injeção de cenários de teste via broadcast (`br.app.condomeet.TEST_CREDENTIAL`) foi submetido a auditoria de segurança e hardening por **Source Set Isolation**:

- **Localização Exclusiva:** `android/app/src/debug/kotlin/br/app/condomeet/home/EntryCredentialTestReceiver.kt`
- **Declaração Exclusiva:** `android/app/src/debug/AndroidManifest.xml`
- **Variante Release:**  
  - Totalmente **AUSENTE** do source set `src/main`;
  - Totalmente **AUSENTE** do bytecode e Constant Pool de Release (`javap -v` comprovou 0 ocorrências);
  - Totalmente **AUSENTE** do Merged `AndroidManifest.xml` de Release;
  - Totalmente **AUSENTE** do APK e AAB de produção.
- **Classificação:** `SAFE_FOR_RELEASE`.

---

## 7. MATRIZ DE HOMOLOGAÇÃO VISUAL E SISTÊMICA

A homologação visual e operacional foi executada no emulador oficial Pixel 8 (Android 15 / API 35 / arm64-v8a):

| Cenário Homologado | Resultado | Evidência / Critério |
|---|---|---|
| **1 Autorização Aberta** | **PASS** | Notificação ativa com código de acesso individual e validade. |
| **2 Autorizações Abertas** | **PASS** | 2 códigos exibidos, badge atualizado. |
| **3 Autorizações Abertas** | **PASS** | 3 códigos exibidos, badge atualizado. |
| **4+ Autorizações Abertas** | **PASS** | 3 códigos mais recentes exibidos + contador "+N outras". |
| **Transição para 0 Autorizações** | **PASS** | Descarte limpo e automático da notificação pelo NotificationManager. |
| **Lock Screen (Tela Bloqueada)** | **PASS** | Exibição em modo público seguro respeitando `VISIBILITY_PUBLIC`. |
| **Notification Panel (Expandido/Recolhido)** | **PASS** | Renderização correta com estilo BigTextStyle. |
| **Dark Mode (Tema Escuro)** | **PASS** | Alto contraste, legibilidade preservada e sem artefatos visuais. |
| **Dumpsys Notification** | **PASS** | Confirmada presença do canal `credencial_entrada` e ID `88001`. |
| **Deep Link ao Toque** | **PASS** | Roteamento nativo verificado e auditado. |

> [!WARNING]
> **Limitação Técnica Registrada:**  
> A homologação da Fase 3.1 foi conduzida em ambiente Pixel 8 / AVD Google APIs Android 15. A plataforma ainda não passou por homologação física em múltiplos fabricantes (Samsung OneUI, Xiaomi MIUI/HyperOS, Motorola MyUX), ficando essa cobertura recomendada para janelas de QA de campo antes do rollout massivo.

---

## 8. SUÍTE DE TESTES E INTEGRIDADE

A baseline foi congelada com 100% de aprovação na suíte de testes:
- **`flutter analyze`:** `No issues found!` (0 alertas)
- **`live_activity_service_test.dart`:** `54/54 PASS`
- **JUnit Kotlin (`:app:testDebugUnitTest`):** `9/9 PASS` (`EntryCredentialPluginTest`)
- **`compileDebugKotlin`:** `BUILD SUCCESSFUL`
- **`compileReleaseKotlin`:** `BUILD SUCCESSFUL`
- **Build APK Debug:** `BUILD SUCCESSFUL`

---

## 9. INVARIANTES DE PRESERVAÇÃO

A implementação da Fase 3.1 preservou integralmente:
- **Backend / Supabase:** Nenhuma tabela, trigger, RPC, migração ou função de borda foi alterada.
- **WhatsApp / WABA / Meta:** Nenhuma interação ou alteração nos fluxos de mensageria operacional.
- **FCM Push Notifications:** A arquitetura de áudio e push existente (`avisos_v2`, `condomeet.mp3`) permanece intocada.
- **iOS:** A implementação de Live Activities do iOS e os artefatos nativos do Xcode permanecem preservados e fora deste commit.

---

## 10. POLÍTICA DE CONGELAMENTO (FREEZE)

Esta funcionalidade encontra-se **HOMOLOGADA E CONGELADA**. Nenhuma alteração no código nativo do `EntryCredentialPlugin`, canais de notificação, regras de expiração ou layout visual da Credencial Android poderá ser realizada sem abertura formal de nova RFC e aprovação expressa do comitê de arquitetura.
