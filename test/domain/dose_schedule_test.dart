// Testes do cálculo de horários de doses (DoseSchedule), a regra única usada
// pela agenda, pelo Relatório de Adesão, pelo alerta de estoque e pelos
// alarmes. Rodar com: flutter test

import 'package:flutter_test/flutter_test.dart';
import 'package:senicare/domain/dose_schedule.dart';
import 'package:senicare/domain/medicamento.dart';

import '../util/fabricas.dart';

void main() {
  // 2026-09-21 é uma segunda-feira.
  final DateTime segunda = DateTime(2026, 9, 21);
  final DateTime terca = DateTime(2026, 9, 22);

  group('Horários Fixos', () {
    test('só gera doses nos dias da semana marcados', () {
      final med = medFixo(dias: {1, 3, 5});
      expect(DoseSchedule.dosesDoDia(med, segunda), [DateTime(2026, 9, 21, 8)]);
      expect(DoseSchedule.dosesDoDia(med, terca), isEmpty);
    });

    test('vários horários no mesmo dia, em ordem', () {
      final med = medFixo(horarios: const [HoraDoDia(20, 0), HoraDoDia(8, 0)]);
      expect(DoseSchedule.dosesDoDia(med, segunda), [
        DateTime(2026, 9, 21, 8),
        DateTime(2026, 9, 21, 20),
      ]);
    });

    test('respeita a data final (inclusive o próprio dia final)', () {
      final med = medFixo(fim: DateTime(2026, 9, 21));
      expect(DoseSchedule.dosesDoDia(med, segunda), hasLength(1));
      expect(DoseSchedule.dosesDoDia(med, terca), isEmpty);
    });

    test('não cobra doses anteriores ao cadastro', () {
      // Cadastrado em 01/09 às 10:00: a dose das 08:00 desse dia não conta
      // (o remédio ainda nem existia); a partir do dia seguinte, sim.
      final med = medFixo();
      expect(DoseSchedule.dosesDoDia(med, DateTime(2026, 8, 31)), isEmpty);
      expect(DoseSchedule.dosesDoDia(med, DateTime(2026, 9, 1)), isEmpty);
      expect(DoseSchedule.dosesDoDia(med, DateTime(2026, 9, 2)), hasLength(1));
    });

    test('dose tomada pouco antes do cadastro ainda pode ser registrada', () {
      final med = medFixo(cadastro: DateTime(2026, 9, 1, 8, 20));
      expect(DoseSchedule.dosesDoDia(med, DateTime(2026, 9, 1)), [
        DateTime(2026, 9, 1, 8),
      ]);
    });

    test('00:00 é a meia-noite DESTA noite (bug "atrasada" ao cadastrar)', () {
      // Cadastrado às 21:00 de segunda, todos os dias às 00:00.
      final med = medFixo(
        horarios: const [HoraDoDia(0, 0)],
        cadastro: DateTime(2026, 9, 21, 21),
      );
      final hoje = DoseSchedule.dosesDoDia(med, segunda);
      expect(hoje, [DateTime(2026, 9, 22)]); // a virada de segunda p/ terça
      expect(DoseSchedule.diaDaDose(med, hoje.single), segunda);
    });

    test('00:00 em dia específico pertence àquele dia', () {
      // Só às segundas, 00:00: a dose é na virada de segunda para terça.
      final med = medFixo(horarios: const [HoraDoDia(0, 0)], dias: {1});
      expect(DoseSchedule.dosesDoDia(med, segunda), [DateTime(2026, 9, 22)]);
      expect(DoseSchedule.dosesDoDia(med, terca), isEmpty);
    });

    test('último dia do tratamento inclui a dose da meia-noite', () {
      final med = medFixo(
        horarios: const [HoraDoDia(0, 0)],
        fim: DateTime(2026, 9, 21),
      );
      expect(DoseSchedule.dosesDoDia(med, segunda), hasLength(1));
      expect(DoseSchedule.dosesDoDia(med, terca), isEmpty);
    });

    test('remédio antigo sem data de início não quebra (sempre ativo)', () {
      final med = medFixo(inicioNulo: true);
      expect(DoseSchedule.dosesDoDia(med, segunda), hasLength(1));
    });

    test('remédio removido para de gerar doses a partir da remoção', () {
      final med = medFixo(arquivadoEm: DateTime(2026, 9, 21, 12));
      // A dose das 08:00 de segunda aconteceu antes da remoção (12:00)...
      expect(DoseSchedule.dosesDoDia(med, segunda), hasLength(1));
      // ...e nada depois dela.
      expect(DoseSchedule.dosesDoDia(med, terca), isEmpty);
    });
  });

  group('Intervalo', () {
    test('8 em 8 horas a partir das 08:00 = 08h, 16h e 00h do dia', () {
      final doses = DoseSchedule.dosesDoDia(medIntervalo(), segunda);
      expect(doses, [
        DateTime(2026, 9, 21, 8),
        DateTime(2026, 9, 21, 16),
        // "Paradoxo da meia-noite": a dose das 00:00 fecha o dia anterior.
        DateTime(2026, 9, 22, 0),
      ]);
    });

    test('diaDaDose é o inverso de dosesDoDia (dose das 00:00)', () {
      final med = medIntervalo();
      expect(DoseSchedule.diaDaDose(med, DateTime(2026, 9, 22)), segunda);
      expect(
        DoseSchedule.diaDaDose(med, DateTime(2026, 9, 22, 8)),
        DateTime(2026, 9, 22),
      );
    });

    test('intervalo que não divide 24h segue a série contínua', () {
      final doses = DoseSchedule.dosesDoDia(medIntervalo(horas: 5), segunda);
      expect(doses, isNotEmpty);
      for (int i = 1; i < doses.length; i++) {
        expect(doses[i].difference(doses[i - 1]), const Duration(hours: 5));
      }
    });

    test('intervalo inválido não trava (antes: laço infinito)', () {
      expect(DoseSchedule.dosesDoDia(medIntervalo(horas: 0), segunda), isEmpty);
      expect(
        DoseSchedule.dosesDoDia(medIntervalo(horas: 99), segunda),
        isEmpty,
      );
    });

    test('consumo médio por dia', () {
      expect(DoseSchedule.dosesPorDiaMedia(medIntervalo(horas: 6)), 4);
      expect(
        DoseSchedule.dosesPorDiaMedia(medFixo(dias: {1, 3, 5})),
        closeTo(3 / 7, 1e-9),
      );
    });
  });

  group('Próximas doses (agendamento dos alarmes)', () {
    test('estritamente depois de "agora" e respeitando o limite', () {
      final proximas = DoseSchedule.proximasDoses(
        medFixo(),
        DateTime(2026, 9, 21, 8),
        limite: 3,
      );
      expect(proximas, [
        DateTime(2026, 9, 22, 8),
        DateTime(2026, 9, 23, 8),
        DateTime(2026, 9, 24, 8),
      ]);
    });

    test('intervalo gera TODAS as doses do dia', () {
      final proximas = DoseSchedule.proximasDoses(
        medIntervalo(),
        DateTime(2026, 9, 21, 7),
        janela: const Duration(hours: 24),
      );
      expect(proximas, [
        DateTime(2026, 9, 21, 8),
        DateTime(2026, 9, 21, 16),
        DateTime(2026, 9, 22, 0),
      ]);
    });

    test('nenhum alarme depois do fim do tratamento', () {
      final proximas = DoseSchedule.proximasDoses(
        medFixo(fim: DateTime(2026, 9, 22)),
        DateTime(2026, 9, 21, 9),
      );
      expect(proximas, [DateTime(2026, 9, 22, 8)]);
    });
  });

  group('Descrição da frequência', () {
    test('todos os dias com dois horários', () {
      final med = medFixo(horarios: const [HoraDoDia(20, 0), HoraDoDia(8, 0)]);
      expect(
        DoseSchedule.descreverFrequencia(med),
        'Todos os dias às 08:00 e 20:00',
      );
    });

    test('dias específicos', () {
      expect(
        DoseSchedule.descreverFrequencia(medFixo(dias: {1, 3, 5})),
        'Seg, Qua e Sex às 08:00',
      );
    });

    test('intervalo', () {
      expect(
        DoseSchedule.descreverFrequencia(medIntervalo()),
        'De 8 em 8 horas, a partir das 08:00',
      );
    });
  });
}
