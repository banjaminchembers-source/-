package com.example.dimon_assistant

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var asked = false
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.postDelayed({ startCookieIfAllowed() }, 800)
    }
    override fun onResume() {
        super.onResume()
        window.decorView.postDelayed({ startCookieIfAllowed() }, 400)
    }
    private fun startCookieIfAllowed() {
        if (Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(this)) {
            asked = false
            val i = Intent(this, FloatingCookieService::class.java)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
        } else if (!asked && !getSharedPreferences("cookie", MODE_PRIVATE).getBoolean("asked", false)) {
            asked = true
            getSharedPreferences("cookie", MODE_PRIVATE).edit().putBoolean("asked", true).apply()
            Toast.makeText(this, "Разреши Cookie Dimon показываться поверх приложений", Toast.LENGTH_LONG).show()
            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
        }
    }
}