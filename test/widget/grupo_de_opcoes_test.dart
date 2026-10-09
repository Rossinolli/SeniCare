// Grupo de opções: os chips aproveitam os vãos das linhas (uma opção que
// cabe no fim de uma linha de cima sobe para lá), "Outro" fica por último e
// marcar uma opção não faz as demais trocarem de lugar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senicare/core/componentes.dart';
import 'package:senicare/core/preferencias.dart';
import 'package:senicare/core/tema.dart';
import 'package:senicare/domain/posologia.dart';

const double _largura = 360;

Widget _app(Widget filho) => MaterialApp(
  theme: construirTema(TemaApp.claro),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: _largura, child: filho),
      ),
    ),
  ),
);

Rect _caixa(WidgetTester t, String rotulo) => t.getRect(
  find.ancestor(of: find.text(rotulo), matching: find.byType(RawChip)).first,
);

Future<MotivoDeUso?> Function() _montar(WidgetTester t) {
  MotivoDeUso? escolhido;
  return () async {
    await t.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => GrupoDeOpcoes(
            opcoes: [
              for (final m in MotivoDeUso.values)
                Opcao(
                  rotulo: m.rotulo,
                  noFim: m == MotivoDeUso.outro,
                  selecionada: escolhido == m,
                  onTap: () => setState(() => escolhido = m),
                ),
            ],
          ),
        ),
      ),
    );
    return escolhido;
  };
}

void main() {
  testWidgets('nenhum vão fica vazio se uma opção seguinte coubesse nele', (
    t,
  ) async {
    await _montar(t)();
    expect(t.takeException(), isNull);
    final Map<String, Rect> caixas = {
      for (final m in MotivoDeUso.values) m.rotulo: _caixa(t, m.rotulo),
    };
    for (final r in caixas.values) {
      expect(r.right, lessThanOrEqualTo(_largura + 0.5));
    }
    // Vão à direita de cada linha.
    final Map<double, double> fimDaLinha = {};
    for (final r in caixas.values) {
      fimDaLinha.update(
        r.top,
        (x) => x > r.right ? x : r.right,
        ifAbsent: () => r.right,
      );
    }
    final List<double> topos = fimDaLinha.keys.toList()..sort();
    for (final m in MotivoDeUso.values) {
      if (m == MotivoDeUso.outro) continue;
      final Rect r = caixas[m.rotulo]!;
      for (final topo in topos.where((y) => y < r.top - 1)) {
        final double vao = _largura - fimDaLinha[topo]! - 8;
        // Cabia (com folga para o ✓) numa linha de cima? Então deveria
        // ter subido.
        expect(
          r.width + 16,
          greaterThan(vao),
          reason: '${m.rotulo} cabia na linha $topo',
        );
      }
    }
    // "Outro" é a última opção.
    final Rect outro = caixas[MotivoDeUso.outro.rotulo]!;
    expect(outro.top, closeTo(topos.last, 1));
    for (final r in caixas.values.where((r) => (r.top - outro.top).abs() < 1)) {
      expect(r.left, lessThanOrEqualTo(outro.left));
    }
  });

  testWidgets('marcar uma opção não muda as outras de linha', (t) async {
    final montar = _montar(t);
    await montar();
    final Map<String, double> antes = {
      for (final m in MotivoDeUso.values)
        m.rotulo:
            _caixa(t, m.rotulo).top - _caixa(t, MotivoDeUso.dor.rotulo).top,
    };
    final Finder alvo = find.text(MotivoDeUso.anticoncepcional.rotulo);
    await t.ensureVisible(alvo);
    await t.tap(alvo);
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsNothing); // ✓ é desenhado, sem ícone
    for (final m in MotivoDeUso.values) {
      expect(
        _caixa(t, m.rotulo).top - _caixa(t, MotivoDeUso.dor.rotulo).top,
        closeTo(antes[m.rotulo]!, 0.5),
        reason: m.rotulo,
      );
    }
  });

  testWidgets('cabe dentro de um diálogo (largura intrínseca)', (t) async {
    await t.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                content: GrupoDeOpcoes(
                  opcoes: [
                    for (final u in ['mg', 'g', 'mcg', 'mL', 'UI', '%'])
                      Opcao(rotulo: u, selecionada: false, onTap: () {}),
                  ],
                ),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('mcg'), findsOneWidget);
  });
}
