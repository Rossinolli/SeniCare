package br.com.senicare

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings

/**
 * Disparado pelo AlarmManager no instante exato do Alarme Principal, em
 * paralelo à notificação de tela cheia do flutter_local_notifications.
 *
 * Só age quando o app tem a permissão especial "Exibir sobre outros apps"
 * (SYSTEM_ALERT_WINDOW) — é essa permissão que isenta o app da restrição do
 * Android de iniciar uma Activity a partir do background. Sem ela, este
 * receiver não faz nada e o usuário continua recebendo a notificação de
 * tela cheia normal (que já funciona hoje e não foi alterada).
 */
class OverlayAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!Settings.canDrawOverlays(context)) return

        val medId = intent.getIntExtra(MainActivity.EXTRA_ALARM_MED_ID, -1)
        val notificationId = intent.getIntExtra(MainActivity.EXTRA_ALARM_NOTIFICATION_ID, -1)
        if (medId == -1 || notificationId == -1) return

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra(MainActivity.EXTRA_ALARM_MED_ID, medId)
            putExtra(MainActivity.EXTRA_ALARM_NOTIFICATION_ID, notificationId)
        }
        context.startActivity(launchIntent)
    }
}
