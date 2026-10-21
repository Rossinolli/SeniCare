// Ponto de entrada do SeniCare: prepara notificações, preferências e
// formatação de datas, e então abre o app.
//
// Arquitetura (detalhes em docs/ARQUITETURA.md):
//   domain/    regras de negócio em Dart puro (horários, agenda, posologia)
//   data/      banco local (Drift/SQLite) e repositório
//   services/  notificações, alarmes, fotos, tarefas em segundo plano
//   core/      tema, componentes visuais, estado global (Riverpod)
//   features/  telas

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/estado.dart';
import 'core/formatos.dart';
import 'features/app.dart';
import 'services/notification_service.dart';
import 'services/sincronizacao_em_segundo_plano.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Intl.defaultLocale = 'pt_BR';
  final NotificationService notificacoes = NotificationService();

  // As três preparações são independentes: em paralelo, a abertura fica
  // mais rápida (sobretudo em aparelhos antigos, com armazenamento lento).
  final (_, _, SharedPreferences prefs) = await (
    initializeDateFormatting('pt_BR'),
    notificacoes.init(),
    SharedPreferences.getInstance(),
  ).wait;

  // Se o app foi aberto POR um alarme, a tela de alarme abre logo após o
  // primeiro frame (ver MainShell).
  final AlarmLaunchInfo? alarmeInicial = await notificacoes
      .alarmeQueAbriuOApp();
  if (alarmeInicial != null) notificacoes.alarmePendente.value = alarmeInicial;

  // Licença da fonte embutida (Ajustes > Sobre > Licenças).
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Great Vibes (fonte)',
    ], await rootBundleLoad('assets/fonts/OFL-GreatVibes.txt'));
  });

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SeniCareApp(),
    ),
  );

  // Fora do caminho crítico da abertura.
  unawaited(agendarSincronizacaoPeriodica());
}
