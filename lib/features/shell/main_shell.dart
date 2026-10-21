// Estrutura principal: as quatro abas (Início, Remédios, Histórico, Ajustes)
// e tudo que acontece "por trás" delas — abrir a tela de alarme, pedir
// permissões na primeira abertura e manter os alarmes sincronizados.

import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/componentes.dart';
import '../../core/estado.dart';
import '../../core/tema.dart';
import '../../data/database.dart';
import '../../services/miui_permission_helper.dart';
import '../../services/notification_service.dart';
import '../ajustes/ajustes_screen.dart';
import '../alarme/alarm_screen.dart';
import '../app.dart';
import '../historico/historico_screen.dart';
import '../inicio/inicio_screen.dart';
import '../remedios/remedios_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _aba = 0;
  DateTime? _ultimaSincronizacao;

  // Ocorrências com AlarmScreen aberta: o overlay nativo e a notificação de
  // tela cheia disparam juntos — sem isto, abririam duas telas iguais.
  final Set<int> _alarmesAbertos = {};

  final NotificationService _notificacoes = NotificationService();

  /// Recebe "atualizar" do motor de segundo plano (botões da notificação).
  final ReceivePort _porta = ReceivePort();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificacoes.escutarAlarmesDeOverlay();
    _notificacoes.alarmePendente.addListener(_abrirAlarmePendente);
    IsolateNameServer.removePortNameMapping(
      NotificationService.portaDaInterface,
    );
    IsolateNameServer.registerPortWithName(
      _porta.sendPort,
      NotificationService.portaDaInterface,
    );
    _porta.listen((_) => AppDatabase.instance.recarregarTelas());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _sincronizar();
      // Prepara o catálogo de medicamentos em segundo plano: quando o
      // cadastro abrir, o autocompletar já está pronto.
      unawaited(ref.read(catalogoProvider.future));
      if (_notificacoes.alarmePendente.value != null) {
        _abrirAlarmePendente();
        return;
      }
      // Abertura normal (não por alarme): hora de pedir permissões —
      // nunca antes do runApp, nunca por cima de um alarme tocando.
      await MiuiPermissionHelper.mostrarAvisoSeNecessario(context);
      await _notificacoes.solicitarPermissoesIniciais();
      if (mounted) ref.invalidate(saudeDoAlarmeProvider);
    });
  }

  @override
  void dispose() {
    _notificacoes.alarmePendente.removeListener(_abrirAlarmePendente);
    IsolateNameServer.removePortNameMapping(
      NotificationService.portaDaInterface,
    );
    _porta.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Respostas dadas pelos botões da notificação são gravadas por outro
    // motor Flutter: recarrega as telas ao voltar.
    AppDatabase.instance.recarregarTelas();
    ref.invalidate(saudeDoAlarmeProvider);
    final DateTime? ultima = _ultimaSincronizacao;
    if (ultima == null ||
        DateTime.now().difference(ultima) > const Duration(minutes: 15)) {
      _sincronizar();
    }
  }

  void _sincronizar() {
    _ultimaSincronizacao = DateTime.now();
    unawaited(_notificacoes.sincronizarAlarmes());
  }

  Future<void> _abrirAlarmePendente() async {
    final AlarmLaunchInfo? info = _notificacoes.alarmePendente.value;
    if (info == null) return;
    _notificacoes.alarmePendente.value = null;
    final NavigatorState? nav = navegadorRaiz.currentState;
    if (nav == null || !_alarmesAbertos.add(info.notificationId)) return;
    try {
      await nav.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AlarmScreen(info: info),
        ),
      );
    } finally {
      _alarmesAbertos.remove(info.notificationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: c.barraDeStatus.copyWith(
        systemNavigationBarColor: c.barraNavegacao,
      ),
      child: Scaffold(
        body: FundoDoTema(
          child: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _aba,
              children: [
                InicioScreen(irParaRemedios: () => setState(() => _aba = 1)),
                const RemediosScreen(),
                const HistoricoScreen(),
                const AjustesScreen(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.borda)),
          ),
          child: NavigationBar(
            selectedIndex: _aba,
            onDestinationSelected: (i) => setState(() => _aba = i),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Início',
              ),
              NavigationDestination(
                icon: Icon(Icons.medication_outlined),
                selectedIcon: Icon(Icons.medication_rounded),
                label: 'Remédios',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: 'Histórico',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Ajustes',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
