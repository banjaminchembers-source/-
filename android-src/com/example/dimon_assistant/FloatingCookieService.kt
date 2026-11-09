package com.example.dimon_assistant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.*
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.sin

class FloatingCookieService : Service() {
    companion object {
        private const val CHANNEL = "cookie_mascot"
        private const val NOTIFICATION_ID = 7721
        private const val SPEECH_URL = "https://dimon-assistant-api.onrender.com/speech"
    }

    private lateinit var wm: WindowManager
    private lateinit var lp: WindowManager.LayoutParams
    private var mascot: CookieView? = null
    private val io = Executors.newSingleThreadExecutor()
    private val ui = Handler(Looper.getMainLooper())
    private var tts: TextToSpeech? = null
    private var player: MediaPlayer? = null
    @Volatile private var speaking = false

    override fun onCreate() {
        super.onCreate()
        makeChannel()
        startForeground(NOTIFICATION_ID, notification())
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale("ru", "RU")
                tts?.setSpeechRate(0.92f)
            }
        }
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        showMascot()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP_COOKIE") {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    private fun showMascot() {
        if (Build.VERSION.SDK_INT >= 23 && !Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        if (mascot != null) return
        val size = dp(106)
        val type = if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                   else WindowManager.LayoutParams.TYPE_PHONE
        lp = WindowManager.LayoutParams(size, size, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16)
            y = dp(140)
        }
        val view = CookieView()
        mascot = view
        try { wm.addView(view, lp) } catch (_: Exception) { mascot = null; stopSelf() }
    }

    private inner class CookieView : View(this@FloatingCookieService) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val born = System.currentTimeMillis()
        private var downX = 0f
        private var downY = 0f
        private var originX = 0
        private var originY = 0
        private var moved = false
        private var laughUntil = 0L

        override fun onDraw(c: Canvas) {
            super.onDraw(c)
            val d = resources.displayMetrics.density
            val cx = width * .46f
            val cy = height * .54f
            val r = width * .34f
            val now = System.currentTimeMillis()
            val laughing = now < laughUntil
            val bob = sin((now - born) / 430.0).toFloat() * d * 1.6f
            c.save()
            c.translate(0f, bob)

            paint.shader = RadialGradient(cx-r*.3f, cy-r*.4f, r*1.8f,
                intArrayOf(Color.rgb(255,225,170), Color.rgb(205,132,62), Color.rgb(151,78,36)),
                floatArrayOf(0f,.62f,1f), Shader.TileMode.CLAMP)
            c.drawCircle(cx, cy, r, paint)
            paint.shader = null
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 2.5f*d
            paint.color = Color.rgb(126,66,35)
            c.drawCircle(cx, cy, r, paint)
            paint.style = Paint.Style.FILL

            // Chocolate chips
            paint.color = Color.rgb(83,43,27)
            c.drawOval(cx-r*.65f,cy-r*.40f,cx-r*.36f,cy-r*.22f,paint)
            c.drawOval(cx+r*.34f,cy-r*.58f,cx+r*.57f,cy-r*.32f,paint)
            c.drawOval(cx-r*.53f,cy+r*.48f,cx-r*.28f,cy+r*.66f,paint)
            c.drawCircle(cx+r*.46f,cy+r*.42f,r*.10f,paint)
            c.drawCircle(cx-r*.04f,cy-r*.73f,r*.08f,paint)

            // Rosy cheeks
            paint.color = Color.argb(82,231,91,75)
            c.drawOval(cx-r*.68f,cy+r*.10f,cx-r*.30f,cy+r*.28f,paint)
            c.drawOval(cx+r*.30f,cy+r*.10f,cx+r*.68f,cy+r*.28f,paint)

            // Eyes and highlights
            paint.color = Color.rgb(48,28,22)
            c.drawOval(cx-r*.39f,cy-r*.20f,cx-r*.18f,cy+r*.12f,paint)
            c.drawOval(cx+r*.18f,cy-r*.20f,cx+r*.39f,cy+r*.12f,paint)
            paint.color = Color.WHITE
            c.drawCircle(cx-r*.31f,cy-r*.13f,r*.045f,paint)
            c.drawCircle(cx+r*.26f,cy-r*.13f,r*.045f,paint)

            // Smile turns into a laughing mouth on tap
            paint.color = Color.rgb(76,36,27)
            if (laughing) {
                c.drawOval(cx-r*.15f,cy+r*.19f,cx+r*.15f,cy+r*.53f,paint)
            } else {
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = 2.8f*d
                paint.strokeCap = Paint.Cap.ROUND
                val smile = Path().apply {
                    moveTo(cx-r*.18f,cy+r*.24f)
                    quadTo(cx,cy+r*.48f,cx+r*.18f,cy+r*.24f)
                }
                c.drawPath(smile,paint)
                paint.style = Paint.Style.FILL
            }

            // Little waving arm and hand
            val angle = if (laughing) sin(now/90.0).toFloat()*35f-10f else -24f
            c.save()
            c.rotate(angle,cx+r*.70f,cy-r*.08f)
            paint.color = Color.rgb(183,105,49)
            paint.strokeWidth = 7f*d
            paint.strokeCap = Paint.Cap.ROUND
            c.drawLine(cx+r*.67f,cy-r*.06f,cx+r*1.10f,cy-r*.45f,paint)
            paint.color = Color.rgb(222,157,82)
            c.drawCircle(cx+r*1.13f,cy-r*.49f,r*.19f,paint)
            paint.color = Color.rgb(132,70,37)
            paint.strokeWidth = 3f*d
            c.drawLine(cx+r*1.02f,cy-r*.60f,cx+r*.99f,cy-r*.78f,paint)
            c.drawLine(cx+r*1.16f,cy-r*.62f,cx+r*1.20f,cy-r*.79f,paint)
            c.restore()
            c.restore()
            postInvalidateDelayed(45)
        }

        override fun onTouchEvent(e: MotionEvent): Boolean {
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX=e.rawX; downY=e.rawY
                    originX=lp.x; originY=lp.y
                    moved=false
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx=e.rawX-downX
                    val dy=e.rawY-downY
                    if (abs(dx)>dp(5) || abs(dy)>dp(5)) moved=true
                    if (moved) {
                        val dm=resources.displayMetrics
                        lp.x=(originX+dx.toInt()).coerceIn(0,dm.widthPixels-width)
                        lp.y=(originY+dy.toInt()).coerceIn(0,dm.heightPixels-height)
                        try { wm.updateViewLayout(this,lp) } catch (_: Exception) {}
                    }
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) {
                        laughUntil=System.currentTimeMillis()+2300
                        invalidate()
                        laugh()
                    }
                    performClick()
                    return true
                }
            }
            return true
        }

        override fun performClick(): Boolean {
            super.performClick()
            return true
        }
    }

    private fun laugh() {
        if (speaking) return
        speaking=true
        val phrase="Ха-ха-ха! Привет!"
        io.execute {
            var bytes: ByteArray?=null
            try {
                val conn=URL(SPEECH_URL).openConnection() as HttpURLConnection
                conn.requestMethod="POST"
                conn.connectTimeout=12000
                conn.readTimeout=45000
                conn.doOutput=true
                conn.setRequestProperty("Content-Type","application/json; charset=utf-8")
                conn.outputStream.use { it.write(JSONObject().put("text",phrase).toString().toByteArray(Charsets.UTF_8)) }
                if (conn.responseCode in 200..299) bytes=conn.inputStream.use { it.readBytes() }
                conn.disconnect()
            } catch (_: Exception) {}
            ui.post {
                if (bytes!=null && bytes!!.isNotEmpty()) play(bytes!!)
                else {
                    tts?.speak(phrase,TextToSpeech.QUEUE_FLUSH,null,"cookie-laugh")
                    ui.postDelayed({speaking=false},2500)
                }
            }
        }
    }

    private fun play(data: ByteArray) {
        try {
            player?.release()
            val f=File(cacheDir,"cookie-laugh.mp3")
            f.writeBytes(data)
            player=MediaPlayer().apply {
                setDataSource(f.absolutePath)
                setOnCompletionListener { it.release(); player=null; speaking=false }
                setOnErrorListener { mp,_,_ ->
                    mp.release(); player=null; speaking=false
                    tts?.speak("Ха-ха-ха!",TextToSpeech.QUEUE_FLUSH,null,"cookie-fallback")
                    true
                }
                prepareAsync()
                setOnPreparedListener { it.start() }
            }
        } catch (_: Exception) {
            speaking=false
            tts?.speak("Ха-ха-ха!",TextToSpeech.QUEUE_FLUSH,null,"cookie-fallback")
        }
    }

    private fun makeChannel() {
        if (Build.VERSION.SDK_INT>=26) {
            val channel=NotificationChannel(CHANNEL,"Печенька на экране",NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun notification(): Notification {
        val stop=Intent(this,FloatingCookieService::class.java).setAction("STOP_COOKIE")
        val pending=PendingIntent.getService(this,7722,stop,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder=if (Build.VERSION.SDK_INT>=26) Notification.Builder(this,CHANNEL) else Notification.Builder(this)
        return builder.setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Cookie Dimon активен")
            .setContentText("Перетащи печеньку или нажми, чтобы она засмеялась.")
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel,"Убрать",pending)
            .build()
    }

    private fun dp(v:Int)=(v*resources.displayMetrics.density).toInt()

    override fun onDestroy() {
        try { mascot?.let { wm.removeView(it) } } catch (_:Exception) {}
        mascot=null
        player?.release(); player=null
        tts?.stop(); tts?.shutdown(); tts=null
        io.shutdownNow()
        super.onDestroy()
    }

    override fun onBind(intent:Intent?):IBinder?=null
}
