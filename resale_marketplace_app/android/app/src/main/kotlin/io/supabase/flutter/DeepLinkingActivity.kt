package io.supabase.flutter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import com.everseconds.resale_marketplace_app.MainActivity

class DeepLinkingActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        forwardToMain(intent)
        finish()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        forwardToMain(intent)
        finish()
    }

    private fun forwardToMain(sourceIntent: Intent?) {
        val deepLink: Uri? = sourceIntent?.data
        val forwardIntent = Intent(this, MainActivity::class.java).apply {
            action = sourceIntent?.action ?: Intent.ACTION_VIEW
            data = deepLink
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            sourceIntent?.extras?.let { putExtras(it) }
        }
        startActivity(forwardIntent)
    }
}
