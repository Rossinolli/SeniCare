// Tela de Histórico: mostra um calendário marcando os dias em que o usuário
// tomou remédio, a lista de doses do dia escolhido e um resumo de como está
// indo o tratamento.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'database_helper.dart';
import 'glass_card.dart';

class HistoryScreen extends StatefulWidget {
  final String currentTheme;
  final double fontSizeMultiplier;
  final bool isActive;

  const HistoryScreen({
    super.key,
    required this.currentTheme,
    required this.fontSizeMultiplier,
    this.isActive = false,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _selectedDosesDetails = [];
  Set<DateTime> _dosesTomadas = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Métricas do Resumo do Tratamento.
  Map<String, int> _dosesPorMedicamento = {};
  String _tempoRestanteTexto = 'Uso Contínuo';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadDosesForSelectedDay(_selectedDay!); // Load doses for today initially
    _loadHistory();
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadHistory();
      _loadDosesForSelectedDay(_selectedDay!); // Also update selected day doses
    }
  }

  Future<void> _loadHistory() async {
    final dbHelper = DatabaseHelper();
    final doses = await dbHelper.getDosesTomadas();
    final Set<DateTime> dates = {};
    for (var dose in doses) {
      final dateStr = dose['data_tomada'] as String;
      // Converte a data para UTC para evitar problemas de fuso horário na comparação
      final date = DateTime.parse(dateStr);
      dates.add(DateTime.utc(date.year, date.month, date.day));
    }

    final medicamentos = await dbHelper.getMedicamentos();
    final String tempoRestante = _calcularTempoRestante(medicamentos);

    // Quebra de 'Doses Tomadas' por medicamento (em vez de um total genérico),
    // reaproveitando os dados já carregados aqui — sem precisar de uma nova
    // consulta/JOIN no banco.
    final Map<int, String> nomesPorId = {
      for (final med in medicamentos)
        if (med['id'] != null)
          med['id'] as int: (med['nome'] as String? ?? 'Medicamento'),
    };
    final Map<String, int> contagemPorMedicamento = {};
    for (final dose in doses) {
      final int? medId = dose['medicamento_id'] as int?;
      final String nome =
          (medId != null ? nomesPorId[medId] : null) ?? 'Medicamento removido';
      contagemPorMedicamento[nome] = (contagemPorMedicamento[nome] ?? 0) + 1;
    }

    if (mounted) {
      setState(() {
        _dosesTomadas = dates;
        _dosesPorMedicamento = contagemPorMedicamento;
        _tempoRestanteTexto = tempoRestante;
      });
    }
  }

  /// Se ao menos um medicamento tem data de fim, mostra quantos dias faltam
  /// até o mais próximo de terminar (a informação mais urgente/acionável).
  /// Só mostra 'Uso Contínuo' quando NENHUM medicamento tem data de fim.
  String _calcularTempoRestante(List<Map<String, dynamic>> medicamentos) {
    if (medicamentos.isEmpty) return 'Nenhum tratamento cadastrado';

    DateTime? menorDataFim;
    bool existeAlgumComDataFim = false;
    for (final med in medicamentos) {
      if (med['data_fim'] != null) {
        existeAlgumComDataFim = true;
        final dataFim = DateTime.parse(med['data_fim']);
        if (menorDataFim == null || dataFim.isBefore(menorDataFim)) {
          menorDataFim = dataFim;
        }
      }
    }

    if (!existeAlgumComDataFim) return 'Uso Contínuo';

    final DateTime hoje = DateTime.now();
    final DateTime hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final int diasRestantes = menorDataFim!.difference(hojeSemHora).inDays;
    if (diasRestantes <= 0) return 'Tratamento concluído';
    return 'Faltam $diasRestantes dia${diasRestantes == 1 ? '' : 's'}';
  }

  Future<void> _loadDosesForSelectedDay(DateTime day) async {
    final dbHelper = DatabaseHelper();
    final String formattedDate = day.toIso8601String().substring(0, 10);
    final doses = await dbHelper.getDosesWithMedicationDetailsByDate(
      formattedDate,
    );

    if (mounted) {
      setState(() {
        _selectedDosesDetails = doses;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cores que se adaptam ao tema
    final isDark = widget.currentTheme == 'Dark';
    final useWhiteText = widget.currentTheme == 'Default' || isDark;
    final textColor = useWhiteText ? Colors.white : Colors.black87;
    final subTextColor = useWhiteText ? Colors.white70 : Colors.black54;
    final headerColor = useWhiteText ? Colors.white : const Color(0xFF0D47A1);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Esta tela não tem uma AppBar de verdade (nenhuma aba do app tem —
          // MainNavigator já cuida da navegação principal), então o botão de
          // relatório vive aqui, no mesmo lugar visual onde uma AppBar action
          // apareceria: canto superior direito do cabeçalho da tela.
          Row(
            children: [
              Expanded(
                child: Text(
                  'Meu Progresso',
                  // Mesma família tipográfica do 'Olá' da Home (GoogleFonts
                  // greatVibes), para os títulos das telas terem identidade
                  // visual coesa. textScaler.noScaling: fontes de caligrafia
                  // têm laços/curvas que quebram feio se a escala do sistema
                  // esticar demais o texto.
                  textScaler: TextScaler.noScaling,
                  style: GoogleFonts.greatVibes(
                    fontSize: 36.0 * widget.fontSizeMultiplier,
                    color: textColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    _abrirResumoTratamento(context, textColor, subTextColor),
                icon: Icon(
                  Icons.analytics_outlined,
                  color: textColor,
                  size: 28.0 * widget.fontSizeMultiplier,
                ),
                tooltip: 'Resumo do Tratamento',
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          _buildCalendar(headerColor, textColor, subTextColor),
          const SizedBox(height: 24.0),
          _buildDosesList(
            textColor,
            subTextColor,
          ), // New widget to display doses
          _buildSummaryCard(textColor, subTextColor),
        ],
      ),
    );
  }

  Widget _buildCalendar(
    Color headerColor,
    Color textColor,
    Color subTextColor,
  ) {
    return GlassCard(
      isDark: widget.currentTheme == 'Dark',
      borderRadius: 12.0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          locale: 'pt_BR',
          focusedDay: _focusedDay,
          calendarFormat: CalendarFormat.month,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            _loadDosesForSelectedDay(
              selectedDay,
            ); // Load doses for the newly selected day
            setState(() {
              // Update selected day and focused day
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          // Altura das linhas/cabeçalho de dias escalada junto com a fonte:
          // sem isso, o texto crescia (fontSizeMultiplier) mas a caixa que o
          // contém continuava do tamanho padrão, e a célula estourava.
          rowHeight: 48.0 * widget.fontSizeMultiplier,
          daysOfWeekHeight: 24.0 * widget.fontSizeMultiplier,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            leftChevronIcon: Icon(Icons.chevron_left, color: headerColor),
            rightChevronIcon: Icon(Icons.chevron_right, color: headerColor),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            // Weekend days should also be in subTextColor for consistency
            weekdayStyle: TextStyle(
              color: subTextColor,
              fontSize: 13.0 * widget.fontSizeMultiplier,
            ),
            weekendStyle: TextStyle(
              color: subTextColor.withValues(alpha: 0.7),
              fontSize: 13.0 * widget.fontSizeMultiplier,
            ),
          ),
          calendarStyle: CalendarStyle(
            defaultTextStyle: TextStyle(
              color: textColor,
              fontSize: 15.0 * widget.fontSizeMultiplier,
            ),
            weekendTextStyle: TextStyle(
              color: textColor,
              fontSize: 15.0 * widget.fontSizeMultiplier,
            ),
            outsideTextStyle: TextStyle(
              color: subTextColor.withValues(alpha: 0.5),
              fontSize: 15.0 * widget.fontSizeMultiplier,
            ),
            todayTextStyle: TextStyle(
              color: textColor,
              fontSize: 15.0 * widget.fontSizeMultiplier,
            ),
            selectedTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 15.0 * widget.fontSizeMultiplier,
            ),
            todayDecoration: BoxDecoration(
              color:
                  (widget.currentTheme == 'Light'
                          ? const Color(0xFF0D47A1)
                          : const Color(0xFF00B4DB))
                      .withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: widget.currentTheme == 'Light'
                  ? const Color(0xFF0D47A1)
                  : const Color(0xFF00B4DB),
              shape: BoxShape.circle,
              // Call _loadDosesForSelectedDay here
            ),
          ),
          calendarBuilders: CalendarBuilders(
            // FittedBox: em telas estreitas, o título do mês (ex.: 'setembro
            // de 2026') com a fonte em 110% não cabia numa linha e o
            // table_calendar quebrava em 2 — só que a altura reservada para o
            // cabeçalho é fixa para 1 linha, então a 2ª linha vazava por cima
            // da fileira de dias da semana logo abaixo. Em vez de quebrar
            // linha, o FittedBox encolhe o texto até caber.
            headerTitleBuilder: (context, day) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                DateFormat.yMMMM('pt_BR').format(day),
                maxLines: 1,
                style: TextStyle(
                  color: headerColor,
                  fontSize: 20.0 * widget.fontSizeMultiplier,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            markerBuilder: (context, day, events) {
              final utcDay = DateTime.utc(day.year, day.month, day.day);
              if (_dosesTomadas.contains(utcDay)) {
                return const Positioned(
                  bottom: 1,
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16.0,
                  ),
                );
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDosesList(Color textColor, Color subTextColor) {
    if (_selectedDosesDetails.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Center(
          child: Text(
            _selectedDay == null
                ? 'Selecione um dia para ver as doses.'
                : 'Nenhuma dose registrada para ${(_selectedDay!).day}/${(_selectedDay!).month}.',
            style: TextStyle(
              fontSize: 16.0 * widget.fontSizeMultiplier,
              color: subTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            'Doses em ${(_selectedDay!).day}/${(_selectedDay!).month}:',
            style: TextStyle(
              fontSize: 20.0 * widget.fontSizeMultiplier,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        ..._selectedDosesDetails.map((dose) {
          final DateTime doseDateTime = DateTime.parse(dose['data_tomada']);
          final String time =
              '${doseDateTime.hour.toString().padLeft(2, '0')}:${doseDateTime.minute.toString().padLeft(2, '0')}';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              '• ${dose['nome']} às $time',
              style: TextStyle(
                fontSize: 16.0 * widget.fontSizeMultiplier,
                color: subTextColor,
              ),
            ),
          );
        }),
        const SizedBox(height: 24.0),
      ],
    );
  }

  Widget _buildSummaryCard(Color textColor, Color subTextColor) {
    return GlassCard(
      width: double.infinity,
      isDark: widget.currentTheme == 'Dark',
      borderRadius: 12.0,
      // Trocamos a Row pelo Text.rich com TextSpan para quebrar a linha sozinho!
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text.rich(
          TextSpan(
            text: 'Dias seguindo o tratamento: ',
            style: TextStyle(
              fontSize: 18.0 * widget.fontSizeMultiplier,
              color: subTextColor,
            ),
            children: [
              TextSpan(
                text: '${_dosesTomadas.length}',
                style: TextStyle(
                  fontSize: 22.0 * widget.fontSizeMultiplier,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _abrirResumoTratamento(
    BuildContext context,
    Color textColor,
    Color subTextColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildResumoTratamentoSheet(textColor, subTextColor),
    );
  }

  Widget _buildResumoTratamentoSheet(Color textColor, Color subTextColor) {
    final double m = widget.fontSizeMultiplier;
    final bool isDefault = widget.currentTheme == 'Default';
    final bool isDark = widget.currentTheme == 'Dark';

    // Este app não usa o Theme.of(context) padrão do Flutter para cores — ele
    // tem o próprio sistema de tema (Default/Light/Dark) via 'currentTheme',
    // já usado em toda a HistoryScreen. Para o relatório ficar visualmente
    // coerente com o resto do app (em vez de destoar no tema Default, que é
    // o gradiente azul e não tem equivalente no ThemeData padrão), sigo o
    // mesmo padrão de tema já estabelecido aqui.
    final BoxDecoration sheetDecoration;
    if (isDefault) {
      sheetDecoration = const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF00B4DB)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      );
    } else if (isDark) {
      sheetDecoration = const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      );
    } else {
      sheetDecoration = BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
      );
    }

    return SafeArea(
      child: Container(
        width: double.infinity,
        decoration: sheetDecoration,
        padding: EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48.0,
                height: 5.0,
                margin: const EdgeInsets.only(bottom: 20.0),
                decoration: BoxDecoration(
                  color: subTextColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3.0),
                ),
              ),
            ),
            Text(
              'Resumo do Tratamento',
              style: TextStyle(
                fontSize: 26.0 * m,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 20.0 * m),
            _buildMetricCard(
              icon: Icons.medication_liquid,
              label: 'Doses Tomadas',
              valueLines: _dosesPorMedicamento.isEmpty
                  ? const ['Nenhuma dose registrada ainda']
                  : _dosesPorMedicamento.entries
                        .map(
                          (e) =>
                              '${e.key}: ${e.value} dose${e.value == 1 ? '' : 's'}',
                        )
                        .toList(),
              textColor: textColor,
              subTextColor: subTextColor,
              m: m,
            ),
            SizedBox(height: 12.0 * m),
            _buildMetricCard(
              icon: Icons.verified,
              label: 'Frequência Correta',
              value:
                  '${_dosesTomadas.length} dia${_dosesTomadas.length == 1 ? '' : 's'}',
              textColor: textColor,
              subTextColor: subTextColor,
              m: m,
            ),
            SizedBox(height: 12.0 * m),
            _buildMetricCard(
              icon: Icons.hourglass_bottom,
              label: 'Tempo Restante',
              value: _tempoRestanteTexto,
              textColor: textColor,
              subTextColor: subTextColor,
              m: m,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    String? value,
    // Quando informado (ex.: quebra de doses por medicamento), renderiza uma
    // linha por item em vez de um único valor grande — 'value' é ignorado.
    List<String>? valueLines,
    required Color textColor,
    required Color subTextColor,
    required double m,
  }) {
    assert(value != null || valueLines != null);
    final bool useWhiteText =
        widget.currentTheme == 'Default' || widget.currentTheme == 'Dark';
    final Color iconAccent = widget.currentTheme == 'Light'
        ? const Color(0xFF0D47A1)
        : const Color(0xFF00B4DB);

    return GlassCard(
      width: double.infinity,
      isDark: widget.currentTheme == 'Dark',
      borderRadius: 10.0,
      child: Padding(
        padding: EdgeInsets.all(18.0 * m),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.0 * m),
              decoration: BoxDecoration(
                color: iconAccent.withValues(alpha: useWhiteText ? 0.3 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: useWhiteText ? Colors.white : iconAccent,
                size: 26.0 * m,
              ),
            ),
            SizedBox(width: 16.0 * m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 14.0 * m, color: subTextColor),
                  ),
                  const SizedBox(height: 2.0),
                  if (valueLines != null)
                    ...valueLines.map(
                      (linha) => Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          linha,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.0 * m,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      value!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20.0 * m,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
