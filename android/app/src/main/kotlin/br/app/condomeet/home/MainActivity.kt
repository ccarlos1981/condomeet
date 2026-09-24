package br.app.condomeet.home

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var entryCredentialPlugin: EntryCredentialPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val plugin = EntryCredentialPlugin(this)
        entryCredentialPlugin = plugin
        plugin.register(flutterEngine.dartExecutor.binaryMessenger)

        intent?.let { plugin.handleIntent(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        entryCredentialPlugin?.handleIntent(intent)
    }

    override fun onDestroy() {
        entryCredentialPlugin?.unregister()
        entryCredentialPlugin = null
        super.onDestroy()
    }
}

