package com.example.senicare

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val EXTRA_ALARM_MED_ID = "senicare.ALARM_MED_ID"
        const val EXTRA_ALARM_NOTIFICATION_ID = "senicare.ALARM_NOTIFICATION_ID"
        private const val CHANNEL = "senicare/overlay_alarm"
    }

    // Extras de um lançamento por overlay, guardados até o lado Dart pedir
    // por eles (consumePendingLaunch) — mesmo padrão "pull" que o
    // getNotificationAppLaunchDetails() do flutter_local_notifications já
    // usa para o caso de abertura a frio (processo morto).
    private var pendingMedId: Int? = null
    private var pendingNotificationId: Int? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Necessário para o Alarme Principal (fullScreenIntent) do SeniCare
        // conseguir aparecer e ligar a tela mesmo com o aparelho bloqueado.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        capturarExtrasDeAlarme(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // App já em execução (launchMode singleTop): a Activity não é
        // recriada, então é aqui que um lançamento por overlay chega quando
        // o app já estava aberto/em background — o lado Dart já está vivo e
        // escutando, então empurramos direto pelo canal em vez de esperar
        // ele perguntar.
        capturarExtrasDeAlarme(intent)
        val medId = pendingMedId
        val notificationId = pendingNotificationId
        if (medId != null && notificationId != null) {
            pendingMedId = null
            pendingNotificationId = null
            methodChannel?.invokeMethod(
                "onOverlayAlarm",
                mapOf("medId" to medId, "notificationId" to notificationId)
            )
        }
    }

    private fun capturarExtrasDeAlarme(intent: Intent?) {
        val medId = intent?.getIntExtra(EXTRA_ALARM_MED_ID, -1) ?: -1
        val notificationId = intent?.getIntExtra(EXTRA_ALARM_NOTIFICATION_ID, -1) ?: -1
        if (medId != -1 && notificationId != -1) {
            pendingMedId = medId
            pendingNotificationId = notificationId
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                "requestOverlayPermission" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                    )
                    result.success(null)
                }
                "consumePendingLaunch" -> {
                    val medId = pendingMedId
                    val notificationId = pendingNotificationId
                    pendingMedId = null
                    pendingNotificationId = null
                    if (medId != null && notificationId != null) {
                        result.success(mapOf("medId" to medId, "notificationId" to notificationId))
                    } else {
                        result.success(null)
                    }
                }
                "scheduleOverlayAlarm" -> {
                    val medId = (call.argument<Number>("medId"))?.toInt()
                    val notificationId = (call.argument<Number>("notificationId"))?.toInt()
                    val triggerAtMillis = (call.argument<Number>("triggerAtMillis"))?.toLong()
                    result.success(
                        if (medId == null || notificationId == null || triggerAtMillis == null) {
                            false
                        } else {
                            agendarAlarmeOverlay(medId, notificationId, triggerAtMillis)
                        }
                    )
                }
                "cancelOverlayAlarm" -> {
                    val notificationId = (call.argument<Number>("notificationId"))?.toInt()
                    if (notificationId != null) cancelarAlarmeOverlay(notificationId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun cancelarAlarmeOverlay(notificationId: Int) {
        try {
            val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, OverlayAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        } catch (_: Exception) {
            // Cancelar um alarme que nunca existiu (ex.: essa ocorrência não
            // era de tela cheia) é uma operação inofensiva — ignoramos.
        }
    }

    private fun agendarAlarmeOverlay(medId: Int, notificationId: Int, triggerAtMillis: Long): Boolean {
        return try {
            val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, OverlayAlarmReceiver::class.java).apply {
                putExtra(EXTRA_ALARM_MED_ID, medId)
                putExtra(EXTRA_ALARM_NOTIFICATION_ID, notificationId)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
            true
        } catch (e: SecurityException) {
            // Sem a permissão de alarme exato (o app já pede isso em
            // ensureExactAlarmPermission() do lado Dart) — a notificação de
            // tela cheia continua funcionando normalmente como reserva.
            false
        }
    }
}
