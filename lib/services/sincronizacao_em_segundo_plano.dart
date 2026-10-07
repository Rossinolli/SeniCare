// Sincronização periódica dos alarmes em segundo plano (WorkManager).
//
// A janela de alarmes agendados é limitada (o Android aceita no máximo 500
// alarmes por app): um remédio de 4 em 4 horas cobre só ~4 dias à frente.
// Antes, se o idoso passasse dias sem abrir o app, a série acabava. Agora o
// sistema roda [sincronizarAlarmes] a cada 6 horas mesmo com o app fechado,
// empurrando a janela para frente.

import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';

const String _tarefaSincronizar = 'senicare.sincronizar_alarmes';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((tarefa, dados) async {
    try {
      DartPluginRegistrant.ensureInitialized();
      await NotificationService().init(emSegundoPlano: true);
      await NotificationService().sincronizarAlarmes();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Segundo plano] Falha: $e');
      return false; // o WorkManager tenta de novo mais tarde
    }
  });
}

/// Registra a tarefa periódica (idempotente: 'keep' não duplica).
Future<void> agendarSincronizacaoPeriodica() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _tarefaSincronizar,
      _tarefaSincronizar,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('[Segundo plano] Não foi possível agendar: $e');
  }
}
