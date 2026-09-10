// Cuida de todos os avisos de remédio: agenda o lembrete antecipado e o
// alarme na hora certa, pede as permissões necessárias no Android, e
// cancela ou adia um alarme quando o usuário pede.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'alarm_screen.dart';
import 'app_preferences.dart';

final GlobalKey<NavigatorState> notificationNavigatorKey =
    GlobalKey<NavigatorState>();

class AlarmLaunchInfo {
  final int medicamentoId;
  final int notificationId;

  const AlarmLaunchInfo({
    required this.medicamentoId,
    required this.notificationId,
  });
}

/// Callback de notificação em background: obrigatório ser uma função
/// top-level (ou estática) anotada com @pragma('vm:entry-point') — sem essa
/// anotação, o compilador Dart em modo Release pode fazer tree-shaking dessa
/// função por "não ser usada" no isolate principal, e o plugin nativo trava/
/// crasha ao tentar invocar um callback que não existe mais no binário.
/// Executa numa isolate separada, sem acesso a UI/estado do app; a
/// navegação real para a AlarmScreen acontece via getNotificationAppLaunchDetails()
/// quando o app reabre.
@pragma('vm:entry-point')
void notificationTapBackgroundHandler(
  NotificationResponse notificationResponse,
) {
  // ignore: avoid_print
  print(
    '🔔 [NotificationService] (background isolate) resposta recebida: ${notificationResponse.payload}',
  );
}

enum _NotificationKind { reminder, alarm }

/// Preferência do usuário (chave 'alert_mode' no SharedPreferences) sobre
/// como ser avisado na hora do remédio.
enum _AlertMode { both, notificationsOnly, alarmsOnly }

class NotificationService {
  // Instância Singleton
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Canal nativo do lançamento por overlay: um alarme agendado direto no
  /// AlarmManager do Android, em paralelo à notificação de tela cheia do
  /// flutter_local_notifications, que abre o app por cima de qualquer outro
  /// em uso quando o usuário concede a permissão especial "Exibir sobre
  /// outros apps" — sem essa permissão, é um no-op seguro do lado nativo, e
  /// a notificação de tela cheia (que já funciona hoje) continua intacta.
  static const MethodChannel _overlayChannel = MethodChannel(
    'senicare/overlay_alarm',
  );

  static const String _alarmChannelId = 'medication_alarm_channel';
  static const String _reminderChannelId = 'medication_reminder_channel';
  static const String _stockChannelId = 'stock_channel_id';

  // Quantas ocorrências futuras são agendadas de uma vez (ex.: 8 semanas para
  // Horários Fixos, 8 dias para Intervalo). Cada ocorrência ganha um ID único,
  // então o usuário pode confirmar/adiar a dose de hoje sem afetar as próximas.
  static const int _occurrencesAhead = 8;

  Future<void> init() async {
    if (_initialized) return;

    _configureLocalTimeZone();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        ); // Substitua caso seu ícone base tenha outro nome

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    try {
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse:
            notificationTapBackgroundHandler,
      );
    } catch (e) {
      debugPrint('[NotificationService] Falha ao inicializar plugin: $e');
    }

    await _createNotificationChannels();
    await _requestAndroidPermissions();

    _initialized = true;
  }

  /// Configura o fuso horário local de forma resiliente: nunca deixa uma
  /// falha aqui impedir o app de funcionar (na pior das hipóteses, cai em
  /// UTC e os alarmes continuam sendo agendados, só que sem ajuste de fuso).
  void _configureLocalTimeZone() {
    try {
      // 1) Carrega a base IANA de fusos horários embutida no pacote.
      tzdata.initializeTimeZones();
      // 2) Descobre e fixa o fuso local (tz.local) do aparelho.
      final String zoneName = _guessLocalTimeZoneName();
      tz.setLocalLocation(tz.getLocation(zoneName));

      // ignore: avoid_print
      print('⏰ [NotificationService] Fuso horário detectado: $zoneName');
      // Esta linha é o teste definitivo de sincronização: se o horário
      // "tz" e o horário bruto do aparelho não baterem (minuto/segundo),
      // é a prova de que a conversão para tz.TZDateTime está desalinhada.
      // ignore: avoid_print
      print(
        '⏰ [NotificationService] tz.TZDateTime.now(tz.local) = ${tz.TZDateTime.now(tz.local)}  |  DateTime.now() (aparelho) = ${DateTime.now()}',
      );
    } catch (e) {
      // ignore: avoid_print
      print(
        '🔴 [NotificationService] Falha ao configurar fuso horário, usando UTC: $e',
      );
      try {
        tz.setLocalLocation(tz.UTC);
      } catch (_) {
        // Se nem isso funcionar, seguimos com o local padrão do pacote.
      }
    }
  }

  /// O pacote 'timezone' não sabe sozinho qual é o fuso do aparelho. Sem
  /// adicionar um plugin nativo extra só para isso, comparamos o offset atual
  /// do dispositivo com o offset de cada fuso da base IANA embutida no
  /// pacote e usamos o primeiro que bater.
  String _guessLocalTimeZoneName() {
    final Duration deviceOffset = DateTime.now().timeZoneOffset;
    for (final String name in tz.timeZoneDatabase.locations.keys) {
      try {
        final tz.TZDateTime now = tz.TZDateTime.now(tz.getLocation(name));
        if (now.timeZoneOffset == deviceOffset) {
          return name;
        }
      } catch (_) {
        continue;
      }
    }
    return 'UTC';
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    try {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _alarmChannelId,
          'Alarmes de Medicamento',
          description: 'Alarme principal, na hora exata de tomar o remédio',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _reminderChannelId,
          'Lembretes Prévios',
          description: 'Aviso 30 minutos antes do horário do remédio',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _stockChannelId,
          'Lembretes de Estoque',
          description: 'Canal para lembretes de compra de medicamentos',
          importance: Importance.max,
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] Falha ao criar canais: $e');
    }
  }

  /// Solicita as permissões necessárias no Android 13+ (notificações) e no
  /// Android 12+ (alarmes exatos). Cada chamada é isolada em try/catch: se o
  /// usuário negar ou o método não existir na versão do SO, o app continua
  /// funcionando (só o alarme pode não disparar/atrasar).
  Future<void> _requestAndroidPermissions() async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    try {
      await androidPlugin.requestNotificationsPermission();
    } catch (e) {
      debugPrint(
        '[NotificationService] Permissão de notificação (Android 13+) indisponível: $e',
      );
    }
    try {
      await androidPlugin.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint(
        '[NotificationService] Permissão de alarme exato indisponível: $e',
      );
    }
  }

  /// Garante a permissão POST_NOTIFICATIONS (Android 13+). Retorna true se já
  /// estava concedida ou se o usuário acabou de concedê-la.
  Future<bool> ensureNotificationPermission() async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return true; // Não é Android: nada a garantir aqui.
    }

    try {
      final bool? granted = await androidPlugin
          .requestNotificationsPermission();
      return granted ?? true;
    } catch (e) {
      debugPrint(
        '[NotificationService] Falha ao garantir permissão de notificação: $e',
      );
      return false;
    }
  }

  /// Verifica a permissão especial "Alarmes e Lembretes" (SCHEDULE_EXACT_ALARM,
  /// obrigatória no Android 12+ para o alarme disparar na hora exata). Se não
  /// estiver concedida, abre diretamente o diálogo/tela nativa do Android para
  /// o usuário concedê-la — essa permissão NUNCA aparece como pop-up comum.
  Future<bool> ensureExactAlarmPermission() async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return true; // Não é Android: nada a garantir aqui.
    }

    try {
      final bool? jaConcedida = await androidPlugin
          .canScheduleExactNotifications();
      if (jaConcedida == true) return true;
    } catch (e) {
      debugPrint(
        '[NotificationService] Não foi possível checar a permissão de alarme exato: $e',
      );
    }

    try {
      // Em versões do Android que suportam, isso abre diretamente a tela do
      // sistema "Alarmes e lembretes" para o app.
      final bool? concedidaAgora = await androidPlugin
          .requestExactAlarmsPermission();
      return concedidaAgora ?? false;
    } catch (e) {
      debugPrint(
        '[NotificationService] Falha ao solicitar permissão de alarme exato: $e',
      );
      return false;
    }
  }

  /// Verifica se o app tem a permissão especial "Exibir sobre outros apps"
  /// (Android). Sem ela, o Alarme Principal continua funcionando como uma
  /// notificação de tela cheia normal — precisa ser tocada para abrir a
  /// AlarmScreen quando o aparelho está desbloqueado e em uso.
  Future<bool> hasOverlayPermission() async {
    try {
      final bool? concedida = await _overlayChannel.invokeMethod<bool>(
        'hasOverlayPermission',
      );
      return concedida ?? false;
    } catch (e) {
      debugPrint(
        '[NotificationService] Falha ao checar permissão de overlay: $e',
      );
      return false;
    }
  }

  /// Abre a tela do sistema (fora do app) onde o usuário concede "Exibir
  /// sobre outros apps" para o SeniCare.
  Future<void> requestOverlayPermission() async {
    try {
      await _overlayChannel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint(
        '[NotificationService] Falha ao abrir a tela de permissão de overlay: $e',
      );
    }
  }

  /// Agenda, em paralelo à notificação de tela cheia, o alarme nativo que
  /// abre o app diretamente por cima de qualquer app em uso. Só tem efeito
  /// se a permissão de overlay já foi concedida — do contrário é um no-op
  /// seguro do lado nativo (ver [OverlayAlarmReceiver] no Kotlin).
  Future<void> _scheduleOverlayAlarm({
    required int medId,
    required int notificationId,
    required tz.TZDateTime scheduledDate,
  }) async {
    try {
      await _overlayChannel.invokeMethod('scheduleOverlayAlarm', {
        'medId': medId,
        'notificationId': notificationId,
        'triggerAtMillis': scheduledDate.millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint(
        '[NotificationService] Falha ao agendar alarme de overlay: $e',
      );
    }
  }

  /// Cancela o alarme nativo de overlay correspondente a [notificationId].
  /// Seguro de chamar mesmo quando essa ocorrência nunca teve um alarme de
  /// overlay agendado (ex.: lembrete prévio, ou tela cheia desativada).
  Future<void> _cancelOverlayAlarm(int notificationId) async {
    try {
      await _overlayChannel.invokeMethod('cancelOverlayAlarm', {
        'notificationId': notificationId,
      });
    } catch (e) {
      debugPrint(
        '[NotificationService] Falha ao cancelar alarme de overlay: $e',
      );
    }
  }

  /// Verifica se o app foi aberto do zero (processo morto) por um
  /// lançamento por overlay. Deve ser chamado junto de [getLaunchAlarmInfo],
  /// logo após init(), antes de runApp.
  Future<AlarmLaunchInfo?> getOverlayLaunchInfo() async {
    try {
      final Map<dynamic, dynamic>? resultado = await _overlayChannel
          .invokeMapMethod<String, dynamic>('consumePendingLaunch');
      if (resultado == null) return null;
      final int? medId = resultado['medId'] as int?;
      final int? notificationId = resultado['notificationId'] as int?;
      if (medId == null || notificationId == null) return null;
      return AlarmLaunchInfo(
        medicamentoId: medId,
        notificationId: notificationId,
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Falha ao ler lançamento por overlay: $e',
      );
      return null;
    }
  }

  /// Escuta lançamentos por overlay que chegam com o app já em execução
  /// (MainActivity.onNewIntent no lado nativo, quando o overlay foi
  /// disparado com o app aberto/em background). Chame uma única vez, cedo
  /// na vida do widget principal.
  void listenForOverlayAlarms(void Function(AlarmLaunchInfo info) onAlarm) {
    _overlayChannel.setMethodCallHandler((call) async {
      if (call.method != 'onOverlayAlarm') return;
      final Map<dynamic, dynamic> args = call.arguments as Map;
      final int? medId = args['medId'] as int?;
      final int? notificationId = args['notificationId'] as int?;
      if (medId != null && notificationId != null) {
        onAlarm(
          AlarmLaunchInfo(medicamentoId: medId, notificationId: notificationId),
        );
      }
    });
  }

  void _onNotificationTapped(NotificationResponse response) {
    final AlarmLaunchInfo? info = _parseAlarmPayload(response.payload);
    if (info == null) return;
    notificationNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlarmScreen(
          medicamentoId: info.medicamentoId,
          notificationId: info.notificationId,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Verifica se o app foi aberto do zero (processo morto) por causa de um
  /// toque na notificação de Alarme Principal. Deve ser chamado logo após
  /// `init()`, antes de `runApp`, para decidir se a AlarmScreen precisa ser
  /// empilhada assim que a navegação inicial terminar.
  Future<AlarmLaunchInfo?> getLaunchAlarmInfo() async {
    try {
      final NotificationAppLaunchDetails? details =
          await flutterLocalNotificationsPlugin
              .getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return _parseAlarmPayload(details.notificationResponse?.payload);
    } catch (e) {
      debugPrint(
        '[NotificationService] Falha ao ler detalhes de lançamento: $e',
      );
      return null;
    }
  }

  AlarmLaunchInfo? _parseAlarmPayload(String? payload) {
    if (payload == null || !payload.startsWith('alarm:')) return null;
    final parts = payload.split(':');
    if (parts.length < 3) return null;
    final int? medId = int.tryParse(parts[1]);
    final int? notifId = int.tryParse(parts[2]);
    if (medId == null || notifId == null) return null;
    return AlarmLaunchInfo(medicamentoId: medId, notificationId: notifId);
  }

  /// Gera o ID de notificação a partir do medicamento + do instante EXATO
  /// agendado (não de um índice sequencial). Este é o fix do bug relatado:
  /// antes o ID dependia só de um índice de 0 a 7 reciclado a cada chamada
  /// de scheduleMedicationAlarms — como 'Horários Fixos' agora agenda um dia
  /// da semana por chamada (loop em add_medication_screen.dart), a chamada
  /// de terça-feira gerava os MESMOS IDs da de segunda-feira e sobrescrevia
  /// (cancelava) o agendamento anterior no flutter_local_notifications.
  /// Derivar o ID do instante exato (segundos desde a época) garante que
  /// cada combinação (medicamento, horário, tipo) tenha um ID sempre único.
  int _notificationId(
    _NotificationKind kind,
    int medId,
    tz.TZDateTime instante,
  ) {
    final int segundosDesdeAEpoca = instante.millisecondsSinceEpoch ~/ 1000;
    final int hash = Object.hash(medId, segundosDesdeAEpoca, kind);
    return hash & 0x7FFFFFFF; // int32 positivo, sempre válido no Android
  }

  Future<_AlertMode> _getAlertMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String valor =
          prefs.getString(AppPreferenceKeys.alertMode) ??
          AppPreferenceDefaults.alertMode;
      switch (valor) {
        case 'notifications_only':
          return _AlertMode.notificationsOnly;
        case 'alarms_only':
          return _AlertMode.alarmsOnly;
        case 'both':
        default:
          return _AlertMode.both;
      }
    } catch (e) {
      // ignore: avoid_print
      print(
        '🔴 [NotificationService] Falha ao ler alert_mode, usando "both": $e',
      );
      return _AlertMode.both;
    }
  }

  static const Duration _antecedenciaLembretePrevio = Duration(minutes: 30);

  /// Agenda os alertas reais de um horário de medicamento: para cada uma das
  /// próximas [_occurrencesAhead] repetições (semanais para Horários Fixos,
  /// diárias para Intervalo) agenda, conforme a preferência 'alert_mode':
  ///   A) um Lembrete Prévio normal, 30 minutos antes;
  ///   B) o Alarme Principal em tela cheia (fullScreenIntent) OU uma
  ///      notificação padrão de alta prioridade, no horário exato.
  ///
  /// [scheduledTime] deve ser a PRÓXIMA ocorrência futura desse horário
  /// específico (ex.: já ajustada para o dia da semana correto).
  Future<void> scheduleMedicationAlarms(
    Map<String, dynamic> medicationData,
    DateTime scheduledTime,
  ) async {
    // À prova de falhas: 'medicationData['id']' nunca deve ser lido com um
    // cast direto ('as int?'), pois se algum dia chegar aqui com um tipo
    // inesperado (ex.: String) o cast lança exceção ANTES de qualquer log
    // ser impresso — exatamente o sintoma de "agendamento parou e não
    // aparece nenhum log". Extraímos com segurança em vez disso.
    final dynamic idBruto = medicationData['id'];
    final int? medId = idBruto is int
        ? idBruto
        : int.tryParse(idBruto?.toString() ?? '');
    if (medId == null) {
      // ignore: avoid_print
      print(
        '🚨 ERRO FATAL AO AGENDAR ALARME: medicationData sem "id" numérico válido (valor recebido: $idBruto).',
      );
      return;
    }

    final _AlertMode alertMode = await _getAlertMode();

    // Reforça a permissão de alarme exato aqui também (não só em init()):
    // o usuário pode ter negado na primeira vez e concedido depois pelas
    // Configurações do Android, ou o app pode ter sido atualizado.
    await ensureExactAlarmPermission();

    final String nomeBruto = (medicationData['nome'] as String?) ?? '';
    final String nome = nomeBruto.trim().isNotEmpty ? nomeBruto : 'seu remédio';
    final String descricao = ((medicationData['descricao'] as String?) ?? '')
        .trim();
    final bool isHorarioFixo =
        medicationData['frequencia_tipo'] == 'Horários Fixos';
    final Duration recorrencia = isHorarioFixo
        ? const Duration(days: 7)
        : const Duration(days: 1);

    // Conversão explícita e precisa do DateTime "cru" recebido para o
    // horário com fuso (tz.TZDateTime), usando o fuso local já configurado
    // em init(). É exatamente aqui que uma dessincronização de timezone
    // se manifestaria, então logamos os dois lados da conversão.
    final tz.TZDateTime agoraNaConversao = tz.TZDateTime.now(tz.local);
    // ignore: avoid_print
    print(
      '⏰ [NotificationService] ---- scheduleMedicationAlarms(medId=$medId, alert_mode=$alertMode) ----',
    );
    // ignore: avoid_print
    print(
      '⏰ [NotificationService] Agora (tz.TZDateTime.now(tz.local)): $agoraNaConversao',
    );
    // ignore: avoid_print
    print(
      '⏰ [NotificationService] scheduledTime recebido (DateTime bruto): $scheduledTime',
    );

    tz.TZDateTime primeiraOcorrencia;
    try {
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );
      // ignore: avoid_print
      print(
        '⏰ [NotificationService] tzScheduledTime convertido: $tzScheduledTime',
      );
      primeiraOcorrencia = tzScheduledTime;
    } catch (e) {
      // ignore: avoid_print
      print(
        '🔴 [NotificationService] Falha ao converter scheduledTime para tz.TZDateTime: $e',
      );
      return;
    }

    while (!primeiraOcorrencia.isAfter(agoraNaConversao)) {
      primeiraOcorrencia = primeiraOcorrencia.add(recorrencia);
    }

    for (int i = 0; i < _occurrencesAhead; i++) {
      final tz.TZDateTime ocorrencia = primeiraOcorrencia.add(recorrencia * i);
      await _scheduleSingleOccurrence(
        medId: medId,
        nome: nome,
        descricao: descricao,
        ocorrencia: ocorrencia,
        occurrenceIndex: i,
        alertMode: alertMode,
      );
    }
  }

  Future<void> _scheduleSingleOccurrence({
    required int medId,
    required String nome,
    required String descricao,
    required tz.TZDateTime ocorrencia,
    required int occurrenceIndex,
    required _AlertMode alertMode,
  }) async {
    final String corpoBase = descricao.isNotEmpty ? '$nome - $descricao' : nome;
    final tz.TZDateTime lembreteTime = ocorrencia.subtract(
      _antecedenciaLembretePrevio,
    );

    // ignore: avoid_print
    print(
      '⏰ [NotificationService] Ocorrência #$occurrenceIndex -> alarme: $ocorrencia | lembrete: $lembreteTime',
    );

    // --- Agendamento A: Lembrete Prévio (notificação simples, 30 min antes) ---
    // No modo 'alarms_only' o usuário pediu para só ser avisado no horário
    // exato, então pulamos o lembrete de propósito.
    if (alertMode == _AlertMode.alarmsOnly) {
      // ignore: avoid_print
      print(
        '⏭️ [NotificationService] Lembrete prévio pulado (alert_mode = alarms_only)',
      );
    } else {
      // Trava anti-passado: se o lembrete cair no passado, ignoramos ele e
      // seguimos direto para o Alarme Principal — que é o que realmente importa.
      final tz.TZDateTime agoraLembrete = tz.TZDateTime.now(tz.local);
      if (lembreteTime.isAfter(agoraLembrete)) {
        final int reminderId = _notificationId(
          _NotificationKind.reminder,
          medId,
          lembreteTime,
        );
        const NotificationDetails detalhesLembrete = NotificationDetails(
          android: AndroidNotificationDetails(
            _reminderChannelId,
            'Lembretes Prévios',
            channelDescription: 'Aviso 30 minutos antes do horário do remédio',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
        );
        try {
          await flutterLocalNotificationsPlugin.zonedSchedule(
            reminderId,
            'SeniCare: Atenção!',
            'Em 30 minutos você deve tomar o $corpoBase',
            lembreteTime,
            detalhesLembrete,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            // Prefixo 'reminder:' (não 'alarm:') faz a AlarmScreen ignorar o
            // toque neste lembrete; o payload existe para cancelMedicationAlarms
            // conseguir localizar e cancelar por medicamento.
            payload: 'reminder:$medId:$reminderId',
          );
          // ignore: avoid_print
          print(
            '✅ [NotificationService] Lembrete prévio (id=$reminderId) agendado com sucesso para: $lembreteTime',
          );
        } catch (e, st) {
          // ignore: avoid_print
          print(
            '🔴 [NotificationService] FALHA ao agendar lembrete prévio (id=$reminderId): $e',
          );
          // ignore: avoid_print
          print('🚨 ERRO FATAL AO AGENDAR ALARME: $e');
          // ignore: avoid_print
          print(st);
        }
      } else {
        // ignore: avoid_print
        print(
          '⏭️ [NotificationService] Lembrete prévio (med $medId) IGNORADO — cairia no passado: $lembreteTime',
        );
      }
    }

    // --- Agendamento B: horário exato (Alarme em tela cheia OU notificação padrão) ---
    final tz.TZDateTime agoraAlarme = tz.TZDateTime.now(tz.local);
    if (ocorrencia.isAfter(agoraAlarme)) {
      final int alarmId = _notificationId(
        _NotificationKind.alarm,
        medId,
        ocorrencia,
      );
      // 'notifications_only': mesma prioridade alta do alarme, mas sem tomar
      // a tela inteira nem tocar em loop — uma notificação padrão mesmo.
      // Condição explícita (em vez de só "!= notificationsOnly") para deixar
      // claro que APENAS 'both' e 'alarms_only' acionam a tela cheia.
      final bool usarTelaCheia =
          alertMode == _AlertMode.both || alertMode == _AlertMode.alarmsOnly;
      await _zonedScheduleComProtecao(
        id: alarmId,
        medId: medId,
        title: 'SeniCare: Hora do Remédio!',
        // Estritamente o nome do remédio — sem concatenar a descrição/motivo.
        body: 'Está na hora de tomar $nome',
        scheduledDate: ocorrencia,
        payload: 'alarm:$medId:$alarmId',
        comTelaCheia: usarTelaCheia,
        descricaoLog: 'Alarme principal',
      );
    } else {
      // ignore: avoid_print
      print(
        '⏭️ [NotificationService] Alarme principal (med $medId) IGNORADO — cairia no passado: $ocorrencia',
      );
    }
  }

  /// Monta os detalhes Android do Alarme Principal. [comTelaCheia] controla
  /// fullScreenIntent/FLAG_INSISTENT/category — usado tanto para a tentativa
  /// normal quanto para o fallback sem tela cheia.
  AndroidNotificationDetails _buildAlarmAndroidDetails({
    required bool comTelaCheia,
  }) {
    return AndroidNotificationDetails(
      _alarmChannelId,
      'Alarmes de Medicamento',
      channelDescription: 'Alarme principal, na hora exata de tomar o remédio',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: comTelaCheia,
      category: comTelaCheia
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      playSound: true,
      enableVibration: true,
      ongoing: comTelaCheia,
      autoCancel: !comTelaCheia,
      // FLAG_INSISTENT (4): só com tela cheia — o som/vibração do sistema
      // tocam em loop até o usuário responder, imitando um alarme contínuo
      // sem precisar de um áudio próprio nem de um Service nativo.
      additionalFlags: comTelaCheia ? Int32List.fromList(<int>[4]) : null,
    );
  }

  /// Agenda uma notificação de alarme com proteção total contra falhas: se a
  /// chamada lançar (ex.: SecurityException do Android 14+/API 34 quando a
  /// permissão especial USE_FULL_SCREEN_INTENT não foi concedida pelo
  /// usuário nas configurações) e a notificação pedia tela cheia, tenta de
  /// novo IMEDIATAMENTE com fullScreenIntent desativado. O app NUNCA deve
  /// travar nem deixar de notificar por causa dessa permissão específica.
  Future<void> _zonedScheduleComProtecao({
    required int id,
    required int medId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
    required bool comTelaCheia,
    required String descricaoLog,
  }) async {
    // Independente da notificação de tela cheia (abaixo): o alarme de
    // overlay é um mecanismo nativo à parte, então agendamos os dois em
    // paralelo — se um falhar, o outro continua sendo a rede de segurança.
    if (comTelaCheia) {
      await _scheduleOverlayAlarm(
        medId: medId,
        notificationId: id,
        scheduledDate: scheduledDate,
      );
    }

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: _buildAlarmAndroidDetails(comTelaCheia: comTelaCheia),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      // ignore: avoid_print
      print(
        '✅ [NotificationService] $descricaoLog (id=$id, telaCheia=$comTelaCheia) agendado com sucesso para: $scheduledDate',
      );
    } catch (e, st) {
      // ignore: avoid_print
      print(
        '🔴 [NotificationService] FALHA ao agendar $descricaoLog (id=$id, telaCheia=$comTelaCheia): $e',
      );
      // ignore: avoid_print
      print('🚨 ERRO FATAL AO AGENDAR ALARME: $e');
      // ignore: avoid_print
      print(st);

      if (!comTelaCheia) {
        return; // já era o fallback, não há mais para onde cair.
      }

      // ignore: avoid_print
      print(
        '⚠️ [NotificationService] Tentando fallback SEM tela cheia para o id=$id (possível SecurityException por falta de USE_FULL_SCREEN_INTENT no Android 14+)',
      );
      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          NotificationDetails(
            android: _buildAlarmAndroidDetails(comTelaCheia: false),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        // ignore: avoid_print
        print(
          '✅ [NotificationService] Fallback sem tela cheia agendado com sucesso para id=$id',
        );
      } catch (e2, st2) {
        // ignore: avoid_print
        print(
          '🔴 [NotificationService] FALHA TOTAL ao agendar $descricaoLog (id=$id), mesmo sem tela cheia: $e2',
        );
        // ignore: avoid_print
        print('🚨 ERRO FATAL AO AGENDAR ALARME: $e2');
        // ignore: avoid_print
        print(st2);
      }
    }
  }

  /// Cancela todos os alertas (lembretes + alarmes + um eventual snooze)
  /// previamente agendados para um medicamento. Chamado antes de reagendar
  /// (edição) e ao excluir.
  ///
  /// Como o ID agora é derivado do instante exato agendado (e não mais de um
  /// índice fixo de 0 a [_occurrencesAhead]), não dá para reconstruir os IDs
  /// aqui sem recalcular exatamente as mesmas ocorrências futuras. Em vez
  /// disso, consultamos as notificações realmente pendentes no sistema e
  /// cancelamos as que carregam o ID deste medicamento no payload
  /// (`alarm:medId:...` ou `reminder:medId:...`).
  Future<void> cancelMedicationAlarms(int medicamentoId) async {
    try {
      final List<PendingNotificationRequest> pendentes =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      int canceladas = 0;
      for (final PendingNotificationRequest pendente in pendentes) {
        final String? payload = pendente.payload;
        if (payload == null) continue;
        final List<String> partes = payload.split(':');
        if (partes.length < 2) continue;
        if (partes[0] != 'alarm' && partes[0] != 'reminder') continue;
        final int? payloadMedId = int.tryParse(partes[1]);
        if (payloadMedId == medicamentoId) {
          await flutterLocalNotificationsPlugin.cancel(pendente.id);
          await _cancelOverlayAlarm(pendente.id);
          canceladas++;
        }
      }
      // ignore: avoid_print
      print(
        '🗑️ [NotificationService] $canceladas alerta(s) cancelado(s) para o medicamento $medicamentoId',
      );
    } catch (e) {
      // ignore: avoid_print
      print(
        '🔴 [NotificationService] Falha ao cancelar alarmes do medicamento $medicamentoId: $e',
      );
    }
  }

  /// Dispensa uma notificação de alarme específica (usado pela AlarmScreen
  /// ao confirmar "Já Tomei!" ou antes de reagendar o "Adiar"). Cancela só a
  /// ocorrência em questão, sem afetar as próximas já agendadas.
  Future<void> dismissAlarm(int notificationId) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(notificationId);
    } catch (e) {
      debugPrint('[NotificationService] Falha ao dispensar alarme: $e');
    }
    await _cancelOverlayAlarm(notificationId);
  }

  /// Reagenda o Alarme Principal de um medicamento para 10 minutos à frente
  /// (botão "Adiar 10 min" da AlarmScreen). É um alarme avulso, independente
  /// da série de ocorrências futuras já agendada.
  Future<void> snoozeAlarm({
    required int medId,
    required String nome,
    required String descricao,
  }) async {
    final int snoozeId = 600000000 + medId;
    final String corpoBase = descricao.trim().isNotEmpty
        ? '$nome - ${descricao.trim()}'
        : nome;

    tz.TZDateTime horaAlarme;
    try {
      horaAlarme = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
    } catch (e) {
      debugPrint(
        '[NotificationService] Falha ao calcular horário do adiamento: $e',
      );
      return;
    }

    await ensureExactAlarmPermission();

    await _zonedScheduleComProtecao(
      id: snoozeId,
      medId: medId,
      title: 'SeniCare: Hora do Remédio!',
      body: 'Está na hora de tomar $corpoBase',
      scheduledDate: horaAlarme,
      payload: 'alarm:$medId:$snoozeId',
      comTelaCheia: true,
      descricaoLog: 'Alarme adiado (snooze)',
    );
  }

  // ID fixo e fora da faixa usada pelos alarmes reais (medId*1000 nunca chega
  // perto disso), para o botão de teste nunca colidir com um alarme real.
  static const int _testAlarmId = 999999999;

  /// "Botão de Pânico": ignora toda a matemática de medicamentos e agenda o
  /// Alarme Principal puro para 5 segundos no futuro, forçando a solicitação
  /// da permissão de alarme exato antes. Usado pelo botão de teste em Ajustes
  /// para validar rapidamente se o motor de alarmes (tela cheia + som
  /// contínuo) está funcionando no aparelho/emulador.
  Future<void> scheduleTestAlarm() async {
    await ensureNotificationPermission();
    await ensureExactAlarmPermission();

    tz.TZDateTime horaDisparo;
    try {
      horaDisparo = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    } catch (e) {
      debugPrint(
        '[NotificationService] Falha ao calcular horário do teste: $e',
      );
      return;
    }

    await _zonedScheduleComProtecao(
      id: _testAlarmId,
      // medId 0 não existe no banco: getOverlayLaunchInfo/AlarmScreen já
      // tratam esse caso, exibindo o título genérico 'Medicamento'.
      medId: 0,
      title: 'SeniCare: Teste de Alarme',
      body:
          'Se isto apareceu em tela cheia, o motor de alarmes está funcionando!',
      scheduledDate: horaDisparo,
      // medId 0 não existe no banco: a AlarmScreen já trata esse caso,
      // exibindo o título genérico 'Medicamento' em vez de travar.
      payload: 'alarm:0:$_testAlarmId',
      comTelaCheia: true,
      descricaoLog: 'Alarme de teste',
    );
  }

  /// Agenda um lembrete para comprar mais medicamento.
  Future<void> scheduleStockAlert(Map<String, dynamic> medicamento) async {
    final prefs = await SharedPreferences.getInstance();
    final bool lembretesAtivos =
        prefs.getBool(AppPreferenceKeys.restockEnabled) ??
        AppPreferenceDefaults.restockEnabled;

    // O ID é essencial para agendar e cancelar notificações.
    if (medicamento['id'] == null) return;

    final int medId = medicamento['id'];
    final int notificationId = medId + 1000; // ID único para alertas de estoque

    // Sempre cancela qualquer alerta anterior para este medicamento.
    // Isso garante que, se o usuário desativar os lembretes, o alerta agendado seja removido.
    await flutterLocalNotificationsPlugin.cancel(notificationId);

    // Se a preferência do usuário for não notificar, apenas paramos.
    if (!lembretesAtivos) {
      return;
    }

    final int? totalQuantity = medicamento['quantidade_total'];
    final int? dosesPerDay = medicamento['doses_por_dia'];
    final int reminderDays = medicamento['dias_antecedencia'] ?? 3;
    final String medName = medicamento['nome'];

    // Se a informação de estoque for inválida, apenas cancelamos o alerta e paramos.
    if (totalQuantity == null || dosesPerDay == null || dosesPerDay <= 0) {
      return;
    }

    // Calcula a duração da caixa em dias.
    final int durationInDays = (totalQuantity / dosesPerDay).floor();

    final DateTime now = DateTime.now();
    final DateTime notificationDate = now
        .add(Duration(days: durationInDays))
        .subtract(Duration(days: reminderDays));

    // Não agenda alertas para datas no passado.
    if (notificationDate.isBefore(now)) {
      return;
    }

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        _stockChannelId,
        'Lembretes de Estoque',
        channelDescription: 'Canal para lembretes de compra de medicamentos',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'SeniCare: Hora de Comprar!',
        'Seu $medName está acabando. Compre uma nova caixa para não interromper o tratamento.',
        tz.TZDateTime.from(notificationDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Falha ao agendar alerta de estoque: $e',
      );
    }
  }
}
