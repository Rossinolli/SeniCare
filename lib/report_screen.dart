// Tela de relatório que mostra como está o tratamento na semana: a
// porcentagem de doses tomadas e, dia por dia, quantas foram tomadas e
// quantas foram esquecidas.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'database_helper.dart';
import 'glass_card.dart';

class _DiaRelatorio {
  final DateTime dia;
  final int tomados;
  final int agendados;

  const _DiaRelatorio({
    required this.dia,
    required this.tomados,
    required this.agendados,
  });

  // 'tomados' já vem filtrado por DatabaseHelper.getDosesTomadas() (WHERE
  // tomado = 1) — uma dose que o usuário cancelou no alarme (tomado = 0)
  // nunca entra nessa contagem, então cai automaticamente aqui em
  // 'esquecidos' junto com as doses que nunca tiveram resposta.
  int get esquecidos => (agendados - tomados) < 0 ? 0 : agendados - tomados;

  double get adesao =>
      agendados == 0 ? 1.0 : (tomados / agendados).clamp(0.0, 1.0);
}

const List<String> _diasSemanaAbrev = [
  'Seg',
  'Ter',
  'Qua',
  'Qui',
  'Sex',
  'Sáb',
  'Dom',
];

/// Tela de Relatório de Adesão: resumo dos últimos 7 dias de tratamento,
/// acessível a partir de Ajustes. Segue a mesma identidade visual do resto
/// do SeniCare — fundo por tema (Default/Light/Dark) e cards em
/// Glassmorphism (GlassCard) — em vez de introduzir um estilo novo.
class ReportScreen extends StatefulWidget {
  final String currentTheme;
  final double fontSizeMultiplier;

  const ReportScreen({
    super.key,
    required this.currentTheme,
    required this.fontSizeMultiplier,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _loading = true;
  List<_DiaRelatorio> _dias = const [];

  @override
  void initState() {
    super.initState();
    _carregarRelatorio();
  }

  Future<void> _carregarRelatorio() async {
    final List<Map<String, dynamic>> medicamentos = await DatabaseHelper()
        .getMedicamentos();
    final List<Map<String, dynamic>> doses = await DatabaseHelper()
        .getDosesTomadas();

    final Map<String, int> tomadosPorDia = {};
    for (final dose in doses) {
      final String? dataTomada = dose['data_tomada'] as String?;
      if (dataTomada == null || dataTomada.length < 10) continue;
      final String chave = dataTomada.substring(0, 10);
      tomadosPorDia[chave] = (tomadosPorDia[chave] ?? 0) + 1;
    }

    final DateTime agora = DateTime.now();
    final DateTime hoje = DateTime(agora.year, agora.month, agora.day);

    final List<_DiaRelatorio> resultado = [];
    for (int i = 6; i >= 0; i--) {
      final DateTime dia = hoje.subtract(Duration(days: i));
      final String chave = dia.toIso8601String().substring(0, 10);

      int agendados = 0;
      for (final med in medicamentos) {
        agendados += _dosesEsperadasNoDia(med, dia);
      }

      resultado.add(
        _DiaRelatorio(
          dia: dia,
          tomados: tomadosPorDia[chave] ?? 0,
          agendados: agendados,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _dias = resultado;
        _loading = false;
      });
    }
  }

  /// Quantas doses de [med] eram esperadas em [dia]. Para 'Horários Fixos',
  /// conta os horários cadastrados nos dias da semana selecionados — exato.
  /// Para 'Intervalo', aproxima por 24h / intervalo_horas — o horário exato
  /// de cada dose desliza dia a dia a partir da primeira, então replicar a
  /// simulação exata (feita em HomeScreen) só pra um relatório resumido não
  /// compensa a complexidade extra.
  int _dosesEsperadasNoDia(Map<String, dynamic> med, DateTime dia) {
    try {
      final String? dataInicioStr = med['data_inicio'] as String?;
      if (dataInicioStr == null) return 0;

      final DateTime inicio = DateTime.parse(dataInicioStr);
      final DateTime dataInicio = DateTime(
        inicio.year,
        inicio.month,
        inicio.day,
      );
      if (dia.isBefore(dataInicio)) return 0;

      final String? dataFimStr = med['data_fim'] as String?;
      if (dataFimStr != null) {
        final DateTime fim = DateTime.parse(dataFimStr);
        final DateTime dataFim = DateTime(fim.year, fim.month, fim.day);
        if (dia.isAfter(dataFim)) return 0;
      }

      final String tipo =
          (med['frequencia_tipo'] as String?) ?? 'Horários Fixos';

      if (tipo == 'Horários Fixos') {
        final String diasSemana = (med['dias_semana'] as String?) ?? '';
        final String nomeDia = _diasSemanaAbrev[dia.weekday - 1];
        final Set<String> diasList = diasSemana
            .split(',')
            .map((d) => d.trim())
            .toSet();
        final bool ocorreNoDia =
            diasSemana == 'Todos os dias' || diasList.contains(nomeDia);
        if (!ocorreNoDia) return 0;

        final String horario = (med['horario'] as String?) ?? '';
        if (horario.trim().isEmpty) return 0;
        return horario.split(',').length;
      }

      final int? intervalo = med['intervalo_horas'] as int?;
      if (intervalo == null || intervalo <= 0) return 0;
      return (24 / intervalo).round().clamp(1, 24);
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.currentTheme == 'Dark';
    final bool useWhiteText =
        widget.currentTheme == 'Default' || widget.currentTheme == 'Dark';
    final Color textColor = useWhiteText ? Colors.white : Colors.black87;
    final Color subTextColor = useWhiteText ? Colors.white70 : Colors.black54;
    final double m = widget.fontSizeMultiplier;

    BoxDecoration backgroundDecoration;
    if (widget.currentTheme == 'Default') {
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

    return Container(
      decoration: backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          title: Text(
            'Relatório de Adesão',
            style: GoogleFonts.greatVibes(fontSize: 30.0 * m, color: textColor),
          ),
        ),
        body: SafeArea(
          top: false,
          child: _loading
              ? Center(child: CircularProgressIndicator(color: textColor))
              : ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.all(24.0 * m),
                  children: [
                    _buildAdesaoSemanal(isDark, textColor, subTextColor, m),
                    SizedBox(height: 24.0 * m),
                    Text(
                      'Últimos 7 dias',
                      style: TextStyle(
                        fontSize: 20.0 * m,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 12.0 * m),
                    ..._dias.reversed.map(
                      (dia) => _buildDiaCard(
                        dia,
                        isDark,
                        textColor,
                        subTextColor,
                        m,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAdesaoSemanal(
    bool isDark,
    Color textColor,
    Color subTextColor,
    double m,
  ) {
    final int totalTomados = _dias.fold(0, (s, d) => s + d.tomados);
    final int totalAgendados = _dias.fold(0, (s, d) => s + d.agendados);
    final double adesao = totalAgendados == 0
        ? 0.0
        : (totalTomados / totalAgendados).clamp(0.0, 1.0);
    final int percentual = (adesao * 100).round();

    final Color corAnel = adesao >= 0.8
        ? Colors.greenAccent
        : (adesao >= 0.5 ? Colors.orangeAccent : Colors.redAccent);

    return GlassCard(
      isDark: isDark,
      borderRadius: 12.0,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.all(24.0 * m),
        child: Column(
          children: [
            Text(
              'Adesão Semanal',
              style: TextStyle(
                fontSize: 18.0 * m,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 20.0 * m),
            SizedBox(
              width: 140.0 * m,
              height: 140.0 * m,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: adesao,
                      strokeWidth: 12.0,
                      backgroundColor: subTextColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(corAnel),
                    ),
                  ),
                  Text(
                    '$percentual%',
                    style: TextStyle(
                      fontSize: 32.0 * m,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.0 * m),
            Text(
              totalAgendados == 0
                  ? 'Nenhuma dose agendada nos últimos 7 dias.'
                  : '$totalTomados de $totalAgendados doses tomadas nos últimos 7 dias',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.0 * m, color: subTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaCard(
    _DiaRelatorio dia,
    bool isDark,
    Color textColor,
    Color subTextColor,
    double m,
  ) {
    final DateTime hoje = DateTime.now();
    final bool isHoje =
        dia.dia.year == hoje.year &&
        dia.dia.month == hoje.month &&
        dia.dia.day == hoje.day;
    final String rotuloDia = isHoje
        ? 'Hoje'
        : _diasSemanaAbrev[dia.dia.weekday - 1];

    return GlassCard(
      margin: EdgeInsets.only(bottom: 12.0 * m),
      isDark: isDark,
      borderRadius: 10.0,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.all(16.0 * m),
        child: Row(
          children: [
            SizedBox(
              width: 56.0 * m,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotuloDia,
                    style: TextStyle(
                      fontSize: 16.0 * m,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM').format(dia.dia),
                    style: TextStyle(fontSize: 12.0 * m, color: subTextColor),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _buildMetrica(
              icon: Icons.check_circle,
              cor: Colors.greenAccent,
              valor: dia.tomados,
              rotulo: 'Tomados',
              subTextColor: subTextColor,
              m: m,
            ),
            SizedBox(width: 20.0 * m),
            _buildMetrica(
              icon: Icons.cancel,
              cor: Colors.redAccent,
              valor: dia.esquecidos,
              rotulo: 'Esquecidos',
              subTextColor: subTextColor,
              m: m,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrica({
    required IconData icon,
    required Color cor,
    required int valor,
    required String rotulo,
    required Color subTextColor,
    required double m,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: cor, size: 18.0 * m),
            SizedBox(width: 4.0 * m),
            Text(
              '$valor',
              style: TextStyle(
                fontSize: 16.0 * m,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
          ],
        ),
        Text(
          rotulo,
          style: TextStyle(fontSize: 11.0 * m, color: subTextColor),
        ),
      ],
    );
  }
}
