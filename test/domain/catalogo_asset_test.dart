// Confere o catálogo REAL embutido no app (assets/data/medicamentos_br.json),
// gerado por tool/gerar_catalogo.py.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senicare/domain/catalogo.dart';
import 'package:senicare/domain/posologia.dart';

void main() {
  final Map<String, dynamic> json =
      jsonDecode(File('assets/data/medicamentos_br.json').readAsStringSync())
          as Map<String, dynamic>;
  final List<dynamic> brutos = json['itens'] as List<dynamic>;
  final CatalogoMedicamentos catalogo = CatalogoMedicamentos.fromJson(json);

  test('tem mais de 500 medicamentos, todos com forma válida', () {
    expect(catalogo.itens.length, greaterThanOrEqualTo(500));
    for (final bruto in brutos) {
      final List<dynamic> formas =
          (bruto as Map<String, dynamic>)['f'] as List<dynamic>;
      expect(formas, isNotEmpty, reason: '${bruto['n']}');
      for (final f in formas) {
        expect(
          FormaFarmaceutica.daChave(f as String),
          isNotNull,
          reason: '${bruto['n']}: forma "$f"',
        );
      }
    }
  });

  test('usos sugeridos existem na lista do app', () {
    for (final bruto in brutos) {
      final List<dynamic> ms =
          (bruto as Map<String, dynamic>)['m'] as List<dynamic>? ?? const [];
      for (final m in ms) {
        expect(
          MotivoDeUso.daChave(m as String),
          isNotNull,
          reason: '${bruto['n']}: $m',
        );
      }
    }
  });

  test('"Para que serve?" mostra só os usos do remédio', () {
    List<String> usos(String nome) => catalogo.porNome(nome)!.motivos;
    expect(usos('Desogestrel'), ['anticoncepcional']);
    expect(usos('Paracetamol'), containsAll(['dor', 'febre']));
    expect(usos('Paracetamol'), isNot(contains('anticoncepcional')));
    expect(usos('Ibuprofeno'), containsAll(['dor', 'febre', 'ossos']));
    // Formas: só as que existem para o remédio.
    expect(catalogo.porNome('Dipirona')!.formas, ['comprimido', 'gotas', 'ml']);
    expect(catalogo.porNome('Losartana')!.formas, ['comprimido']);
    expect(catalogo.porNome('Salbutamol')!.formas, ['jato']);
    // Nome comercial também identifica o remédio.
    expect(catalogo.porNome('yasmin')!.nome, 'Drospirenona + Etinilestradiol');
  });

  test('nomes únicos (sem diferenciar acento e maiúscula)', () {
    final nomes = catalogo.itens.map((i) => normalizarBusca(i.nome)).toList();
    expect(nomes.toSet().length, nomes.length);
  });

  test('busca por nome comercial de anticoncepcional', () {
    final s = catalogo.buscar('yasmin').first;
    expect(s.item.nome, 'Drospirenona + Etinilestradiol');
    expect(s.item.motivo, MotivoDeUso.anticoncepcional.chave);
  });

  test('genérico de referência continua no topo', () {
    expect(catalogo.buscar('dipi').first.item.nome, 'Dipirona');
    expect(catalogo.buscar('losar').first.item.nome, 'Losartana');
    expect(catalogo.buscar('losar').first.item.motivo, 'pressao');
  });

  test('busca rápida mesmo com o catálogo inteiro', () {
    final Stopwatch relogio = Stopwatch()..start();
    for (final q in ['di', 'par', 'amox', 'vitamina', 'metf', 'xa']) {
      catalogo.buscar(q);
    }
    expect(relogio.elapsedMilliseconds, lessThan(200));
  });
}
