package com.example.dimon_assistant

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

class CookieBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        if (Build.VERSION.SDK_INT >= 23 && !Settings.canDrawOverlays(context)) return
        val service = Intent(context, FloatingCookieService::class.java)
        if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service) else context.startService(service)
    }
}