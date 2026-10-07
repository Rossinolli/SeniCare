package br.com.senicare

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
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

        // Constantes internas do flutter_local_notifications: é assim que o
        // plugin marca a Intent que abre o app a partir de uma notificação
        // (inclusive a de tela cheia).
        private const val PLUGIN_SELECT_NOTIFICATION = "SELECT_NOTIFICATION"
        private const val PLUGIN_PAYLOAD = "payload"
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
        // Só aparece por cima da tela de bloqueio (e liga a tela) quando foi
        // aberto POR UM ALARME. Antes isso ficava ligado sempre: bastava
        // apertar o botão de energia com o app aberto para qualquer pessoa
        // ver a lista de remédios sem desbloquear o celular. O lado Dart
        // desliga de novo quando a AlarmScreen fecha (setShowOnLockScreen).
        exibirSobreTelaDeBloqueio(isAlarmIntent(intent))
        capturarExtrasDeAlarme(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (isAlarmIntent(intent)) exibirSobreTelaDeBloqueio(true)
        // App já em execução (launchMode singleTop): a Activity não é
        // recriada, então é aqui que um lançamento por overlay chega quando
        // o app já estava aberto/em background — o lado Dart já está vivo e
        // escutando, então empurramos direto pelo canal.
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

    private fun isAlarmIntent(intent: Intent?): Boolean {
        if (intent == null) return false
        if (intent.getIntExtra(EXTRA_ALARM_MED_ID, -1) != -1) return true
        if (intent.action == PLUGIN_SELECT_NOTIFICATION) {
            val payload = intent.getStringExtra(PLUGIN_PAYLOAD) ?: return false
            return payload.startsWith("alarm:") || payload.startsWith("snooze:") ||
                payload.startsWith("teste:")
        }
        return false
    }

    private fun exibirSobreTelaDeBloqueio(exibir: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(exibir)
            setTurnScreenOn(exibir)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (exibir) window.addFlags(flags) else window.clearFlags(flags)
        }
        // Mantém a tela acesa enquanto o alarme está sendo exibido.
        if (exibir) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
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
                "getAlarmHealth" -> result.success(saudeDoAlarme())
                "openPermissionSettings" -> {
                    abrirConfiguracao(call.argument<String>("kind"))
                    result.success(null)
                }
                "setShowOnLockScreen" -> {
                    exibirSobreTelaDeBloqueio(call.argument<Boolean>("show") == true)
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

    /** Tudo o que decide se o alarme realmente toca na hora, num só mapa. */
    private fun saudeDoAlarme(): Map<String, Boolean> {
        val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        return mapOf(
            "notifications" to notificationManager.areNotificationsEnabled(),
            "exactAlarms" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                alarmManager.canScheduleExactAlarms()),
            "fullScreen" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
                notificationManager.canUseFullScreenIntent()),
            "overlay" to Settings.canDrawOverlays(this),
            "batteryUnrestricted" to powerManager.isIgnoringBatteryOptimizations(packageName),
        )
    }

    @SuppressLint("BatteryLife")
    private fun abrirConfiguracao(tipo: String?) {
        val pacote = Uri.parse("package:$packageName")
        val intent = when (tipo) {
            "notifications" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            "exactAlarms" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pacote)
            } else null
            "fullScreen" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pacote)
            } else null
            "overlay" -> Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, pacote)
            // Diálogo direto "Permitir que o app rode em segundo plano?" —
            // um toque só, bem mais simples para o público idoso do que
            // procurar o app numa lista de otimização de bateria.
            "batteryUnrestricted" -> Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pacote)
            else -> null
        } ?: Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pacote)
        try {
            startActivity(intent)
        } catch (_: Exception) {
            // Algumas ROMs removem telas específicas: cai nos detalhes do app.
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pacote))
        }
    }

    private fun overlayPendingIntent(notificationId: Int, intent: Intent): PendingIntent =
        PendingIntent.getBroadcast(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    private fun cancelarAlarmeOverlay(notificationId: Int) {
        try {
            val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
            val pendingIntent = overlayPendingIntent(
                notificationId,
                Intent(this, OverlayAlarmReceiver::class.java)
            )
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        } catch (_: Exception) {
            // Cancelar um alarme que nunca existiu é inofensivo — ignoramos.
        }
    }

    private fun agendarAlarmeOverlay(medId: Int, notificationId: Int, triggerAtMillis: Long): Boolean {
        return try {
            val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, OverlayAlarmReceiver::class.java).apply {
                putExtra(EXTRA_ALARM_MED_ID, medId)
                putExtra(EXTRA_ALARM_NOTIFICATION_ID, notificationId)
            }
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                overlayPendingIntent(notificationId, intent)
            )
            true
        } catch (e: SecurityException) {
            // Sem a permissão de alarme exato — a notificação de tela cheia
            // continua funcionando normalmente como reserva.
            false
        }
    }
}
