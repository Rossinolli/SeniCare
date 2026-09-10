// Tela que aparece na hora de tomar o remédio, ocupando a tela toda, com as
// opções de confirmar que tomou, adiar 10 minutos ou cancelar o alarme.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'notification_service.dart';

class _AlarmPalette {
  _AlarmPalette._();

  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color backgroundLight = Color(0xFF1E293B);
  static const Color cardColor = Color(0xFF334155);
  static const Color primaryBlue = Color(0xFF0EA5E9);
  static const Color secondaryBlue = Color(0xFF0369A1);
  static const Color lightBlue = Color(0xFF7DD3FC);
}

class AlarmScreen extends StatefulWidget {
  final int medicamentoId;
  final int notificationId;

  const AlarmScreen({
    super.key,
    required this.medicamentoId,
    required this.notificationId,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  Map<String, dynamic>? _medicamento;
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadMedicamento();
  }

  Future<void> _loadMedicamento() async {
    try {
      // O payload da notificação carrega só o ID (leve e sempre atualizado);
      // o nome exibido vem direto do SQLite, então reflete o nome atual do
      // remédio mesmo que o usuário o tenha editado depois de agendar.
      final data = await DatabaseHelper().getMedicamentoById(
        widget.medicamentoId,
      );
      debugPrint(
        '[AlarmScreen] Medicamento id=${widget.medicamentoId}: '
        '${data == null ? "NÃO ENCONTRADO no banco" : data['nome']}',
      );

      if (data == null) {
        // O medicamento foi excluído depois que este alarme já tinha sido
        // agendado (ex.: usuário cadastra às 20:40 e apaga antes da hora
        // chegar) — o cancelamento pode não ter alcançado a tempo essa
        // ocorrência específica. Em vez de tocar/mostrar uma tela de alarme
        // para um remédio que não existe mais, dispensa tudo (som,
        // vibração, alarme de overlay) e fecha imediatamente, sem exigir
        // nenhuma ação do usuário.
        debugPrint(
          '[AlarmScreen] Medicamento excluído — dispensando o alarme sem exibir a tela.',
        );
        try {
          await NotificationService().dismissAlarm(widget.notificationId);
        } catch (e) {
          debugPrint(
            '[AlarmScreen] Falha ao dispensar alarme de medicamento excluído: $e',
          );
        }
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (mounted) {
        setState(() {
          _medicamento = data;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[AlarmScreen] Falha ao carregar medicamento: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Confirma a dose: registra o check-in no histórico (SQLite) ANTES de
  /// dispensar o alarme e fechar a tela — é assim que o ícone de check verde
  /// já aparece ao lado do remédio quando o usuário volta para a Home.
  Future<void> _handleConfirmar() async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      await DatabaseHelper().registrarDose(widget.medicamentoId, tomado: true);
    } catch (e) {
      debugPrint('[AlarmScreen] Falha ao registrar dose: $e');
    }
    try {
      await NotificationService().dismissAlarm(widget.notificationId);
    } catch (e) {
      debugPrint('[AlarmScreen] Falha ao dispensar alarme: $e');
    }

    if (mounted) Navigator.of(context).pop();
  }

  /// Cancela esta ocorrência do alarme registrando explicitamente que o
  /// usuário NÃO tomou a dose (tomado: false) — é isso que faz a Home
  /// mostrar o ícone vermelho e o Relatório de Adesão contar como
  /// 'Esquecido' em vez de simplesmente não saber o que aconteceu. As
  /// próximas doses já agendadas na série continuam intactas.
  Future<void> _handleCancelar() async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      await DatabaseHelper().registrarDose(widget.medicamentoId, tomado: false);
    } catch (e) {
      debugPrint('[AlarmScreen] Falha ao registrar dose não tomada: $e');
    }
    try {
      await NotificationService().dismissAlarm(widget.notificationId);
    } catch (e) {
      debugPrint('[AlarmScreen] Falha ao cancelar alarme: $e');
    }

    if (mounted) Navigator.of(context).pop();
  }

  /// Adia esta ocorrência em 10 minutos: cancela o alarme atual e agenda um
  /// novo avulso (snoozeAlarm), independente da série de ocorrências futuras
  /// já agendada para este medicamento.
  Future<void> _handleAdiar() async {
    if (_processing) return;
    setState(() => _processing = true);

    final String nome = (_medicamento?['nome'] as String?) ?? 'Medicamento';
    final String descricao = (_medicamento?['descricao'] as String?) ?? '';

    try {
      await NotificationService().snoozeAlarm(
        medId: widget.medicamentoId,
        nome: nome,
        descricao: descricao,
      );
    } catch (e) {
      debugPrint('[AlarmScreen] Falha ao adiar alarme: $e');
    }
    try {
      await NotificationService().dismissAlarm(widget.notificationId);
    } catch (e) {
      debugPrint(
        '[AlarmScreen] Falha ao cancelar alarme original ao adiar: $e',
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final String nomeRemedio =
        (_medicamento?['nome'] as String?) ?? 'Medicamento';
    final String descricao = (_medicamento?['descricao'] as String?) ?? '';

    return PopScope(
      // Bloqueia o botão de voltar: o idoso precisa usar um dos dois botões.
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.1,
              colors: [
                _AlarmPalette.backgroundLight,
                _AlarmPalette.backgroundDark,
              ],
            ),
          ),
          child: SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20.0),
                        const _AlarmIcon(),
                        // Design minimalista: sem títulos/subtítulos acima do
                        // card — ele é o único foco visual da tela, reduzindo
                        // a carga cognitiva no momento do alarme.
                        Expanded(
                          child: Center(
                            child: _MedicationCard(
                              nomeRemedio: nomeRemedio,
                              descricao: descricao,
                            ),
                          ),
                        ),
                        _ConfirmButton(
                          processing: _processing,
                          onPressed: _processing ? null : _handleConfirmar,
                        ),
                        const SizedBox(height: 28.0),
                        // Dois botões secundários lado a lado, mesma altura e
                        // largura (Expanded + SizedBox no meio) — bem mais
                        // discretos que o Confirmar, para não competir com ele.
                        Row(
                          children: [
                            Expanded(
                              child: _SecondaryAlarmButton(
                                label: 'Cancelar',
                                onPressed: _processing ? null : _handleCancelar,
                              ),
                            ),
                            const SizedBox(width: 16.0),
                            Expanded(
                              child: _SecondaryAlarmButton(
                                label: 'Adiar 10 min',
                                onPressed: _processing ? null : _handleAdiar,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Ícone de sino no topo: 3 círculos concêntricos (translúcido > claro >
/// branco sólido) com o sino azul no centro e dois traços laterais
/// sugerindo a vibração/som do alarme tocando.
class _AlarmIcon extends StatelessWidget {
  const _AlarmIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200.0,
      height: 200.0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 200.0,
            height: 200.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _AlarmPalette.secondaryBlue.withValues(alpha: 0.15),
            ),
          ),
          Container(
            width: 150.0,
            height: 150.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _AlarmPalette.lightBlue.withValues(alpha: 0.30),
            ),
          ),
          Container(
            width: 100.0,
            height: 100.0,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.notifications_active,
              color: _AlarmPalette.primaryBlue,
              size: 48.0,
            ),
          ),
          // Traços laterais sugerindo o som/vibração ecoando do sino.
          Positioned(
            left: 4.0,
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: Icon(
                Icons.wifi_rounded,
                color: _AlarmPalette.primaryBlue.withValues(alpha: 0.55),
                size: 24.0,
              ),
            ),
          ),
          Positioned(
            right: 4.0,
            child: Transform.rotate(
              angle: math.pi / 2,
              child: Icon(
                Icons.wifi_rounded,
                color: _AlarmPalette.primaryBlue.withValues(alpha: 0.55),
                size: 24.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card central com os dados do medicamento — nome dinâmico, lido do banco
/// pela AlarmScreen (via [AlarmScreen.medicamentoId]). É o foco absoluto da
/// tela: só o nome em destaque, uma linha divisória e a dose/descrição.
class _MedicationCard extends StatelessWidget {
  final String nomeRemedio;
  final String descricao;

  const _MedicationCard({required this.nomeRemedio, required this.descricao});

  @override
  Widget build(BuildContext context) {
    final double largura = MediaQuery.sizeOf(context).width * 0.88;
    // Mostra a descrição/motivo salvo pelo usuário quando existir; senão,
    // cai num texto genérico de dose.
    final String textoRodape = descricao.trim().isNotEmpty
        ? descricao.trim()
        : '1 comprimido';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          width: largura,
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 36.0),
          decoration: BoxDecoration(
            color: _AlarmPalette.cardColor.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: _AlarmPalette.primaryBlue.withValues(alpha: 0.20),
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // FittedBox: nomes grandes (ex.: 'Paracetamol') sempre cabem
              // numa linha só, encolhendo em vez de estourar o card.
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    nomeRemedio,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 34.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              Container(
                height: 1.0,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 18.0),
              Text(
                textoRodape,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _AlarmPalette.lightBlue,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão principal: só o gradiente azul e o texto — visual clean, sem
/// selos/ícones decorativos, para reduzir a carga cognitiva. Enquanto
/// [processing] é true, mostra um spinner no lugar do texto (trava contra
/// duplo toque enquanto o check-in é salvo no banco).
class _ConfirmButton extends StatelessWidget {
  final bool processing;
  final VoidCallback? onPressed;

  const _ConfirmButton({required this.processing, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final double largura = MediaQuery.sizeOf(context).width * 0.88;

    return SizedBox(
      width: largura,
      height: 76.0,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(10.0),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _AlarmPalette.primaryBlue,
                  _AlarmPalette.secondaryBlue,
                ],
              ),
            ),
            child: Center(
              child: processing
                  ? const SizedBox(
                      width: 28.0,
                      height: 28.0,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3.0,
                      ),
                    )
                  : const Text(
                      'Confirmar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 26.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão secundário: fundo transparente, borda fina — usado tanto para
/// 'Cancelar' quanto 'Adiar', sempre com a mesma altura, fonte e estilo,
/// para não competir visualmente com o Confirmar.
class _SecondaryAlarmButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _SecondaryAlarmButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final Color cor = _AlarmPalette.lightBlue.withValues(alpha: 0.85);

    return SizedBox(
      height: 52.0,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: cor,
          side: BorderSide(
            color: _AlarmPalette.lightBlue.withValues(alpha: 0.4),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: cor,
            fontSize: 15.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
