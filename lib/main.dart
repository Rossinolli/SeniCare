// Arquivo principal do aplicativo.
// Mostra a tela de splash ou a Home, monta as três abas (Início,
// Histórico, Ajustes) e mostra a lista de remédios do dia na tela inicial.

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'database_helper.dart';
import 'add_medication_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'notification_service.dart';
import 'alarm_screen.dart';
import 'app_preferences.dart';
import 'glass_card.dart';
import 'miui_permission_helper.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.system,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização do serviço de notificações local
  await NotificationService().init();

  // Se o app foi aberto do zero (processo morto) por um alarme, guardamos
  // aqui para empilhar a AlarmScreen assim que a navegação inicial
  // (Splash -> MainNavigator) terminar. Tenta primeiro o lançamento por
  // overlay (abriu direto por cima de outro app, sem precisar de toque);
  // se não foi esse o caso, cai para o lançamento por toque na notificação.
  final AlarmLaunchInfo? launchAlarmInfo =
      await NotificationService().getOverlayLaunchInfo() ??
      await NotificationService().getLaunchAlarmInfo();

  // Carrega as preferências salvas antes de rodar o app. Chaves e defaults
  // centralizados em AppPreferenceKeys/AppPreferenceDefaults — nunca leia ou
  // escreva uma string literal de preferência direto por aqui.
  final prefs = await SharedPreferences.getInstance();
  final savedTheme =
      prefs.getString(AppPreferenceKeys.themeChoice) ??
      AppPreferenceDefaults.themeChoice;
  // Se a chave ainda não existir (primeiro acesso do usuário), o tamanho da
  // fonte SEMPRE começa no mínimo do slider (0.8 = 80%) — nunca em um valor
  // pré-ampliado. O clamp(0.8, 1.1) protege contra um valor salvo antes do
  // limite máximo ter sido reduzido de 1.3 para 1.1 (o Slider trava se
  // value > max).
  final savedFontSize =
      (prefs.getDouble(AppPreferenceKeys.fontSize) ??
              AppPreferenceDefaults.fontSize)
          .clamp(0.8, 1.1);
  final savedRestock =
      prefs.getBool(AppPreferenceKeys.restockEnabled) ??
      AppPreferenceDefaults.restockEnabled;
  final savedAlertMode =
      prefs.getString(AppPreferenceKeys.alertMode) ??
      AppPreferenceDefaults.alertMode;
  final savedAlarmSoundEnabled =
      prefs.getBool(AppPreferenceKeys.alarmSoundEnabled) ??
      AppPreferenceDefaults.alarmSoundEnabled;
  final savedAlarmVibrationEnabled =
      prefs.getBool(AppPreferenceKeys.alarmVibrationEnabled) ??
      AppPreferenceDefaults.alarmVibrationEnabled;
  // A tela 'SeniCare' só aparece na primeiríssima abertura do app na vida do
  // aparelho: a SplashScreen marca esta chave como true antes de navegar
  // para a Home, então toda vez depois disso o app pula direto pra Home.
  final hasSeenSplash =
      prefs.getBool(AppPreferenceKeys.hasSeenSplash) ??
      AppPreferenceDefaults.hasSeenSplash;

  // Sincroniza o Notifier com o valor salvo inicialmente
  themeModeNotifier.value = savedTheme == 'Dark'
      ? ThemeMode.dark
      : (savedTheme == 'Light' ? ThemeMode.light : ThemeMode.system);

  // Inicializa a formatação de datas para PT-BR
  await initializeDateFormatting('pt_BR', null);

  runApp(
    SeniCareApp(
      initialTheme: savedTheme,
      initialFontSize: savedFontSize,
      initialAlarmSoundEnabled: savedAlarmSoundEnabled,
      initialAlarmVibrationEnabled: savedAlarmVibrationEnabled,
      initialRestock: savedRestock,
      initialAlertMode: savedAlertMode,
      hasSeenSplash: hasSeenSplash,
      launchAlarmInfo: launchAlarmInfo,
    ),
  );
}

class SeniCareApp extends StatelessWidget {
  final String initialTheme;
  final double initialFontSize;
  final bool initialRestock;
  final String initialAlertMode;
  final bool initialAlarmSoundEnabled;
  final bool initialAlarmVibrationEnabled;
  final bool hasSeenSplash;
  final AlarmLaunchInfo? launchAlarmInfo;

  const SeniCareApp({
    super.key,
    required this.initialTheme,
    required this.initialFontSize,
    required this.initialAlarmSoundEnabled,
    required this.initialAlarmVibrationEnabled,
    required this.initialRestock,
    required this.initialAlertMode,
    required this.hasSeenSplash,
    this.launchAlarmInfo,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'SeniCare',
          // Permite que o NotificationService navegue para a AlarmScreen a
          // partir de qualquer lugar (ex.: toque na notificação com o app
          // já em execução), sem precisar de um BuildContext específico.
          navigatorKey: notificationNavigatorKey,
          theme: ThemeData.light().copyWith(
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData.light().textTheme,
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
          ),
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          // Trava a escala de fonte do SISTEMA (acessibilidade do Android) num
          // intervalo estreito: sem isso, um aparelho com "tamanho de fonte"
          // do sistema no máximo faz o app INTEIRO nascer com texto enorme —
          // mesmo com o fontSizeMultiplier interno do app já corretamente em
          // 1.0. O app tem seu próprio controle de tamanho de fonte (Ajustes),
          // pensado especificamente para o público idoso, então não depende
          // da escala do sistema para acessibilidade.
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: mediaQuery.textScaler.clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.15,
                ),
              ),
              child: child!,
            );
          },
          home: hasSeenSplash
              ? MainNavigator(
                  initialTheme: initialTheme,
                  initialFontSize: initialFontSize,
                  initialAlarmSoundEnabled: initialAlarmSoundEnabled,
                  initialAlarmVibrationEnabled: initialAlarmVibrationEnabled,
                  initialRestock: initialRestock,
                  initialAlertMode: initialAlertMode,
                  launchAlarmInfo: launchAlarmInfo,
                )
              : SplashScreen(
                  initialTheme: initialTheme,
                  initialFontSize: initialFontSize,
                  initialAlarmSoundEnabled: initialAlarmSoundEnabled,
                  initialAlarmVibrationEnabled: initialAlarmVibrationEnabled,
                  initialRestock: initialRestock,
                  initialAlertMode: initialAlertMode,
                  launchAlarmInfo: launchAlarmInfo,
                ),
        );
      },
    );
  }
}

// === SPLASH SCREEN ===
class SplashScreen extends StatefulWidget {
  final String initialTheme;
  final double initialFontSize;
  final bool initialRestock;
  final String initialAlertMode;
  final bool initialAlarmSoundEnabled;
  final bool initialAlarmVibrationEnabled;
  final AlarmLaunchInfo? launchAlarmInfo;

  const SplashScreen({
    super.key,
    required this.initialTheme,
    required this.initialFontSize,
    required this.initialAlarmSoundEnabled,
    required this.initialAlarmVibrationEnabled,
    required this.initialRestock,
    required this.initialAlertMode,
    this.launchAlarmInfo,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () async {
      // Marca que o usuário já viu a splash — a partir de agora, todo
      // próximo lançamento do app pula direto para a Home (ver a checagem
      // de 'hasSeenSplash' em SeniCareApp.build()).
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppPreferenceKeys.hasSeenSplash, true);
      } catch (e) {
        debugPrint('[SplashScreen] Falha ao salvar hasSeenSplash: $e');
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigator(
              initialTheme: widget.initialTheme,
              initialFontSize: widget.initialFontSize,
              initialAlarmSoundEnabled: widget.initialAlarmSoundEnabled,
              initialAlarmVibrationEnabled: widget.initialAlarmVibrationEnabled,
              initialRestock: widget.initialRestock,
              initialAlertMode: widget.initialAlertMode,
              launchAlarmInfo: widget.launchAlarmInfo,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.initialTheme == 'Dark';

    BoxDecoration backgroundDecoration;
    Color textColor;

    if (widget.initialTheme == 'Default') {
      backgroundDecoration = const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF00B4DB)],
        ),
      );
      textColor = Colors.white;
    } else if (isDark) {
      backgroundDecoration = const BoxDecoration(color: Color(0xFF121212));
      textColor = Colors.white;
    } else {
      backgroundDecoration = const BoxDecoration(color: Colors.white);
      textColor = const Color(0xFF0D47A1);
    }

    return Scaffold(
      body: Container(
        decoration: backgroundDecoration,
        child: Center(
          child: Text(
            'SeniCare',
            // textScaler.noScaling: em campo, a logo aparecia enorme em
            // aparelhos com a acessibilidade "tamanho de fonte" do sistema
            // aumentada — o Text respeita esse ajuste por padrão, mesmo sem
            // relação nenhuma com o fontSizeMultiplier interno do app. A logo
            // é uma peça de marca com tamanho fixo, então ignora a escala do
            // sistema de propósito. Fontes cursivas de caligrafia (como esta)
            // têm curvas/laços que quebram feio se esticados, então essa
            // trava importa ainda mais aqui.
            textScaler: TextScaler.noScaling,
            // GoogleFonts.greatVibes: caligrafia clássica, mesma fonte usada
            // no 'Olá' da Home para as duas telas terem a mesma identidade
            // visual. Não define fontWeight/fontStyle: essa família só tem a
            // variante Regular — pedir outro peso faria o pacote lançar erro.
            style: GoogleFonts.greatVibes(fontSize: 54.0, color: textColor),
          ),
        ),
      ),
    );
  }
}

// === NAVEGAÇÃO PRINCIPAL ===
class MainNavigator extends StatefulWidget {
  final String initialTheme;
  final double initialFontSize;
  final bool initialRestock;
  final String initialAlertMode;
  final bool initialAlarmSoundEnabled;
  final bool initialAlarmVibrationEnabled;
  final AlarmLaunchInfo? launchAlarmInfo;

  const MainNavigator({
    super.key,
    required this.initialTheme,
    required this.initialFontSize,
    required this.initialAlarmSoundEnabled,
    required this.initialAlarmVibrationEnabled,
    required this.initialRestock,
    required this.initialAlertMode,
    this.launchAlarmInfo,
  });

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 1; // 1 = Início (HomeScreen)
  late String _currentTheme;
  late double _fontSizeMultiplier;
  late bool _isRestockEnabled;
  late String _alertMode;
  late bool _isAlarmSoundEnabled;
  late bool _isAlarmVibrationEnabled;

  @override
  void initState() {
    super.initState();
    _currentTheme = widget.initialTheme;
    _fontSizeMultiplier = widget.initialFontSize;
    _isRestockEnabled = widget.initialRestock;
    _alertMode = widget.initialAlertMode;
    _isAlarmSoundEnabled = widget.initialAlarmSoundEnabled;
    _isAlarmVibrationEnabled = widget.initialAlarmVibrationEnabled;

    // Lançamento por overlay chegando com o app já em execução (aberto ou
    // em background) — o nativo (MainActivity.onNewIntent) empurra pelo
    // canal assim que isso acontece. Cadastrado uma única vez aqui.
    NotificationService().listenForOverlayAlarms(_abrirTelaDeAlarme);

    // Se o app acabou de ser aberto do zero por um alarme (overlay ou toque
    // na notificação), empilha a AlarmScreen assim que este primeiro frame
    // terminar.
    final AlarmLaunchInfo? launchAlarmInfo = widget.launchAlarmInfo;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (launchAlarmInfo != null) {
        await _abrirTelaDeAlarme(launchAlarmInfo);
      } else {
        // Não mostra o aviso da MIUI por cima de um alarme real — só quando o
        // app abre normalmente (evita empilhar dois diálogos/telas cheias).
        if (mounted) {
          await MiuiPermissionHelper.mostrarAvisoSeNecessario(context);
        }
      }
    });
  }

  Future<void> _abrirTelaDeAlarme(AlarmLaunchInfo info) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlarmScreen(
          medicamentoId: info.medicamentoId,
          notificationId: info.notificationId,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _updateTheme(String newTheme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppPreferenceKeys.themeChoice, newTheme);
    themeModeNotifier.value = newTheme == 'Dark'
        ? ThemeMode.dark
        : (newTheme == 'Light' ? ThemeMode.light : ThemeMode.system);
    setState(() => _currentTheme = newTheme);
  }

  Future<void> _updateFontSize(double newSize) async {
    // Nunca confia cegamente no valor recebido: garante que o que é salvo
    // (e propagado pelo app inteiro) nunca ultrapassa o limite de 1.1.
    final double tamanhoSeguro = newSize.clamp(0.8, 1.1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppPreferenceKeys.fontSize, tamanhoSeguro);
    setState(() => _fontSizeMultiplier = tamanhoSeguro);
  }

  Future<void> _updateAlarmSound(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppPreferenceKeys.alarmSoundEnabled, value);
    setState(() => _isAlarmSoundEnabled = value);
  }

  Future<void> _updateAlarmVibration(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppPreferenceKeys.alarmVibrationEnabled, value);
    setState(() => _isAlarmVibrationEnabled = value);
  }

  Future<void> _updateRestock(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppPreferenceKeys.restockEnabled, value);
    setState(() => _isRestockEnabled = value);
  }

  Future<void> _updateAlertMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppPreferenceKeys.alertMode, value);
    setState(() => _alertMode = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _currentTheme == 'Dark';

    BoxDecoration backgroundDecoration;
    if (_currentTheme == 'Default') {
      backgroundDecoration = const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF00B4DB)],
        ),
      );
    } else if (isDark) {
      backgroundDecoration = const BoxDecoration(color: Color(0xFF121212));
    } else {
      backgroundDecoration = BoxDecoration(color: Colors.grey.shade50);
    }

    // O Container envolve todo o Scaffold para que o gradiente (tema Default)
    // se estenda por trás do BottomNavigationBar, permitindo que ele fique
    // transparente e pareça uma peça única com o restante da tela.
    return Container(
      decoration: backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              HistoryScreen(
                currentTheme: _currentTheme,
                fontSizeMultiplier: _fontSizeMultiplier,
                isActive: _currentIndex == 0,
              ),
              HomeScreen(
                currentTheme: _currentTheme,
                fontSizeMultiplier: _fontSizeMultiplier,
                isRestockEnabled: _isRestockEnabled,
                isActive: _currentIndex == 1,
              ),
              SettingsScreen(
                currentTheme: _currentTheme,
                fontSizeMultiplier: _fontSizeMultiplier,
                isRestockEnabled: _isRestockEnabled,
                alertMode: _alertMode,
                isAlarmSoundEnabled: _isAlarmSoundEnabled,
                isAlarmVibrationEnabled: _isAlarmVibrationEnabled,
                onThemeChanged: _updateTheme,
                onFontSizeChanged: _updateFontSize,
                onRestockChanged: _updateRestock,
                onAlertModeChanged: _updateAlertMode,
                onAlarmSoundChanged: _updateAlarmSound,
                onAlarmVibrationChanged: _updateAlarmVibration,
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          // No tema Default a barra fica transparente e o gradiente do Container
          // pai aparece por trás dela, deixando-a mesclada com o fundo (seamless).
          backgroundColor: _currentTheme == 'Default'
              ? Colors.transparent
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          elevation: _currentTheme == 'Default' ? 0 : 8,
          // Mesma cor do botão 'Adicionar Remédio' (sem nenhum tom de
          // ciano/teal): branco no tema Default, azul-marca nos outros dois.
          selectedItemColor: _currentTheme == 'Default'
              ? Colors.white
              : const Color(0xFF0D47A1),
          unselectedItemColor: _currentTheme == 'Default'
              ? Colors.white60
              : (isDark ? Colors.white54 : Colors.grey),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'Histórico',
            ),
            BottomNavigationBarItem(
              // Ícone limpo/minimalista (Cupertino) no lugar do frasco de
              // pílulas anterior; a versão preenchida marca a aba ativa.
              icon: Icon(CupertinoIcons.house),
              activeIcon: Icon(CupertinoIcons.house_fill),
              label: 'Início',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}

// === TELA DE INÍCIO (LISTA DE MEDICAMENTOS) ===
class HomeScreen extends StatefulWidget {
  final String currentTheme;
  final double fontSizeMultiplier;
  final bool isRestockEnabled;
  final bool isActive;

  const HomeScreen({
    super.key,
    required this.currentTheme,
    required this.fontSizeMultiplier,
    required this.isRestockEnabled,
    this.isActive = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _medicamentos = [];
  // medicamentoId -> true (tomou) / false (cancelou no alarme). Ausência da
  // chave significa que ainda não houve resposta ao alarme hoje.
  Map<int, bool> _statusDosesHoje = {};
  // IDs com registro de dose em andamento — trava sincrônica contra duplo
  // toque: 'tomadoHoje' só fica true depois de um round-trip assíncrono no
  // banco (_loadMedicamentos), então sem isso um segundo toque rápido, antes
  // desse reload terminar, duplicava o registro no histórico.
  final Set<int> _registrandoDose = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMedicamentos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMedicamentos(); // Recarrega automaticamente ao voltar para o app no dia seguinte
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadMedicamentos(); // Atualiza caso o usuário mude da aba de histórico para cá
    }
  }

  Future<void> _navigateToAddMedication() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicationScreen(
          currentTheme: widget.currentTheme,
          fontSizeMultiplier: widget.fontSizeMultiplier,
          isRestockEnabled: widget.isRestockEnabled,
        ),
      ),
    );
    if (result == true) {
      _loadMedicamentos();
    }
  }

  /// Mostra o diálogo de confirmação e executa a exclusão de forma segura.
  ///
  /// Bug corrigido: a versão anterior chamava `Navigator.pop(ctx)` logo após
  /// os `await`s, guardado só por `ctx.mounted` — mas `mounted` só vira false
  /// quando o elemento é DE FATO removido da árvore, o que só acontece depois
  /// que a transição de pop termina. Ou seja, um duplo toque em 'Excluir'
  /// disparava DOIS `onPressed` em paralelo, e ambos passavam pelo `mounted`
  /// antes de o primeiro pop terminar — o segundo `Navigator.pop` colidia com
  /// o primeiro, ainda em andamento, e derrubava a assinatura `!_debugLocked`.
  ///
  /// A correção: uma trava local (`excluindo`) desabilita o botão assim que
  /// o primeiro toque é processado, e o trabalho assíncrono inteiro (banco,
  /// cancelamento de alarmes, recarga da lista) é concluído ANTES da única
  /// chamada a `Navigator.pop` — que só acontece no fim, e só se o diálogo
  /// ainda estiver montado.
  Future<void> _confirmarExclusao(Map<String, dynamic> med) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool excluindo = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Excluir Medicamento'),
              content: const Text(
                'Tem certeza que deseja remover este medicamento?',
              ),
              actions: [
                TextButton(
                  onPressed: excluindo
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: excluindo
                      ? null
                      : () async {
                          setDialogState(() => excluindo = true);

                          // 1) Trabalho assíncrono inteiro primeiro — nenhuma
                          // chamada ao Navigator aqui dentro.
                          try {
                            await DatabaseHelper().deleteMedicamento(med['id']);
                          } catch (e) {
                            debugPrint(
                              '[Excluir] Falha ao remover do banco: $e',
                            );
                          }
                          // Evita alarmes órfãos disparando para um remédio
                          // já excluído.
                          try {
                            await NotificationService().cancelMedicationAlarms(
                              med['id'],
                            );
                          } catch (_) {}
                          await _loadMedicamentos();

                          // 2) Só agora, com tudo resolvido, fecha o diálogo —
                          // uma única vez, e só se ele ainda existir.
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  child: excluindo
                      ? const SizedBox(
                          width: 18.0,
                          height: 18.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: Colors.red,
                          ),
                        )
                      : const Text(
                          'Excluir',
                          style: TextStyle(color: Colors.red),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadMedicamentos() async {
    final data = await DatabaseHelper().getMedicamentos();
    final statusHoje = await DatabaseHelper().getStatusDosesHoje();

    if (mounted) {
      setState(() {
        _medicamentos.clear(); // Limpa a lista antes de reconstruir

        final agora = DateTime.now();
        final hoje = DateTime(agora.year, agora.month, agora.day);

        // Mapeamento para bater exatamente com a string que salvamos
        final List<String> diasDaSemana = [
          'Seg',
          'Ter',
          'Qua',
          'Qui',
          'Sex',
          'Sáb',
          'Dom',
        ];
        final nomeDiaHoje = diasDaSemana[agora.weekday - 1];

        for (var med in data) {
          // Precisamos de um Map mutável para poder alterar a string de horários na tela
          final medicamento = Map<String, dynamic>.from(med);

          final inicio = DateTime.parse(medicamento['data_inicio']);
          final dataInicio = DateTime(inicio.year, inicio.month, inicio.day);

          DateTime dataFim = DateTime(
            hoje.year + 5,
          ); // Proteção: 5 anos de uso contínuo
          if (medicamento['data_fim'] != null) {
            final fim = DateTime.parse(medicamento['data_fim']);
            dataFim = DateTime(fim.year, fim.month, fim.day, 23, 59, 59);
          }

          // 1. Filtro Mestre: O remédio está dentro do prazo do tratamento?
          if (hoje.isBefore(dataInicio) || hoje.isAfter(dataFim)) {
            continue; // Já passou da validade ou nem começou, ignora.
          }

          final tipo = medicamento['frequencia_tipo'] ?? 'Horários Fixos';
          bool mostrarHoje = false;

          // 2. Lógica Simples: Horários Fixos
          if (tipo == 'Horários Fixos') {
            final dias = medicamento['dias_semana'] as String;
            // Comparação exata por token: usar String.contains() aqui comparava substrings
            // (ex: dias.contains('Seg')) em vez dos dias individuais, o que causava falsos
            // positivos/negativos ao selecionar apenas alguns dias da semana.
            final diasList = dias.split(',').map((d) => d.trim()).toSet();
            if (dias == 'Todos os dias' || diasList.contains(nomeDiaHoje)) {
              mostrarHoje = true;
            }
          }
          // 3. Lógica Avançada: Intervalos (Calcula as doses do dia)
          else if (tipo == 'Intervalo') {
            mostrarHoje = true;

            final intervalo = medicamento['intervalo_horas'] as int;
            final primeiraHoraStr = (medicamento['horario'] as String)
                .split(', ')
                .first;
            final partesHora = primeiraHoraStr.split(':');

            // Fixamos no espaço-tempo a mesmíssima primeira dose
            DateTime proximaDose = DateTime(
              inicio.year,
              inicio.month,
              inicio.day,
              int.parse(partesHora[0]),
              int.parse(partesHora[1]),
            );

            // O Paradoxo da Meia-Noite: Para humanos, 00:00 pertence ao "hoje".
            // Então um dia vai de 00:00:01 de hoje até 00:00:00 de amanhã.
            final inicioDoDia = hoje.add(const Duration(seconds: 1));
            final fimDoDia = hoje.add(const Duration(days: 1));

            // Avança no tempo até chegar no início do dia de hoje
            while (proximaDose.isBefore(inicioDoDia)) {
              proximaDose = proximaDose.add(Duration(hours: intervalo));
            }

            // Pega todas as doses que caem até a meia-noite exata
            List<String> horariosDeHoje = [];
            while (proximaDose.isBefore(fimDoDia) ||
                proximaDose.isAtSameMomentAs(fimDoDia)) {
              final h = proximaDose.hour.toString().padLeft(2, '0');
              final m = proximaDose.minute.toString().padLeft(2, '0');
              horariosDeHoje.add(
                '$h:$m',
              ); // Se for meia-noite, adiciona o "00:00" na tela de hoje

              proximaDose = proximaDose.add(Duration(hours: intervalo));
            }

            if (horariosDeHoje.isNotEmpty) {
              medicamento['horario'] = horariosDeHoje.join(', ');
            } else {
              mostrarHoje = false;
            }
          }

          // Passou na malha fina? Adiciona na interface!
          if (mostrarHoje) {
            _medicamentos.add(medicamento);
          }
        }

        _statusDosesHoje = statusHoje;
      });
    }
  }

  Widget _buildGiantAddButton() {
    final bool isDefault = widget.currentTheme == 'Default';
    final bool useWhiteIcon = widget.currentTheme == 'Dark' || isDefault;
    final Color iconColor = useWhiteIcon
        ? Colors.white
        : const Color(0xFF0D47A1);
    // clamp(0.8, 1.1): mesmo intervalo usado em todo o resto do app — o
    // clamp(1.0, 1.1) anterior travava esse ícone num tamanho mínimo maior
    // que o real fontSizeMultiplier do usuário quando ele escolhia 0.8.
    final double iconSize = 72.0 * widget.fontSizeMultiplier.clamp(0.8, 1.1);

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _navigateToAddMedication,
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          // CupertinoIcons.add: traço bem mais fino/elegante que o Icons.add
          // (Material) ou o Icons.add_rounded usado antes, no padrão Apple.
          child: Icon(CupertinoIcons.add, size: iconSize, color: iconColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useWhiteText =
        widget.currentTheme == 'Dark' || widget.currentTheme == 'Default';
    final textColor = useWhiteText ? Colors.white : Colors.black87;
    final subTextColor = useWhiteText ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: widget.currentTheme == 'Default'
            ? Colors.white
            : const Color(0xFF0D47A1),
        // Sem ícone de '+': só o texto, num formato de pílula totalmente
        // arredondado.
        shape: const StadiumBorder(),
        label: Text(
          'Adicionar Remédio',
          style: TextStyle(
            color: widget.currentTheme == 'Default'
                ? const Color(0xFF0D47A1)
                : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: _navigateToAddMedication,
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0 * widget.fontSizeMultiplier),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GoogleFonts.greatVibes: caligrafia clássica, mesma fonte usada
            // na logo da Splash. O pacote nunca lança por falta de rede — só
            // usa um fallback do sistema até baixar/cachear a fonte real.
            Text(
              'Olá',
              textScaler: TextScaler.noScaling,
              style: GoogleFonts.greatVibes(
                fontSize: 46.0 * widget.fontSizeMultiplier,
                color: textColor,
              ),
            ),
            SizedBox(height: 8.0 * widget.fontSizeMultiplier),
            Text(
              _medicamentos.isEmpty
                  ? 'Clique para adicionar seus medicamentos'
                  : 'Aqui estão seus medicamentos.',
              style: TextStyle(
                fontSize: 18.0 * widget.fontSizeMultiplier,
                color: subTextColor,
              ),
            ),
            SizedBox(height: 24.0 * widget.fontSizeMultiplier),
            Expanded(
              child: _medicamentos.isEmpty
                  ? Center(
                      // Widget de Estado Vazio
                      child: _buildGiantAddButton(),
                    )
                  : ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      itemCount: _medicamentos.length,

                      itemBuilder: (context, index) {
                        final med = _medicamentos[index];
                        // true = confirmou hoje; false = cancelou no alarme
                        // (disse que não tomou); null = ainda sem resposta.
                        final bool? statusHoje = _statusDosesHoje[med['id']];

                        String diasTexto = med['dias_semana'];
                        if (diasTexto == 'S, T, Q, Q, S, S, D' ||
                            diasTexto == 'Seg, Ter, Qua, Qui, Sex, Sáb, Dom') {
                          diasTexto = 'Todos os dias';
                        }

                        return GlassCard(
                          margin: EdgeInsets.only(
                            bottom: 16.0 * widget.fontSizeMultiplier,
                          ),
                          isDark: widget.currentTheme == 'Dark',
                          borderRadius: 10.0,
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddMedicationScreen(
                                      medicationData: med,
                                      currentTheme: widget.currentTheme,
                                      fontSizeMultiplier:
                                          widget.fontSizeMultiplier,
                                      isRestockEnabled: widget.isRestockEnabled,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  _loadMedicamentos();
                                }
                              },
                              child: Padding(
                                padding: EdgeInsets.all(
                                  16.0 * widget.fontSizeMultiplier,
                                ),
                                child: Row(
                                  children: [
                                    if (med['foto_path'] != null)
                                      CircleAvatar(
                                        backgroundImage: FileImage(
                                          File(med['foto_path']),
                                        ),
                                        radius: 36 * widget.fontSizeMultiplier,
                                      )
                                    else
                                      CircleAvatar(
                                        backgroundColor:
                                            (useWhiteText
                                                    ? Colors.white
                                                    : const Color(0xFF0D47A1))
                                                .withValues(alpha: 0.2),
                                        radius: 36 * widget.fontSizeMultiplier,
                                        child: _PillIcon(
                                          size: 34 * widget.fontSizeMultiplier,
                                          color: useWhiteText
                                              ? Colors.white
                                              : const Color(0xFF0D47A1),
                                        ),
                                      ),
                                    SizedBox(
                                      width: 16 * widget.fontSizeMultiplier,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            med['nome'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                              fontSize:
                                                  22.0 *
                                                  widget.fontSizeMultiplier,
                                            ),
                                          ),
                                          SizedBox(
                                            height:
                                                8 * widget.fontSizeMultiplier,
                                          ),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size:
                                                    20 *
                                                    widget.fontSizeMultiplier,
                                                color: subTextColor,
                                              ),
                                              SizedBox(
                                                width:
                                                    4 *
                                                    widget.fontSizeMultiplier,
                                              ),
                                              // Expanded + ellipsis: sem isso, um
                                              // horário longo com a fonte em 110%
                                              // causava RenderFlex overflow aqui.
                                              Expanded(
                                                child: Text(
                                                  med['horario'],
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: subTextColor,
                                                    fontSize:
                                                        18.0 *
                                                        widget
                                                            .fontSizeMultiplier,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height:
                                                4 * widget.fontSizeMultiplier,
                                          ),
                                          Text(
                                            diasTexto,
                                            style: TextStyle(
                                              color: subTextColor,
                                              fontSize:
                                                  16.0 *
                                                  widget.fontSizeMultiplier,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            statusHoje == true
                                                ? Icons.check_circle
                                                : (statusHoje == false
                                                      ? Icons.cancel
                                                      : Icons
                                                            .radio_button_unchecked),
                                            color: statusHoje == true
                                                ? Colors.green
                                                : (statusHoje == false
                                                      ? Colors.red
                                                      : Colors.grey),
                                            size:
                                                40 * widget.fontSizeMultiplier,
                                          ),
                                          tooltip: statusHoje == true
                                              ? 'Dose já registrada hoje'
                                              : (statusHoje == false
                                                    ? 'Você marcou que não tomou — toque para confirmar que tomou'
                                                    : 'Registrar Dose'),
                                          // Só trava quando JÁ confirmado —
                                          // se cancelou no alarme (false) ou
                                          // ainda não respondeu (null), o
                                          // toque aqui confirma que tomou.
                                          onPressed:
                                              (statusHoje == true ||
                                                  _registrandoDose.contains(
                                                    med['id'],
                                                  ))
                                              ? null
                                              : () async {
                                                  setState(
                                                    () => _registrandoDose.add(
                                                      med['id'],
                                                    ),
                                                  );
                                                  try {
                                                    await DatabaseHelper()
                                                        .registrarDose(
                                                          med['id'],
                                                          tomado: true,
                                                        );
                                                  } catch (e) {
                                                    debugPrint(
                                                      '[HomeScreen] Falha ao registrar dose: $e',
                                                    );
                                                  }
                                                  // _loadMedicamentos já chama
                                                  // setState internamente, o
                                                  // que atualiza statusHoje e
                                                  // torna a trava abaixo
                                                  // redundante — mas ainda
                                                  // limpamos o ID pra não
                                                  // deixar a trava vazando.
                                                  await _loadMedicamentos();
                                                  if (mounted) {
                                                    setState(
                                                      () => _registrandoDose
                                                          .remove(med['id']),
                                                    );
                                                  }
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Dose registrada com sucesso!',
                                                        ),
                                                        backgroundColor:
                                                            Colors.green,
                                                      ),
                                                    );
                                                  }
                                                },
                                        ),
                                        SizedBox(
                                          height:
                                              24.0 * widget.fontSizeMultiplier,
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size:
                                                32 * widget.fontSizeMultiplier,
                                          ),
                                          tooltip: 'Remover',
                                          onPressed: () =>
                                              _confirmarExclusao(med),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ícone de pílula desenhado direto no Canvas (CustomPaint): uma cápsula na
/// diagonal, metade sólida e metade translúcida, com um contorno sólido ao
/// redor pra continuar visível mesmo sobre um fundo de cor parecida. Usado
/// no lugar de Icons.medication porque, no Material Icons clássico embutido
/// no Flutter, esse glifo desenha um pote/frasco com uma cruz, não uma
/// pílula — nenhuma troca de IconData resolvia o pedido. Desenhar no Canvas
/// (em vez de compor com Transform.rotate + ClipRRect) evita qualquer
/// ambiguidade de layout/clipping entre widgets — o formato é sempre
/// exatamente o que está descrito aqui.
class _PillIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _PillIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PillIconPainter(color)),
    );
  }
}

class _PillIconPainter extends CustomPainter {
  final Color color;

  const _PillIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 4);

    final double largura = size.width * 0.85;
    final double altura = size.height * 0.42;
    final Rect retangulo = Rect.fromCenter(
      center: Offset.zero,
      width: largura,
      height: altura,
    );
    final RRect capsula = RRect.fromRectAndRadius(
      retangulo,
      Radius.circular(altura / 2),
    );

    canvas.save();
    canvas.clipRRect(capsula);
    canvas.drawRect(
      Rect.fromLTWH(retangulo.left, retangulo.top, largura / 2, altura),
      Paint()..color = color,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        retangulo.left + largura / 2,
        retangulo.top,
        largura / 2,
        altura,
      ),
      Paint()..color = color.withValues(alpha: 0.35),
    );
    canvas.restore();

    // Contorno sólido: garante que a cápsula continue visível mesmo quando
    // o fundo atrás dela tem um tom parecido com a própria cor do ícone.
    canvas.drawRRect(
      capsula,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = altura * 0.14
        ..color = color,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PillIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
