// Agenda de um dia: cada dose programada com o seu status (tomada, não
// tomada, atrasada, agora, futura). Usada pela Home e pelo Relatório de
// Adesão — a mesma regra de status nas duas telas.
//
// Atribuição das respostas às doses: desde a v8 cada resposta grava o
// horário exato da dose a que se refere (horarioDose), então "Tomei" na dose
// das 20:00 nunca é confundido com a das 08:00 e uma resposta pode ser
// desfeita ou corrigida. Respostas antigas (sem horarioDose) preenchem as
// doses em ordem, como o app fazia antes.

import 'dose_schedule.dart';
import 'medicamento.dart';

enum StatusDose {
  tomada,
  naoTomada,

  /// Passou do horário + tolerância sem resposta (em dias passados, a dose
  /// esquecida).
  atrasada,

  /// Chegou o horário (dentro da tolerância) e ainda não houve resposta.
  agora,
  futura,
}

class DoseDoDia {
  final Medicamento medicamento;
  final DateTime horario;
  final StatusDose status;

  /// Respostas atribuídas a esta dose (a última é a que vale). Usadas para
  /// "desfazer".
  final List<RegistroDose> registros;

  const DoseDoDia({
    required this.medicamento,
    required this.horario,
    required this.status,
    this.registros = const [],
  });

  bool get respondida =>
      status == StatusDose.tomada || status == StatusDose.naoTomada;

  /// Já devia ter sido tomada (para o relatório).
  bool get devida => status != StatusDose.futura;
}

class AgendaDoDia {
  final DateTime dia;
  final List<DoseDoDia> doses;

  const AgendaDoDia({required this.dia, required this.doses});

  int get total => doses.length;
  int get tomadas => doses.where((d) => d.status == StatusDose.tomada).length;

  /// Doses que já deviam ter sido tomadas e não foram (não tomadas ou
  /// esquecidas).
  int get perdidas => doses
      .where(
        (d) =>
            d.status == StatusDose.naoTomada || d.status == StatusDose.atrasada,
      )
      .length;

  /// Doses que contam no relatório: as devidas até agora, mais as futuras
  /// que já foram tomadas antes da hora.
  int get consideradas =>
      doses.where((d) => d.devida || d.status == StatusDose.tomada).length;

  /// A próxima dose que pede atenção: a primeira sem resposta (atrasada,
  /// agora ou futura).
  DoseDoDia? get proxima {
    for (final d in doses) {
      if (!d.respondida) return d;
    }
    return null;
  }
}

/// Monta a agenda de [dia] para [medicamentos], a partir das respostas
/// registradas naquele dia ([registros]). [agora] decide o que já passou.
AgendaDoDia montarAgenda({
  required DateTime dia,
  required List<Medicamento> medicamentos,
  required List<RegistroDose> registros,
  required DateTime agora,
  Duration tolerancia = const Duration(minutes: 30),
}) {
  final List<DoseDoDia> doses = [];
  for (final Medicamento med in medicamentos) {
    final List<DateTime> horarios = DoseSchedule.dosesDoDia(med, dia);
    if (horarios.isEmpty) continue;

    final List<RegistroDose> doMed =
        registros.where((r) => r.medicamentoId == med.id).toList()
          ..sort((a, b) => a.dataTomada.compareTo(b.dataTomada));
    final Map<int, List<RegistroDose>> porDose = {};
    final List<RegistroDose> semDose = [];
    for (final r in doMed) {
      final int i = r.horarioDose == null
          ? -1
          : horarios.indexWhere((h) => h.isAtSameMomentAs(r.horarioDose!));
      if (i >= 0) {
        porDose.putIfAbsent(i, () => []).add(r);
      } else {
        semDose.add(r);
      }
    }
    // Legado/sem correspondência: preenche as doses ainda sem resposta, em
    // ordem cronológica.
    for (final r in semDose) {
      final int livre = List.generate(
        horarios.length,
        (i) => i,
      ).firstWhere((i) => !porDose.containsKey(i), orElse: () => -1);
      if (livre < 0) break;
      porDose[livre] = [r];
    }

    for (int i = 0; i < horarios.length; i++) {
      final DateTime h = horarios[i];
      final List<RegistroDose> respostas = porDose[i] ?? const [];
      final StatusDose status;
      if (respostas.isNotEmpty) {
        status = respostas.last.tomado
            ? StatusDose.tomada
            : StatusDose.naoTomada;
      } else if (h.add(tolerancia).isBefore(agora)) {
        status = StatusDose.atrasada;
      } else if (!h.isAfter(agora)) {
        status = StatusDose.agora;
      } else {
        status = StatusDose.futura;
      }
      doses.add(
        DoseDoDia(
          medicamento: med,
          horario: h,
          status: status,
          registros: respostas,
        ),
      );
    }
  }
  doses.sort((a, b) {
    final int c = a.horario.compareTo(b.horario);
    return c != 0
        ? c
        : a.medicamento.nome.toLowerCase().compareTo(
            b.medicamento.nome.toLowerCase(),
          );
  });
  return AgendaDoDia(dia: inicioDoDia(dia), doses: doses);
}
