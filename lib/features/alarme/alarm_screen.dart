// Tela que toma o celular inteiro na hora do remédio: mostra o remédio de
// forma padronizada (nome, gramatura e quantidade, para que serve) e três
// respostas — Tomei / Adiar 10 min / Não vou tomar.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/componentes.dart';
import '../../core/formatos.dart';
import '../../data/repositorio.dart';
import '../../domain/medicamento.dart';
import '../../services/notification_service.dart';

class _Paleta {
  static const Color fundoTopo = Color(0xFF0B1B3F);
  static const Color fundoBase = Color(0xFF07122A);
  static const Color cartao = Color(0xFF16284F);
  static const Color destaque = Color(0xFF38BDF8);
  static const Color texto = Colors.white;
  static const Color textoSecundario = Color(0xFFC7D6EE);
  static const Color botaoSecundario = Color(0xFF9CC8F5);
}

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

  bool get _teste => widget.info.ehTeste;

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
    if (!_teste) {
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

  Future<void> _fecharTeste() async {
    _vigia?.cancel();
    await _notificacoes.dispensar(widget.info.notificationId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Textos grandes por padrão; a escala de acessibilidade ainda vale, com
    // teto para a tela caber sem rolagem na maioria dos aparelhos.
    final MediaQueryData mq = MediaQuery.of(context);
    return PopScope(
      // O botão Voltar não dispensa o alarme: é preciso responder.
      canPop: false,
      child: MediaQuery(
        data: mq.copyWith(
          textScaler: mq.textScaler.clamp(maxScaleFactor: 1.35),
        ),
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_Paleta.fundoTopo, _Paleta.fundoBase],
              ),
            ),
            child: SafeArea(
              child: _carregando
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : LayoutBuilder(
                      builder: (context, c) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: c.maxHeight),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
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
    );
  }

  Widget _conteudo() {
    final Medicamento? med = _med;
    final DateTime? horario = _horarioDose;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        const _Sino(),
        const SizedBox(height: 16),
        Text(
          _teste
              ? 'Teste de alarme'
              : (horario == null
                    ? 'Hora do remédio'
                    : 'Dose das ${hhmm(horario)}'),
          style: const TextStyle(
            color: _Paleta.textoSecundario,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _Paleta.cartao,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _Paleta.destaque.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              if (med != null) ...[
                AvatarRemedio(fotoPath: med.fotoPath, raio: 44),
                const SizedBox(height: 14),
              ],
              Text(
                med?.nome ?? 'SeniCare',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Paleta.texto,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _teste
                    ? 'Os alarmes estão funcionando neste aparelho.'
                    : (med?.textoDose ?? 'Tome a dose indicada na receita'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Paleta.destaque,
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
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Para: ${med!.textoMotivo}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _Paleta.textoSecundario,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        if (_teste)
          _BotaoPrincipal(rotulo: 'Fechar teste', onPressed: _fecharTeste)
        else ...[
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
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _Paleta.destaque.withValues(alpha: 0.15),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 84,
        height: 84,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: const Icon(
          Icons.notifications_active_rounded,
          color: Color(0xFF0369A1),
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
          backgroundColor: const Color(0xFF16A34A),
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
    return SizedBox(
      height: 64,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _Paleta.botaoSecundario,
          side: const BorderSide(color: _Paleta.botaoSecundario, width: 1.4),
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
