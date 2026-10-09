// Tela que toma o celular inteiro na hora do remédio: mostra o remédio de
// forma padronizada (nome, gramatura e quantidade, para que serve) e três
// respostas — Tomei / Adiar 10 min / Não vou tomar. Usa as cores do tema
// escolhido em Ajustes (Padrão, Claro ou Escuro), como o resto do app.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/componentes.dart';
import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../data/repositorio.dart';
import '../../domain/medicamento.dart';
import '../../services/notification_service.dart';

/// Verde do "Tomei" em todos os temas: a resposta principal se reconhece
/// pela cor (texto branco em negrito de 26 sp — texto grande, 3,3:1).
const Color _verdeTomei = Color(0xFF16A34A);

class AlarmScreen extends StatefulWidget {
  final AlarmLaunchInfo info;

  const AlarmScreen({super.key, required this.info});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  // Várias AlarmScreens podem empilhar (dois remédios no mesmo horário):
  // o app só sai de cima da tela de bloqueio quando a última fecha.
  static int _abertas = 0;

  final NotificationService _notificacoes = NotificationService();
  Medicamento? _med;
  DateTime? _horarioDose;
  bool _carregando = true;
  bool _processando = false;
  Timer? _vigia;
  bool _notificacaoEstavaAtiva = false;

  @override
  void initState() {
    super.initState();
    _abertas++;
    _notificacoes.exibirSobreTelaDeBloqueio(true);
    _carregar();
  }

  @override
  void dispose() {
    _vigia?.cancel();
    _abertas--;
    if (_abertas == 0) _notificacoes.exibirSobreTelaDeBloqueio(false);
    super.dispose();
  }

  Future<void> _carregar() async {
    _horarioDose =
        widget.info.horarioDose ??
        await _notificacoes.horarioDaDose(widget.info.notificationId);
    {
      final Medicamento? med = await Repositorio.instance.porId(
        widget.info.medicamentoId,
      );
      if (med == null || med.arquivado) {
        // Remédio removido depois que o alarme foi agendado: dispensa
        // tudo e fecha, sem tocar para um remédio que não está mais em uso.
        await _notificacoes.dispensar(widget.info.notificationId);
        if (mounted) Navigator.of(context).pop();
        return;
      }
      _med = med;
    }
    if (!mounted) return;
    setState(() => _carregando = false);
    _vigiarNotificacao();
  }

  /// Se a dose for respondida pelos botões da notificação enquanto esta tela
  /// está aberta, a notificação some — e a tela fecha junto, em vez de
  /// esperar uma segunda resposta (que duplicaria o registro).
  void _vigiarNotificacao() {
    _vigia = Timer.periodic(const Duration(seconds: 2), (_) async {
      final bool ativa = await _notificacoes.notificacaoAtiva(
        widget.info.notificationId,
      );
      if (ativa) {
        _notificacaoEstavaAtiva = true;
      } else if (_notificacaoEstavaAtiva && !_processando && mounted) {
        _vigia?.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _responder({required bool tomado}) async {
    if (_processando) return; // trava contra duplo toque
    setState(() => _processando = true);
    _vigia?.cancel();
    final Medicamento? med = _med;
    if (med != null) {
      await Repositorio.instance.registrarResposta(
        med,
        tomado: tomado,
        horarioDose: _horarioDose,
      );
    }
    await _notificacoes.dispensar(widget.info.notificationId);
    if (mounted) Navigator.of(context).pop();
  }

  /// Dispensa ANTES de agendar o adiamento: quando o alarme tocando já é um
  /// adiamento, os dois têm o mesmo ID.
  Future<void> _adiar() async {
    if (_processando) return;
    setState(() => _processando = true);
    _vigia?.cancel();
    await _notificacoes.dispensar(widget.info.notificationId);
    final Medicamento? med = _med;
    if (med != null) await _notificacoes.adiar(med, horarioDose: _horarioDose);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Textos grandes por padrão; a escala de acessibilidade ainda vale, com
    // teto para a tela caber sem rolagem na maioria dos aparelhos.
    final MediaQueryData mq = MediaQuery.of(context);
    final c = context.cores;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: c.barraDeStatus,
      child: PopScope(
        // O botão Voltar não dispensa o alarme: é preciso responder.
        canPop: false,
        child: MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: 1.35),
          ),
          child: Scaffold(
            backgroundColor: c.fundo,
            body: FundoDoTema(
              child: SafeArea(
                child: _carregando
                    ? Center(
                        child: CircularProgressIndicator(color: c.destaque),
                      )
                    : LayoutBuilder(
                        builder: (context, c) => SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: c.maxHeight),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                child: _conteudo(),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _conteudo() {
    final c = context.cores;
    final Medicamento? med = _med;
    final DateTime? horario = _horarioDose;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        const _Sino(),
        const SizedBox(height: 16),
        Text(
          horario == null ? 'Hora do remédio' : 'Dose das ${hhmm(horario)}',
          style: TextStyle(
            color: c.textoSecundario,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Cartao(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (med != null) ...[
                AvatarRemedio(fotoPath: med.fotoPath, raio: 44),
                const SizedBox(height: 14),
              ],
              Text(
                med?.nome ?? 'SeniCare',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.texto,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                med?.textoDose ?? 'Tome a dose indicada na receita',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.destaque,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (med?.textoMotivo != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.suave,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Para: ${med!.textoMotivo}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textoSecundario, fontSize: 18),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        ...[
          _BotaoPrincipal(
            rotulo: 'Tomei',
            icone: Icons.check_rounded,
            carregando: _processando,
            onPressed: _processando ? null : () => _responder(tomado: true),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BotaoSecundario(
                  rotulo: 'Adiar 10 min',
                  icone: Icons.snooze_rounded,
                  onPressed: _processando ? null : _adiar,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BotaoSecundario(
                  rotulo: 'Não vou tomar',
                  icone: Icons.close_rounded,
                  onPressed: _processando
                      ? null
                      : () => _responder(tomado: false),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Sino extends StatelessWidget {
  const _Sino();

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.destaque.withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.destaque),
        child: Icon(
          Icons.notifications_active_rounded,
          color: c.sobreDestaque,
          size: 44,
        ),
      ),
    );
  }
}

class _BotaoPrincipal extends StatelessWidget {
  final String rotulo;
  final IconData? icone;
  final bool carregando;
  final VoidCallback? onPressed;

  const _BotaoPrincipal({
    required this.rotulo,
    this.icone,
    this.carregando = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 76,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: _verdeTomei,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF166534),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        onPressed: onPressed,
        child: carregando
            ? const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icone != null) ...[
                    Icon(icone, size: 32),
                    const SizedBox(width: 10),
                  ],
                  Text(rotulo),
                ],
              ),
      ),
    );
  }
}

class _BotaoSecundario extends StatelessWidget {
  final String rotulo;
  final IconData icone;
  final VoidCallback? onPressed;

  const _BotaoSecundario({
    required this.rotulo,
    required this.icone,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return SizedBox(
      height: 64,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.destaque,
          backgroundColor: c.superficie,
          side: BorderSide(color: c.destaque, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: onPressed,
        icon: Icon(icone),
        label: Text(rotulo, textAlign: TextAlign.center),
      ),
    );
  }
}
