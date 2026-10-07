// Testes da agenda do dia (status de cada dose), da posologia padronizada e
// da busca no catálogo de medicamentos.

import 'package:flutter_test/flutter_test.dart';
import 'package:senicare/domain/agenda.dart';
import 'package:senicare/domain/catalogo.dart';
import 'package:senicare/domain/medicamento.dart';
import 'package:senicare/domain/posologia.dart';

import '../util/fabricas.dart';

void main() {
  final DateTime segunda = DateTime(2026, 9, 21);

  group('Agenda do dia', () {
    final med = medFixo(
      horarios: const [HoraDoDia(8, 0), HoraDoDia(14, 0), HoraDoDia(20, 0)],
    );

    test('status por horário: atrasada, agora e futura', () {
      final agenda = montarAgenda(
        dia: segunda,
        medicamentos: [med],
        registros: const [],
        agora: DateTime(2026, 9, 21, 14, 10),
      );
      expect(agenda.doses.map((d) => d.status), [
        StatusDose.atrasada, // 08:00 + 30 min de tolerância já passou
        StatusDose.agora, // 14:00, ainda dentro da tolerância
        StatusDose.futura,
      ]);
      expect(agenda.proxima!.horario, DateTime(2026, 9, 21, 8));
    });

    test('resposta com horarioDose vai para a dose exata', () {
      final agenda = montarAgenda(
        dia: segunda,
        medicamentos: [med],
        registros: [
          resposta(
            med: med,
            em: DateTime(2026, 9, 21, 20, 5),
            horarioDose: DateTime(2026, 9, 21, 20),
          ),
        ],
        agora: DateTime(2026, 9, 21, 20, 10),
      );
      expect(agenda.doses.last.status, StatusDose.tomada);
      // A das 08:00 continua esquecida — não foi "cumprida" pela das 20:00.
      expect(agenda.doses.first.status, StatusDose.atrasada);
      expect(agenda.tomadas, 1);
      expect(agenda.perdidas, 2);
    });

    test('a resposta mais recente da dose vale (corrigir não tomei)', () {
      final DateTime dose = DateTime(2026, 9, 21, 8);
      final agenda = montarAgenda(
        dia: segunda,
        medicamentos: [med],
        registros: [
          resposta(id: 1, med: med, em: dose, tomado: false, horarioDose: dose),
          resposta(
            id: 2,
            med: med,
            em: dose.add(const Duration(minutes: 20)),
            horarioDose: dose,
          ),
        ],
        agora: DateTime(2026, 9, 21, 9),
      );
      expect(agenda.doses.first.status, StatusDose.tomada);
      expect(agenda.doses.first.registros, hasLength(2));
    });

    test('registros antigos (sem horarioDose) preenchem as doses em ordem', () {
      final agenda = montarAgenda(
        dia: segunda,
        medicamentos: [med],
        registros: [resposta(med: med, em: DateTime(2026, 9, 21, 9))],
        agora: DateTime(2026, 9, 21, 9),
      );
      expect(agenda.doses.first.status, StatusDose.tomada);
    });

    test('doses futuras tomadas antes da hora contam no relatório', () {
      final agenda = montarAgenda(
        dia: segunda,
        medicamentos: [med],
        registros: [
          resposta(
            med: med,
            em: DateTime(2026, 9, 21, 7, 50),
            horarioDose: DateTime(2026, 9, 21, 8),
          ),
        ],
        agora: DateTime(2026, 9, 21, 7, 55),
      );
      expect(agenda.consideradas, 1);
      expect(agenda.tomadas, 1);
    });
  });

  group('Posologia padronizada', () {
    test('quantidades com meio comprimido e plural', () {
      expect(FormaFarmaceutica.comprimido.descrever(1), '1 comprimido');
      expect(FormaFarmaceutica.comprimido.descrever(0.5), '½ comprimido');
      expect(FormaFarmaceutica.comprimido.descrever(1.5), '1½ comprimido');
      expect(FormaFarmaceutica.comprimido.descrever(2), '2 comprimidos');
      expect(FormaFarmaceutica.gotas.descrever(20), '20 gotas');
      expect(FormaFarmaceutica.ml.descrever(5), '5 mL');
    });

    test('gramatura montada e validada', () {
      expect(montarDosagem('500', 'mg'), '500 mg');
      expect(montarDosagem('0.5', 'mg'), '0,5 mg');
      expect(montarDosagem('abc', 'mg'), isNull);
      expect(montarDosagem('0', 'mg'), isNull);
      expect(montarDosagem('10', 'litros'), isNull);
    });

    test('linha de dose do alarme', () {
      const med = Medicamento(
        id: 1,
        nome: 'Dipirona',
        horarios: [HoraDoDia(8, 0)],
        diasSemana: {1},
        dosagem: '500 mg',
        quantidadePorDose: 1,
        forma: 'comprimido',
        motivo: 'dor',
      );
      expect(med.textoDose, '500 mg · 1 comprimido');
      expect(med.textoMotivo, 'Dor');
    });

    test('cadastro antigo mostra a descrição livre como motivo', () {
      const med = Medicamento(
        id: 1,
        nome: 'X',
        horarios: [],
        diasSemana: {},
        descricao: 'Para a pressão',
      );
      expect(med.textoMotivo, 'Para a pressão');
      expect(med.textoDose, isNull);
    });
  });

  group('Catálogo de medicamentos', () {
    final catalogo = CatalogoMedicamentos([
      ItemCatalogo(nome: 'Dipirona', sinonimos: ['Novalgina']),
      ItemCatalogo(nome: 'Diclofenaco'),
      ItemCatalogo(nome: 'Ácido acetilsalicílico', sinonimos: ['AAS']),
      ItemCatalogo(nome: 'Orfenadrina + Dipirona + Cafeína'),
    ]);

    test('início do nome, sem acento e sem diferenciar maiúsculas', () {
      expect(catalogo.buscar('DIPIR').first.item.nome, 'Dipirona');
      expect(
        catalogo.buscar('acido').single.item.nome,
        'Ácido acetilsalicílico',
      );
    });

    test('nome comercial leva ao genérico', () {
      final s = catalogo.buscar('novalg').single;
      expect(s.item.nome, 'Dipirona');
      expect(s.viaSinonimo, 'Novalgina');
    });

    test('início do nome vem antes de palavra no meio', () {
      expect(catalogo.buscar('dipi').map((s) => s.item.nome), [
        'Dipirona',
        'Orfenadrina + Dipirona + Cafeína',
      ]);
    });

    test('uma letra só não sugere nada', () {
      expect(catalogo.buscar('d'), isEmpty);
    });
  });
}
