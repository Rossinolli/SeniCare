// Cuida de todos os avisos de remédio: agenda o lembrete antecipado, o
// alarme na hora certa e o aviso de estoque, trata os botões "Tomei" e
// "Adiar" da própria notificação e verifica as permissões do Android.
//
// Modelo de agendamento: RECONCILIAÇÃO. [sincronizarAlarmes] calcula o
// conjunto completo de avisos que DEVERIAM existir (a partir do banco e das
// preferências), compara com o que o sistema tem pendente e só cancela/agenda
// a diferença. É idempotente — pode rodar sempre que algo muda, ao abrir o
// app e periodicamente em segundo plano (WorkManager) — e mantém uma janela
// deslizante de alarmes futuros, então a série nunca "acaba".

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show DartPluginRegistrant, IsolateNameServer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/preferencias.dart';
import '../data/repositorio.dart';
import '../domain/dose_schedule.dart';
import '../domain/medicamento.dart';

/// Pedido para abrir a tela de alarme de uma dose.
class AlarmLaunchInfo {
  final int medicamentoId;
  final int notificationId;

  /// Horário agendado da dose a que o alarme se refere.
  final DateTime? horarioDose;

  const AlarmLaunchInfo({
    required this.medicamentoId,
    required this.notificationId,
    this.horarioDose,
  });
}

/// Estado das permissões/configurações do Android que decidem se o alarme
/// realmente toca. Mostrado em Ajustes > Saúde do alarme.
class AlarmHealth {
  final bool notificacoes;
  final bool alarmesExatos;
  final bool telaCheia;
  final bool sobreporApps;
  final bool semOtimizacaoDeBateria;

  const AlarmHealth({
    required this.notificacoes,
    required this.alarmesExatos,
    required this.telaCheia,
    required this.sobreporApps,
    required this.semOtimizacaoDeBateria,
  });

  /// Sem estas duas o alarme simplesmente não toca (ou toca atrasado).
  bool get essenciaisOk => notificacoes && alarmesExatos;

  bool get tudoOk =>
      essenciaisOk && telaCheia && sobreporApps && semOtimizacaoDeBateria;

  static const AlarmHealth desconhecido = AlarmHealth(
    notificacoes: true,
    alarmesExatos: true,
    telaCheia: true,
    sobreporApps: true,
    semOtimizacaoDeBateria: true,
  );
}

/// Toque num botão da notificação ("Tomei"/"Adiar") com o app fechado ou em
/// segundo plano. O plugin roda isto num motor Flutter próprio, sem tela;
/// precisa ser top-level e marcado como entry-point para sobreviver ao
/// tree-shaking do modo Release.
@pragma('vm:entry-point')
Future<void> notificationTapBackgroundHandler(NotificationResponse r) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await NotificationService().init(emSegundoPlano: true);
  await NotificationService().tratarAcaoDaNotificacao(r);
}

void _log(String mensagem) {
  // Só em debug: os logs citam nomes de remédios (dado de saúde).
  if (kDebugMode) debugPrint('[Notificações] $mensagem');
}

/// Um aviso que deveria estar agendado, calculado pela reconciliação.
class _AvisoDesejado {
  final int id;
  final String titulo;
  final String corpo;
  final tz.TZDateTime quando;
  final String payload;
  final NotificationDetails detalhes;
  final bool telaCheia;
  final int medId;

  const _AvisoDesejado({
    required this.id,
    required this.titulo,
    required this.corpo,
    required this.quando,
    required this.payload,
    required this.detalhes,
    required this.telaCheia,
    required this.medId,
  });
}

class NotificationService {
  static final NotificationService _instancia = NotificationService._();

  factory NotificationService() => _instancia;

  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _iniciado = false;

  /// Pedidos de abertura da tela de alarme. A interface (MainShell) escuta
  /// e abre a AlarmScreen; o serviço não conhece widgets.
  final ValueNotifier<AlarmLaunchInfo?> alarmePendente = ValueNotifier(null);

  /// Canal nativo (MainActivity.kt). Só existe no motor da Activity: nos
  /// motores de segundo plano as chamadas lançam MissingPluginException e o
  /// serviço segue sem o alarme de overlay (a notificação continua).
  static const MethodChannel _nativo = MethodChannel('senicare/overlay_alarm');

  /// Nome da porta pela qual a interface (motor principal) recebe avisos
  /// de mudança vindos dos motores de segundo plano — os dois rodam no mesmo
  /// processo, então compartilham o IsolateNameServer.
  static const String portaDaInterface = 'senicare.interface';

  /// Avisa a interface aberta (se houver) que os dados mudaram.
  static void avisarInterface() {
    final SendPort? porta = IsolateNameServer.lookupPortByName(
      portaDaInterface,
    );
    porta?.send('atualizar');
  }

  static const String acaoTomei = 'tomei';
  static const String acaoAdiar = 'adiar';
  static const Duration duracaoAdiamento = Duration(minutes: 10);
  static const Duration _antecedenciaLembrete = Duration(minutes: 30);

  // Canais: no Android 8+ som e vibração pertencem ao CANAL, então há um
  // canal por combinação dos interruptores "Som" / "Vibração" dos Ajustes.
  static const String _canalLembrete = 'medication_reminder_channel';
  static const String _canalEstoque = 'stock_channel_id';

  static String _canalAlarme({required bool som, required bool vibra}) =>
      'senicare_alarme_v2_${som ? 's' : 'x'}${vibra ? 'v' : 'x'}';

  static String _nomeCanalAlarme({required bool som, required bool vibra}) {
    if (som && vibra) return 'Alarmes de Medicamento';
    if (som) return 'Alarmes de Medicamento (sem vibração)';
    if (vibra) return 'Alarmes de Medicamento (só vibração)';
    return 'Alarmes de Medicamento (silencioso)';
  }

  // Toque de ALARME do sistema (não o de notificação).
  static const UriAndroidNotificationSound _somDeAlarme =
      UriAndroidNotificationSound('content://settings/system/alarm_alert');

  // Janela deslizante e orçamento. Android: 500 alarmes pendentes por app no
  // AlarmManager (cada ocorrência gasta até 3: lembrete + alarme +
  // overlay). iOS: no máximo 64 notificações pendentes por app.
  static const Duration _janela = Duration(days: 28);
  static int get _orcamento => Platform.isIOS ? 60 : 300;
  static const int _maxOcorrenciasPorMed = 24;

  // Faixas de ID separadas por tipo, sem colisão possível:
  //   estoque = 1000 + medId
  //   adiar = 600.000.000 + medId | lembrete/alarme = hash em [1e9, 2,1e9)
  static int _idEstoque(int medId) => 1000 + medId;
  static int _idAdiamento(int medId) => 600000000 + medId;

  // ---------------------------------------------------------------------
  // Inicialização
  // ---------------------------------------------------------------------

  /// Inicializa fuso horário, plugin e canais. Não pede permissão nenhuma:
  /// roda antes do runApp (inclusive quando o app é aberto por um alarme) e
  /// em motores de segundo plano — ver [solicitarPermissoesIniciais].
  Future<void> init({bool emSegundoPlano = false}) async {
    if (_iniciado) return;
    await _configurarFusoHorario();
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _aoTocarNotificacao,
        onDidReceiveBackgroundNotificationResponse:
            notificationTapBackgroundHandler,
      );
    } catch (e) {
      _log('Falha ao inicializar plugin: $e');
    }
    if (!emSegundoPlano) await _criarCanais();
    _iniciado = true;
  }

  /// Fuso IANA real do aparelho (ex.: 'America/Sao_Paulo'), com recurso ao
  /// offset atual se o plugin falhar. Nunca impede o app de abrir.
  Future<void> _configurarFusoHorario() async {
    try {
      tzdata.initializeTimeZones();
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      _log('Fuso horário indisponível, usando o offset do aparelho: $e');
      try {
        final Duration offset = DateTime.now().timeZoneOffset;
        final String nome = tz.timeZoneDatabase.locations.keys.firstWhere(
          (n) => tz.TZDateTime.now(tz.getLocation(n)).timeZoneOffset == offset,
          orElse: () => 'UTC',
        );
        tz.setLocalLocation(tz.getLocation(nome));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _criarCanais() async {
    final android = _android;
    if (android == null) return;
    try {
      for (final som in [true, false]) {
        for (final vibra in [true, false]) {
          await android.createNotificationChannel(
            AndroidNotificationChannel(
              _canalAlarme(som: som, vibra: vibra),
              _nomeCanalAlarme(som: som, vibra: vibra),
              description: 'Alarme principal, na hora exata de tomar o remédio',
              importance: Importance.max,
              playSound: som,
              sound: som ? _somDeAlarme : null,
              enableVibration: vibra,
              enableLights: true,
              audioAttributesUsage: AudioAttributesUsage.alarm,
            ),
          );
        }
      }
      // Canal da versão 1 (usava o áudio de NOTIFICAÇÃO, silenciado junto
      // com o volume de notificações) — canais não podem ser alterados.
      await android.deleteNotificationChannel(
        channelId: 'medication_alarm_channel',
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _canalLembrete,
          'Lembretes Prévios',
          description: 'Aviso 30 minutos antes do horário do remédio',
          importance: Importance.high,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _canalEstoque,
          'Lembretes de Estoque',
          description: 'Aviso para comprar mais remédio antes de acabar',
          importance: Importance.high,
        ),
      );
    } catch (e) {
      _log('Falha ao criar canais: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Permissões
  // ---------------------------------------------------------------------

  /// Chamado depois do primeiro frame, numa abertura normal do app (nunca
  /// por cima de um alarme). Só pede o que ainda falta.
  Future<void> solicitarPermissoesIniciais() async {
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return;
    }
    final android = _android;
    if (android == null) return;
    try {
      await android.requestNotificationsPermission();
      if (await android.canScheduleExactNotifications() == false) {
        await android.requestExactAlarmsPermission();
      }
    } catch (e) {
      _log('Falha ao pedir permissões: $e');
    }
  }

  Future<AlarmHealth> verificarSaudeDoAlarme() async {
    try {
      final Map<String, dynamic>? r = await _nativo
          .invokeMapMethod<String, dynamic>('getAlarmHealth');
      if (r == null) return AlarmHealth.desconhecido;
      bool b(String k) => r[k] as bool? ?? true;
      return AlarmHealth(
        notificacoes: b('notifications'),
        alarmesExatos: b('exactAlarms'),
        telaCheia: b('fullScreen'),
        sobreporApps: b('overlay'),
        semOtimizacaoDeBateria: b('batteryUnrestricted'),
      );
    } catch (e) {
      return AlarmHealth.desconhecido;
    }
  }

  /// Abre a tela do sistema da permissão [tipo]: 'notifications',
  /// 'exactAlarms', 'fullScreen', 'overlay' ou 'batteryUnrestricted'.
  Future<void> abrirConfiguracaoDePermissao(String tipo) async {
    if (tipo == 'notifications') {
      // Primeiro o pop-up comum; se já foi negado antes, o Android não o
      // mostra mais, então cai na tela de ajustes do app.
      bool? concedida;
      try {
        concedida = await _android?.requestNotificationsPermission();
      } catch (_) {}
      if (concedida == true) return;
    }
    try {
      await _nativo.invokeMethod('openPermissionSettings', {'kind': tipo});
    } catch (e) {
      _log('Falha ao abrir configuração "$tipo": $e');
    }
  }

  /// null = não dá para saber neste motor (segundo plano).
  Future<bool?> _temPermissaoDeOverlay() async {
    try {
      return await _nativo.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return false;
    }
  }

  /// Liga/desliga a exibição do app sobre a tela de bloqueio — só ligada
  /// enquanto uma AlarmScreen está aberta (privacidade dos dados de saúde).
  Future<void> exibirSobreTelaDeBloqueio(bool exibir) async {
    try {
      await _nativo.invokeMethod('setShowOnLockScreen', {'show': exibir});
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Abertura da tela de alarme
  // ---------------------------------------------------------------------

  /// App aberto do zero (processo morto) por um alarme: overlay nativo ou
  /// toque/tela cheia da notificação.
  Future<AlarmLaunchInfo?> alarmeQueAbriuOApp() async {
    try {
      final Map<String, dynamic>? r = await _nativo
          .invokeMapMethod<String, dynamic>('consumePendingLaunch');
      final int? medId = r?['medId'] as int?;
      final int? notificationId = r?['notificationId'] as int?;
      if (medId != null && notificationId != null) {
        return AlarmLaunchInfo(
          medicamentoId: medId,
          notificationId: notificationId,
          horarioDose: await horarioDaDose(notificationId),
        );
      }
    } catch (e) {
      _log('Falha ao ler lançamento por overlay: $e');
    }
    try {
      final NotificationAppLaunchDetails? detalhes = await _plugin
          .getNotificationAppLaunchDetails();
      if (detalhes == null || !detalhes.didNotificationLaunchApp) return null;
      return _alarmeDoPayload(detalhes.notificationResponse?.payload);
    } catch (e) {
      _log('Falha ao ler detalhes de lançamento: $e');
      return null;
    }
  }

  /// Lançamentos por overlay com o app já em execução (onNewIntent nativo).
  void escutarAlarmesDeOverlay() {
    _nativo.setMethodCallHandler((call) async {
      if (call.method != 'onOverlayAlarm') return;
      final Map<dynamic, dynamic> args = call.arguments as Map;
      final int? medId = args['medId'] as int?;
      final int? notificationId = args['notificationId'] as int?;
      if (medId == null || notificationId == null) return;
      alarmePendente.value = AlarmLaunchInfo(
        medicamentoId: medId,
        notificationId: notificationId,
        horarioDose: await horarioDaDose(notificationId),
      );
    });
  }

  void _aoTocarNotificacao(NotificationResponse r) {
    if (r.actionId != null) {
      // Ações sem interface chegam pelo motor de segundo plano; esta via só
      // é usada se o sistema entregar a ação ao app aberto.
      tratarAcaoDaNotificacao(r);
      return;
    }
    final AlarmLaunchInfo? info = _alarmeDoPayload(r.payload);
    if (info != null) alarmePendente.value = info;
  }

  /// Payload: 'tipo:medId:notificationId[:assinatura[:horarioDoseMs]]'.
  /// Só 'alarm' e 'snooze' abrem a AlarmScreen.
  AlarmLaunchInfo? _alarmeDoPayload(String? payload) {
    final _Payload? p = _Payload.ler(payload);
    if (p == null || !const {'alarm', 'snooze'}.contains(p.tipo)) {
      return null;
    }
    return AlarmLaunchInfo(
      medicamentoId: p.medId,
      notificationId: p.notificationId,
      horarioDose: p.dose,
    );
  }

  // ---------------------------------------------------------------------
  // Botões "Tomei" / "Adiar" da notificação
  // ---------------------------------------------------------------------

  Future<void> tratarAcaoDaNotificacao(NotificationResponse r) async {
    final _Payload? p = _Payload.ler(r.payload);
    if (p == null || r.actionId == null) return;
    await _cancelarOverlay(p.notificationId);
    final Medicamento? med = await Repositorio.instance.porId(p.medId);
    if (med == null) return;
    if (r.actionId == acaoTomei) {
      await Repositorio.instance.registrarResposta(
        med,
        tomado: true,
        horarioDose: p.dose,
      );
      _log('Dose registrada pela notificação: ${med.nome}');
      avisarInterface();
    } else if (r.actionId == acaoAdiar) {
      await adiar(med, horarioDose: p.dose);
    }
  }

  // ---------------------------------------------------------------------
  // Reconciliação (agendamento)
  // ---------------------------------------------------------------------

  /// Hash FNV-1a de 32 bits: estável entre execuções (Object.hash tem
  /// semente aleatória por processo — o mesmo alarme mudaria de ID).
  static int _hashEstavel(String texto) {
    int hash = 0x811c9dc5;
    for (final int unidade in texto.codeUnits) {
      hash ^= unidade;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static int _idOcorrencia(String tipo, int medId, DateTime instante) {
    final int segundos = instante.millisecondsSinceEpoch ~/ 1000;
    return 1000000000 + _hashEstavel('$tipo:$medId:$segundos') % 1100000000;
  }

  Future<void>? _emAndamento;
  bool _repetir = false;

  /// Deixa os avisos agendados exatamente de acordo com o banco e as
  /// preferências. Chamadas concorrentes são agrupadas: se uma chegar
  /// durante uma sincronização, roda mais uma rodada no fim.
  Future<void> sincronizarAlarmes() {
    if (_emAndamento != null) {
      _repetir = true;
      return _emAndamento!;
    }
    return _emAndamento = _executarSincronizacoes();
  }

  Future<void> _executarSincronizacoes() async {
    try {
      do {
        _repetir = false;
        await _sincronizarUmaVez();
      } while (_repetir);
    } catch (e, st) {
      _log('Falha na sincronização: $e\n$st');
    } finally {
      _emAndamento = null;
    }
  }

  Future<void> _sincronizarUmaVez() async {
    final Preferencias prefs = await Preferencias.lerAtualizado();
    final ModoAviso modo = prefs.modoAviso;
    // null = motor de segundo plano: não dá para consultar nem mexer no
    // overlay; os existentes ficam como estão.
    final bool? overlay = modo.telaCheia
        ? await _temPermissaoDeOverlay()
        : false;

    final List<Medicamento> meds = await Repositorio.instance.ativos();
    final Set<int> idsAtivos = {for (final m in meds) m.id};

    final int porOcorrencia =
        1 + (modo.lembretePrevio ? 1 : 0) + (overlay != false ? 1 : 0);
    final int limitePorMed = meds.isEmpty
        ? 0
        : (_orcamento ~/ (meds.length * porOcorrencia)).clamp(
            1,
            _maxOcorrenciasPorMed,
          );

    final DateTime agora = DateTime.now();
    // Doses já respondidas (ex.: "Tomei" antes da hora): não tocam mais.
    final DateTime hoje = inicioDoDia(agora);
    final Set<String> respondidas = {
      for (final r in await Repositorio.instance.registrosEntre(
        hoje.subtract(const Duration(days: 1)),
        hoje.add(const Duration(days: 2)),
      ))
        if (r.horarioDose != null)
          '${r.medicamentoId}|${r.horarioDose!.millisecondsSinceEpoch}',
    };
    final Map<int, _AvisoDesejado> desejados = {};
    for (final Medicamento med in meds) {
      // A assinatura entra no payload: se nome, dose, modo de aviso ou
      // som/vibração mudarem, o payload muda e o aviso é reagendado.
      final int assinatura = _hashEstavel(
        '${med.nome}|${med.textoDose}|${modo.valor}|${prefs.somAlarme}|${prefs.vibracaoAlarme}',
      );
      final String complemento = med.textoDose == null
          ? ''
          : ' (${med.textoDose})';

      for (final DateTime dose in DoseSchedule.proximasDoses(
        med,
        agora,
        janela: _janela,
        limite: limitePorMed,
      )) {
        if (respondidas.contains('${med.id}|${dose.millisecondsSinceEpoch}')) {
          continue;
        }
        final int idAlarme = _idOcorrencia('alarm', med.id, dose);
        desejados[idAlarme] = _AvisoDesejado(
          id: idAlarme,
          medId: med.id,
          titulo: 'Hora do remédio: ${med.nome}',
          corpo: 'Tome agora$complemento.',
          quando: tz.TZDateTime.from(dose, tz.local),
          payload:
              'alarm:${med.id}:$idAlarme:$assinatura:${dose.millisecondsSinceEpoch}',
          detalhes: _detalhesDoAlarme(prefs, comAcoes: true),
          telaCheia: modo.telaCheia,
        );

        final DateTime lembrete = dose.subtract(_antecedenciaLembrete);
        if (modo.lembretePrevio && lembrete.isAfter(agora)) {
          final int idLembrete = _idOcorrencia('reminder', med.id, lembrete);
          desejados[idLembrete] = _AvisoDesejado(
            id: idLembrete,
            medId: med.id,
            titulo: 'Daqui a 30 minutos: ${med.nome}',
            corpo:
                'Às ${HoraDoDia(dose.hour, dose.minute)} você toma ${med.nome}$complemento.',
            quando: tz.TZDateTime.from(lembrete, tz.local),
            payload: 'reminder:${med.id}:$idLembrete:$assinatura',
            detalhes: _detalhesDoLembrete,
            telaCheia: false,
          );
        }
      }

      if (prefs.estoqueAtivo) {
        final _AvisoDesejado? estoque = _avisoDeEstoque(med, agora);
        if (estoque != null) desejados[estoque.id] = estoque;
      }
    }

    // --- Diferença entre o desejado e o que está pendente ---
    final List<PendingNotificationRequest> pendentes = await _plugin
        .pendingNotificationRequests();
    final Set<int> mantidos = {};
    int cancelados = 0;
    for (final p in pendentes) {
      final _Payload? info = _Payload.ler(p.payload);
      if (info?.tipo == 'snooze') {
        // Avulsos: só somem se o remédio foi removido.
        if (!idsAtivos.contains(info!.medId)) {
          await _cancelar(p.id, overlay: overlay != null);
          cancelados++;
        }
        continue;
      }
      final _AvisoDesejado? desejado = desejados[p.id];
      if (desejado != null && desejado.payload == p.payload) {
        mantidos.add(p.id);
      } else {
        await _cancelar(p.id, overlay: overlay != null);
        cancelados++;
      }
    }

    int agendados = 0;
    for (final aviso in desejados.values) {
      if (mantidos.contains(aviso.id)) {
        // O alarme de overlay se perde num reboot; reagendar é idempotente.
        if (aviso.telaCheia && overlay != null) {
          await _overlay(aviso, ativo: overlay);
        }
        continue;
      }
      await _agendar(aviso, overlay: overlay);
      agendados++;
    }
    _log(
      'Sincronização: ${desejados.length} desejados, $agendados agendados, '
      '$cancelados cancelados, ${mantidos.length} mantidos '
      '(limite/remédio: $limitePorMed, overlay: $overlay)',
    );
  }

  _AvisoDesejado? _avisoDeEstoque(Medicamento med, DateTime agora) {
    final int? quantidade = med.quantidadeTotal;
    final double porDia =
        DoseSchedule.dosesPorDiaMedia(med) * (med.quantidadePorDose ?? 1);
    if (quantidade == null || quantidade <= 0 || porDia <= 0) return null;
    final DateTime? desde = med.estoqueDesde ?? med.dataInicio;
    if (desde == null) return null;

    final int duracaoDias = (quantidade / porDia).floor();
    // Às 9h do dia do aviso — nunca de madrugada.
    final DateTime quando = DateTime(
      desde.year,
      desde.month,
      desde.day + duracaoDias - med.diasAntecedencia,
      9,
    );
    if (!quando.isAfter(agora)) return null;
    final int id = _idEstoque(med.id);
    return _AvisoDesejado(
      id: id,
      medId: med.id,
      titulo: 'Hora de comprar: ${med.nome}',
      corpo:
          'Seu ${med.nome} está acabando. Compre uma nova caixa para não interromper o tratamento.',
      quando: tz.TZDateTime.from(quando, tz.local),
      payload:
          'stock:${med.id}:$id:${_hashEstavel('${med.nome}|${quando.toIso8601String()}')}',
      detalhes: const NotificationDetails(
        android: AndroidNotificationDetails(
          _canalEstoque,
          'Lembretes de Estoque',
          channelDescription: 'Aviso para comprar mais remédio antes de acabar',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      telaCheia: false,
    );
  }

  static const NotificationDetails _detalhesDoLembrete = NotificationDetails(
    android: AndroidNotificationDetails(
      _canalLembrete,
      'Lembretes Prévios',
      channelDescription: 'Aviso 30 minutos antes do horário do remédio',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Alarme principal: tela cheia + som em loop (FLAG_INSISTENT) no modo
  /// com alarmes; notificação de alta prioridade no modo só notificações.
  /// [comAcoes]: botões "Tomei" e "Adiar 10 min" na própria notificação —
  /// o idoso responde sem precisar abrir o app.
  NotificationDetails _detalhesDoAlarme(
    Preferencias prefs, {
    required bool comAcoes,
  }) {
    final bool telaCheia = prefs.modoAviso.telaCheia;
    final bool som = prefs.somAlarme;
    final bool vibra = prefs.vibracaoAlarme;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _canalAlarme(som: som, vibra: vibra),
        _nomeCanalAlarme(som: som, vibra: vibra),
        channelDescription:
            'Alarme principal, na hora exata de tomar o remédio',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: telaCheia,
        category: telaCheia
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: som,
        sound: som ? _somDeAlarme : null,
        enableVibration: vibra,
        ongoing: telaCheia,
        autoCancel: !telaCheia,
        additionalFlags: telaCheia ? Int32List.fromList(<int>[4]) : null,
        actions: comAcoes
            ? const [
                AndroidNotificationAction(
                  acaoTomei,
                  'Tomei',
                  cancelNotification: true,
                ),
                AndroidNotificationAction(
                  acaoAdiar,
                  'Adiar 10 min',
                  cancelNotification: true,
                ),
              ]
            : null,
      ),
      iOS: const DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  Future<void> _cancelar(int id, {bool overlay = true}) async {
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      _log('Falha ao cancelar id=$id: $e');
    }
    if (overlay) await _cancelarOverlay(id);
  }

  /// Agenda com proteção: se falhar com tela cheia (ex.: SecurityException
  /// sem USE_FULL_SCREEN_INTENT no Android 14+), tenta de novo sem ela.
  Future<void> _agendar(_AvisoDesejado aviso, {required bool? overlay}) async {
    if (aviso.telaCheia && overlay != null) {
      await _overlay(aviso, ativo: overlay);
    }
    try {
      await _plugin.zonedSchedule(
        id: aviso.id,
        title: aviso.titulo,
        body: aviso.corpo,
        scheduledDate: aviso.quando,
        notificationDetails: aviso.detalhes,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: aviso.payload,
      );
    } catch (e) {
      _log('Falha ao agendar id=${aviso.id}: $e');
      if (!aviso.telaCheia) return;
      try {
        final Preferencias prefs = await Preferencias.lerAtualizado();
        await _plugin.zonedSchedule(
          id: aviso.id,
          title: aviso.titulo,
          body: aviso.corpo,
          scheduledDate: aviso.quando,
          notificationDetails: _detalhesDoAlarme(
            prefs.copyWith(modoAviso: ModoAviso.apenasNotificacoes),
            comAcoes: true,
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: aviso.payload,
        );
      } catch (e2) {
        _log('Falha TOTAL ao agendar id=${aviso.id}: $e2');
      }
    }
  }

  /// Alarme nativo que abre o app por cima de qualquer outro (só com a
  /// permissão "Exibir sobre outros apps").
  Future<void> _overlay(_AvisoDesejado aviso, {required bool ativo}) async {
    if (!ativo) {
      await _cancelarOverlay(aviso.id);
      return;
    }
    try {
      await _nativo.invokeMethod('scheduleOverlayAlarm', {
        'medId': aviso.medId,
        'notificationId': aviso.id,
        'triggerAtMillis': aviso.quando.millisecondsSinceEpoch,
      });
    } catch (e) {
      _log('Falha ao agendar overlay: $e');
    }
  }

  Future<void> _cancelarOverlay(int notificationId) async {
    try {
      await _nativo.invokeMethod('cancelOverlayAlarm', {
        'notificationId': notificationId,
      });
    } catch (_) {
      // Motor sem Activity ou alarme inexistente: nada a fazer.
    }
  }

  // ---------------------------------------------------------------------
  // Ações da AlarmScreen
  // ---------------------------------------------------------------------

  /// Dispensa uma ocorrência (sem afetar as próximas).
  Future<void> dispensar(int notificationId) => _cancelar(notificationId);

  /// A dose de [medId] das [horario] foi respondida fora do alarme (na Home
  /// ou pelos botões): some com o alarme dela, se estiver na barra, e com
  /// um adiamento pendente da mesma dose; a reconciliação remove os avisos
  /// futuros dela (lembrete/alarme que ainda não tocaram).
  Future<void> dispensarAlarmeDaDose(int medId, DateTime horario) async {
    await _cancelar(_idOcorrencia('alarm', medId, horario));
    final int idAdiamento = _idAdiamento(medId);
    try {
      final List<String?> payloads = [
        for (final n in await _plugin.getActiveNotifications())
          if (n.id == idAdiamento) n.payload,
        for (final p in await _plugin.pendingNotificationRequests())
          if (p.id == idAdiamento) p.payload,
      ];
      if (payloads.any(
        (p) => _Payload.ler(p)?.dose?.isAtSameMomentAs(horario) ?? false,
      )) {
        await _cancelar(idAdiamento);
      }
    } catch (_) {}
    await sincronizarAlarmes();
  }

  /// A notificação [notificationId] ainda está na barra? (A AlarmScreen
  /// fecha sozinha se a dose foi respondida pelos botões da notificação.)
  Future<bool> notificacaoAtiva(int notificationId) async {
    try {
      final List<ActiveNotification> ativas = await _plugin
          .getActiveNotifications();
      return ativas.any((n) => n.id == notificationId);
    } catch (_) {
      return true;
    }
  }

  /// Horário da dose do alarme [notificationId], lido do payload da
  /// notificação que está tocando.
  Future<DateTime?> horarioDaDose(int notificationId) async {
    try {
      for (final n in await _plugin.getActiveNotifications()) {
        if (n.id == notificationId) return _Payload.ler(n.payload)?.dose;
      }
    } catch (_) {}
    return null;
  }

  /// Toca de novo daqui a 10 minutos — alarme avulso que carrega o horário
  /// da dose original (para a resposta cair na dose certa).
  Future<void> adiar(Medicamento med, {DateTime? horarioDose}) async {
    final Preferencias prefs = await Preferencias.lerAtualizado();
    final int id = _idAdiamento(med.id);
    await _cancelar(id);
    final String complemento = med.textoDose == null
        ? ''
        : ' (${med.textoDose})';
    await _agendar(
      _AvisoDesejado(
        id: id,
        medId: med.id,
        titulo: 'Hora do remédio: ${med.nome}',
        corpo: 'Lembrete adiado — tome agora$complemento.',
        quando: tz.TZDateTime.now(tz.local).add(duracaoAdiamento),
        payload:
            'snooze:${med.id}:$id:0:${horarioDose?.millisecondsSinceEpoch ?? ''}',
        detalhes: _detalhesDoAlarme(prefs, comAcoes: true),
        telaCheia: prefs.modoAviso.telaCheia,
      ),
      overlay: prefs.modoAviso.telaCheia
          ? await _temPermissaoDeOverlay()
          : false,
    );
  }
}

class _Payload {
  final String tipo;
  final int medId;
  final int notificationId;
  final DateTime? dose;

  const _Payload(this.tipo, this.medId, this.notificationId, this.dose);

  static _Payload? ler(String? payload) {
    if (payload == null) return null;
    final List<String> partes = payload.split(':');
    if (partes.length < 3) return null;
    final int? medId = int.tryParse(partes[1]);
    final int? notificationId = int.tryParse(partes[2]);
    if (medId == null || notificationId == null) return null;
    final int? ms = partes.length > 4 ? int.tryParse(partes[4]) : null;
    return _Payload(
      partes[0],
      medId,
      notificationId,
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }
}
