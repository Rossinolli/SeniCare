// Aba Histórico: calendário com as doses de cada dia e a lista dos remédios
// já utilizados. Pedido dos orientadores: um remédio removido continua
// aparecendo aqui com todas as doses que foram registradas — remover não
// apaga o passado.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/componentes.dart';
import '../../core/estado.dart';
import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../domain/agenda.dart';
import '../../domain/medicamento.dart';
import '../../services/notification_service.dart';
import '../inicio/inicio_screen.dart'
    show aparenciaDoStatus, mostrarAcoesDaDose;
import 'relatorio_screen.dart';

class HistoricoScreen extends ConsumerStatefulWidget {
  const HistoricoScreen({super.key});

  @override
  ConsumerState<HistoricoScreen> createState() => _HistoricoState();
}

class _HistoricoState extends ConsumerState<HistoricoScreen> {
  DateTime _diaSelecionado = inicioDoDia(DateTime.now());
  DateTime _mesEmFoco = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ConteudoResponsivo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const TituloCaligrafico('Meu histórico'),
              const SizedBox(height: 16),
              Cartao(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RelatorioScreen()),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: 32,
                      color: context.cores.destaque,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Relatório de adesão',
                            style: context.textos.titleMedium,
                          ),
                          Text(
                            'Últimos 7 dias, para levar ao médico',
                            style: context.textos.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.cores.textoSecundario,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _calendario(),
              const SizedBox(height: 8),
              const _Legenda(),
              CabecalhoSecao(dataPorExtenso(_diaSelecionado)),
              _DosesDoDia(dia: _diaSelecionado),
              const CabecalhoSecao('Remédios já utilizados'),
              const _RemediosJaUtilizados(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _calendario() {
    final c = context.cores;
    final Map<String, ({int tomadas, int naoTomadas})> resumo =
        ref.watch(resumoPorDiaProvider).value ?? const {};
    final TextStyle base = context.textos.bodyLarge!;
    return Cartao(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: TableCalendar<void>(
        locale: 'pt_BR',
        firstDay: DateTime(2020),
        lastDay: DateTime(2035, 12, 31),
        focusedDay: _mesEmFoco,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        availableGestures: AvailableGestures.horizontalSwipe,
        rowHeight: 52,
        daysOfWeekHeight: 28,
        selectedDayPredicate: (d) => isSameDay(d, _diaSelecionado),
        onDaySelected: (sel, foco) => setState(() {
          _diaSelecionado = inicioDoDia(sel);
          _mesEmFoco = foco;
        }),
        onPageChanged: (foco) => _mesEmFoco = foco,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextFormatter: (d, _) =>
              capitalizar(DateFormat.yMMMM('pt_BR').format(d)),
          titleTextStyle: context.textos.titleMedium!,
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: c.texto,
            size: 30,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: c.texto,
            size: 30,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          dowTextFormatter: (d, _) =>
              capitalizar(DateFormat.E('pt_BR').format(d).replaceAll('.', '')),
          weekdayStyle: context.textos.labelMedium!.copyWith(
            color: c.textoSecundario,
          ),
          weekendStyle: context.textos.labelMedium!.copyWith(
            color: c.textoSecundario,
          ),
        ),
        calendarStyle: CalendarStyle(
          defaultTextStyle: base,
          weekendTextStyle: base,
          outsideTextStyle: base.copyWith(
            color: c.textoSecundario.withValues(alpha: 0.6),
          ),
          todayDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.destaque, width: 2),
          ),
          todayTextStyle: base.copyWith(fontWeight: FontWeight.w700),
          selectedDecoration: BoxDecoration(
            color: c.destaque,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: base.copyWith(
            color: c.sobreDestaque,
            fontWeight: FontWeight.w700,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, dia, _) {
            final r = resumo[chaveDoDia(dia)];
            if (r == null) return null;
            final Color cor = r.naoTomadas == 0
                ? c.sucesso
                : (r.tomadas == 0 ? c.perigo : c.atencao);
            return Positioned(
              bottom: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    Widget item(Color cor, String texto) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(texto, style: context.textos.bodySmall),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [
        item(c.sucesso, 'Tudo tomado'),
        item(c.atencao, 'Parte tomada'),
        item(c.perigo, 'Não tomado'),
      ],
    );
  }
}

/// Doses de um dia: as programadas (com status) de todos os remédios —
/// inclusive os já removidos — e respostas de remédios antigos que não
/// existem mais no cadastro.
class _DosesDoDia extends ConsumerWidget {
  final DateTime dia;

  const _DosesDoDia({required this.dia});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Medicamento>? meds = ref.watch(todosMedicamentosProvider).value;
    final List<RegistroDose>? registros = ref
        .watch(registrosDoDiaProvider(dia))
        .value;
    if (meds == null || registros == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final DateTime agora = ref.watch(relogioProvider).value ?? DateTime.now();
    final AgendaDoDia agenda = montarAgenda(
      dia: dia,
      medicamentos: meds,
      registros: registros,
      agora: agora,
    );
    final Set<int> ids = {for (final m in meds) m.id};
    final List<RegistroDose> orfaos = registros
        .where((r) => r.medicamentoId == null || !ids.contains(r.medicamentoId))
        .toList();

    if (agenda.doses.isEmpty && orfaos.isEmpty) {
      return Cartao(
        child: Text(
          'Nenhuma dose neste dia.',
          style: context.textos.bodyLarge?.copyWith(
            color: context.cores.textoSecundario,
          ),
        ),
      );
    }
    final bool hoje = isSameDay(dia, agora);
    return Cartao(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (final d in agenda.doses)
            _LinhaDose(
              horario: hhmm(d.horario),
              nome: d.medicamento.nome,
              removido: d.medicamento.arquivado,
              aparencia: _aparenciaHistorico(context, d, hoje),
              onTap: hoje && !d.medicamento.arquivado
                  ? () => mostrarAcoesDaDose(context, ref, d)
                  : null,
            ),
          for (final r in orfaos)
            _LinhaDose(
              horario: hhmm(r.dataTomada),
              nome: r.nomeMedicamento ?? 'Remédio removido',
              removido: true,
              aparencia: r.tomado
                  ? (
                      Icons.check_circle_rounded,
                      context.cores.sucesso,
                      'Tomada',
                    )
                  : (Icons.cancel_rounded, context.cores.perigo, 'Não tomada'),
            ),
        ],
      ),
    );
  }

  (IconData, Color, String) _aparenciaHistorico(
    BuildContext context,
    DoseDoDia d,
    bool hoje,
  ) {
    // Em dias passados, "atrasada" significa esquecida.
    if (!hoje && d.status == StatusDose.atrasada) {
      return (Icons.error_rounded, context.cores.atencao, 'Esquecida');
    }
    return aparenciaDoStatus(context, d);
  }
}

class _LinhaDose extends StatelessWidget {
  final String horario;
  final String nome;
  final bool removido;
  final (IconData, Color, String) aparencia;
  final VoidCallback? onTap;

  const _LinhaDose({
    required this.horario,
    required this.nome,
    required this.removido,
    required this.aparencia,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (IconData icone, Color cor, String rotulo) = aparencia;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: MediaQuery.textScalerOf(context).scale(60),
              child: Text(
                horario,
                maxLines: 1,
                softWrap: false,
                style: context.textos.titleSmall,
              ),
            ),
            Icon(icone, color: cor, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    removido ? '$nome (removido)' : nome,
                    style: context.textos.bodyLarge,
                  ),
                  Text(
                    rotulo,
                    style: context.textos.bodySmall?.copyWith(color: cor),
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

/// Remédios removidos ou com tratamento já terminado, com o período e as
/// doses tomadas.
class _RemediosJaUtilizados extends ConsumerWidget {
  const _RemediosJaUtilizados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Medicamento> todos =
        ref.watch(todosMedicamentosProvider).value ?? const [];
    final Map<int, int> totais =
        ref.watch(totalTomadasPorMedicamentoProvider).value ?? const {};
    final DateTime hoje = inicioDoDia(DateTime.now());
    final List<Medicamento> utilizados =
        todos
            .where(
              (m) =>
                  m.arquivado ||
                  (m.dataFim != null && m.dataFim!.isBefore(hoje)),
            )
            .toList()
          ..sort((a, b) {
            final DateTime fa = a.arquivadoEm ?? a.dataFim!;
            final DateTime fb = b.arquivadoEm ?? b.dataFim!;
            return fb.compareTo(fa);
          });

    if (utilizados.isEmpty) {
      return Cartao(
        child: Text(
          'Quando um tratamento terminar ou você remover um remédio, ele aparece aqui com todas as doses registradas.',
          style: context.textos.bodyMedium?.copyWith(
            color: context.cores.textoSecundario,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final m in utilizados) ...[
          Cartao(
            child: Row(
              children: [
                AvatarRemedio(fotoPath: m.fotoPath, raio: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.nome, style: context.textos.titleMedium),
                      Text(_periodo(m), style: context.textos.bodySmall),
                      Text(
                        '${totais[m.id] ?? 0} '
                        '${(totais[m.id] ?? 0) == 1 ? 'dose tomada' : 'doses tomadas'}',
                        style: context.textos.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (m.arquivado)
                  TextButton(
                    onPressed: () async {
                      await ref.read(repositorioProvider).restaurar(m.id);
                      await NotificationService().sincronizarAlarmes();
                      if (context.mounted) {
                        avisar(context, 'De volta à lista: ${m.nome}');
                      }
                    },
                    child: const Text('Restaurar'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  String _periodo(Medicamento m) {
    final String inicio = m.dataInicio == null ? '—' : dataCurta(m.dataInicio!);
    final DateTime fim = m.arquivadoEm ?? m.dataFim!;
    return '$inicio a ${dataCurta(fim)}${m.arquivado ? ' · removido' : ' · concluído'}';
  }
}
