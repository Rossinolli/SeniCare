// Relatório de Adesão: percentual de doses tomadas nos últimos 7 dias e o
// detalhe dia a dia, com a MESMA regra de status da agenda (doses de hoje
// que ainda não chegaram não contam como esquecidas). Pode ser
// compartilhado em texto com o médico ou o cuidador.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/componentes.dart';
import '../../core/estado.dart';
import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../domain/agenda.dart';
import '../../domain/medicamento.dart';

class _Dia {
  final DateTime dia;
  final AgendaDoDia agenda;

  const _Dia(this.dia, this.agenda);
}

final _relatorioProvider = FutureProvider.autoDispose<List<_Dia>>((ref) async {
  // Recalcula quando remédios ou respostas mudam.
  final List<Medicamento> meds = await ref.watch(
    todosMedicamentosProvider.future,
  );
  ref.watch(resumoPorDiaProvider);
  final DateTime agora = DateTime.now();
  final DateTime hoje = inicioDoDia(agora);
  final DateTime inicio = DateTime(hoje.year, hoje.month, hoje.day - 6);
  final List<RegistroDose> registros = await ref
      .read(repositorioProvider)
      .registrosEntre(inicio, hoje);
  return [
    for (int i = 6; i >= 0; i--)
      () {
        final DateTime dia = DateTime(hoje.year, hoje.month, hoje.day - i);
        final String chave = chaveDoDia(dia);
        return _Dia(
          dia,
          montarAgenda(
            dia: dia,
            medicamentos: meds,
            registros: registros.where((r) => r.dia == chave).toList(),
            agora: agora,
          ),
        );
      }(),
  ];
});

class RelatorioScreen extends ConsumerWidget {
  const RelatorioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<_Dia>> dias = ref.watch(_relatorioProvider);
    final c = context.cores;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de adesão'),
        backgroundColor: c.fundoGradiente != null ? azulMarcaEscuro : c.fundo,
        actions: [
          if (dias.hasValue)
            IconButton(
              tooltip: 'Compartilhar',
              icon: const Icon(Icons.share_rounded),
              onPressed: () => _compartilhar(dias.value!),
            ),
        ],
      ),
      body: FundoDoTema(
        child: dias.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (lista) => ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              ConteudoResponsivo(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Anel(dias: lista),
                    const CabecalhoSecao('Dia a dia'),
                    for (final d in lista.reversed) ...[
                      _LinhaDia(dia: d),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _compartilhar(List<_Dia> dias) async {
    final int tomadas = dias.fold(0, (s, d) => s + d.agenda.tomadas);
    final int total = dias.fold(0, (s, d) => s + d.agenda.consideradas);
    final StringBuffer texto = StringBuffer()
      ..writeln('Relatório de adesão — SeniCare')
      ..writeln(
        'Período: ${dataCurta(dias.first.dia)} a ${dataCurta(dias.last.dia)}',
      )
      ..writeln(
        total == 0
            ? 'Nenhuma dose prevista no período.'
            : 'Doses tomadas: $tomadas de $total (${(tomadas * 100 / total).round()}%)',
      )
      ..writeln();
    for (final d in dias) {
      if (d.agenda.consideradas == 0) continue;
      texto.writeln(
        '${capitalizar(diaCurto(d.dia))}: ${d.agenda.tomadas} tomada(s), '
        '${d.agenda.perdidas} não tomada(s)',
      );
      for (final dose in d.agenda.doses.where((x) => x.devida)) {
        final String status = switch (dose.status) {
          StatusDose.tomada => 'tomada',
          StatusDose.naoTomada => 'não tomada',
          _ => 'esquecida',
        };
        texto.writeln(
          '  • ${hhmm(dose.horario)} ${dose.medicamento.nome} — $status',
        );
      }
    }
    await SharePlus.instance.share(ShareParams(text: texto.toString()));
  }
}

class _Anel extends StatelessWidget {
  final List<_Dia> dias;

  const _Anel({required this.dias});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final int tomadas = dias.fold(0, (s, d) => s + d.agenda.tomadas);
    final int total = dias.fold(0, (s, d) => s + d.agenda.consideradas);
    final double adesao = total == 0 ? 0 : tomadas / total;
    final Color cor = adesao >= 0.8
        ? c.sucesso
        : (adesao >= 0.5 ? c.atencao : c.perigo);
    return Cartao(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Últimos 7 dias', style: context.textos.titleMedium),
          const SizedBox(height: 18),
          Semantics(
            label: 'Adesão de ${(adesao * 100).round()} por cento',
            child: SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: total == 0 ? 0 : adesao,
                      strokeWidth: 14,
                      backgroundColor: c.suave,
                      color: cor,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    total == 0 ? '—' : '${(adesao * 100).round()}%',
                    style: context.textos.displaySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            total == 0
                ? 'Nenhuma dose prevista até agora.'
                : '$tomadas de $total doses tomadas',
            textAlign: TextAlign.center,
            style: context.textos.bodyLarge,
          ),
          if (total > 0)
            Text(
              adesao >= 0.8
                  ? 'Ótimo! Continue assim.'
                  : 'Vale conversar com o médico ou o cuidador.',
              textAlign: TextAlign.center,
              style: context.textos.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _LinhaDia extends StatelessWidget {
  final _Dia dia;

  const _LinhaDia({required this.dia});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final bool hoje = isSameDayLocal(dia.dia, DateTime.now());
    return Cartao(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hoje ? 'Hoje' : capitalizar(diaCurto(dia.dia)),
              style: context.textos.titleSmall,
            ),
          ),
          _Metrica(
            icone: Icons.check_circle_rounded,
            cor: c.sucesso,
            valor: dia.agenda.tomadas,
            rotulo: 'tomadas',
          ),
          const SizedBox(width: 18),
          _Metrica(
            icone: Icons.cancel_rounded,
            cor: c.perigo,
            valor: dia.agenda.perdidas,
            rotulo: 'perdidas',
          ),
        ],
      ),
    );
  }
}

bool isSameDayLocal(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _Metrica extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final int valor;
  final String rotulo;

  const _Metrica({
    required this.icone,
    required this.cor,
    required this.valor,
    required this.rotulo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: cor, size: 20),
            const SizedBox(width: 4),
            Text('$valor', style: context.textos.titleMedium),
          ],
        ),
        Text(rotulo, style: context.textos.bodySmall),
      ],
    );
  }
}
