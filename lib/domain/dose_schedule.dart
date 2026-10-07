// Calcula, a partir do cadastro de um remédio, em quais dias e horários ele
// deve ser tomado. É a ÚNICA fonte dessa regra: a agenda da Home, o
// Relatório de Adesão, o alerta de estoque e o agendamento dos alarmes usam
// este mesmo cálculo, então nunca discordam entre si.
//
// Dart puro — coberto por testes unitários em test/dose_schedule_test.dart.

import 'medicamento.dart';

class DoseSchedule {
  DoseSchedule._();

  static const List<String> diasDaSemana = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];

  static const List<String> diasDaSemanaExtenso = [
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'domingo',
  ];

  static const int intervaloMinimoHoras = 1;
  static const int intervaloMaximoHoras = 24;

  static int? intervaloValido(Medicamento med) {
    final int? horas = med.intervaloHoras;
    if (horas == null ||
        horas < intervaloMinimoHoras ||
        horas > intervaloMaximoHoras) {
      return null;
    }
    return horas;
  }

  static DateTime _diaSeguinte(DateTime d) =>
      DateTime(d.year, d.month, d.day + 1);

  /// Primeiro instante em que o tratamento vale (início do dia de início).
  /// Remédios anteriores à versão 5 do banco não têm essa data — são
  /// tratados como "sempre ativos".
  static DateTime inicioDoTratamento(Medicamento med) {
    final DateTime? inicio = med.dataInicio;
    return inicio == null ? DateTime(2000) : inicioDoDia(inicio);
  }

  /// Primeiro instante em que o tratamento JÁ NÃO vale: meia-noite do dia
  /// seguinte à data final, ou o momento em que o remédio foi removido —
  /// o que vier primeiro. null em Uso Contínuo ainda ativo.
  static DateTime? fimDoTratamento(Medicamento med) {
    final DateTime? fim = med.dataFim == null
        ? null
        : _diaSeguinte(med.dataFim!);
    final DateTime? arquivado = med.arquivadoEm;
    if (fim == null) return arquivado;
    if (arquivado == null) return fim;
    return arquivado.isBefore(fim) ? arquivado : fim;
  }

  static bool _dentroDoTratamento(Medicamento med, DateTime t) {
    if (t.isBefore(inicioDoTratamento(med))) return false;
    final DateTime? fim = fimDoTratamento(med);
    return fim == null || t.isBefore(fim);
  }

  /// Todas as doses de [med] com instante em [de, ate), em ordem, até
  /// [limite] doses. Já respeita início, fim e remoção do tratamento.
  static List<DateTime> dosesEntre(
    Medicamento med,
    DateTime de,
    DateTime ate, {
    int? limite,
  }) {
    final List<DateTime> doses = [];
    bool cheio() => limite != null && doses.length >= limite;
    final List<HoraDoDia> horarios = [...med.horarios]..sort();
    if (horarios.isEmpty || !de.isBefore(ate)) return doses;

    if (med.frequencia == FrequenciaTipo.intervalo) {
      final int? horas = intervaloValido(med);
      if (horas == null) return doses;
      final DateTime inicio = inicioDoTratamento(med);
      // Âncora fixa: a 1ª dose no dia de início; as demais seguem de
      // [horas] em [horas] a partir dela, atravessando a meia-noite.
      final DateTime ancora = horarios.first.noDia(inicio);
      final Duration passo = Duration(hours: horas);
      // Pula direto (aritmética, não laço) para a primeira dose >= de.
      int k = 0;
      if (de.isAfter(ancora)) {
        k = (de.difference(ancora).inMicroseconds / passo.inMicroseconds)
            .ceil();
      }
      for (
        DateTime t = ancora.add(passo * k);
        t.isBefore(ate) && !cheio();
        t = t.add(passo)
      ) {
        if (_dentroDoTratamento(med, t)) doses.add(t);
      }
      return doses;
    }

    if (med.diasSemana.isEmpty) return doses;
    for (
      DateTime dia = inicioDoDia(de);
      dia.isBefore(ate) && !cheio();
      dia = _diaSeguinte(dia)
    ) {
      if (!med.diasSemana.contains(dia.weekday)) continue;
      for (final HoraDoDia h in horarios) {
        final DateTime t = h.noDia(dia);
        if (t.isBefore(de) || !t.isBefore(ate)) continue;
        if (!_dentroDoTratamento(med, t)) continue;
        doses.add(t);
        if (cheio()) break;
      }
    }
    return doses;
  }

  /// Doses que pertencem ao dia [dia], do ponto de vista do usuário.
  ///
  /// No modo Intervalo vale o "paradoxo da meia-noite": a dose das 00:00
  /// fecha o dia anterior (08h, 16h, 00h = as 3 doses de hoje), então o dia
  /// vai de 00:00:01 até 00:00:00 do dia seguinte.
  static List<DateTime> dosesDoDia(Medicamento med, DateTime dia) {
    final DateTime inicio = inicioDoDia(dia);
    final DateTime fim = _diaSeguinte(dia);
    if (med.frequencia == FrequenciaTipo.intervalo) {
      const Duration umSegundo = Duration(seconds: 1);
      return dosesEntre(med, inicio.add(umSegundo), fim.add(umSegundo));
    }
    return dosesEntre(med, inicio, fim);
  }

  /// Dia (início do dia) a que pertence a dose agendada para [horario] —
  /// a regra inversa de [dosesDoDia].
  static DateTime diaDaDose(Medicamento med, DateTime horario) {
    if (med.frequencia == FrequenciaTipo.intervalo &&
        horario.hour == 0 &&
        horario.minute == 0 &&
        horario.second == 0) {
      return inicioDoDia(horario.subtract(const Duration(seconds: 1)));
    }
    return inicioDoDia(horario);
  }

  /// Próximas doses estritamente depois de [apos], dentro de [janela].
  static List<DateTime> proximasDoses(
    Medicamento med,
    DateTime apos, {
    Duration janela = const Duration(days: 28),
    int? limite,
  }) {
    return dosesEntre(
      med,
      apos.add(const Duration(milliseconds: 1)),
      apos.add(janela),
      limite: limite,
    );
  }

  /// Consumo médio por dia, em doses (ex.: 1 horário em Seg/Qua/Sex = 3/7).
  static double dosesPorDiaMedia(Medicamento med) {
    if (med.horarios.isEmpty) return 0;
    if (med.frequencia == FrequenciaTipo.intervalo) {
      final int? horas = intervaloValido(med);
      return horas == null ? 0 : 24 / horas;
    }
    return med.horarios.length * med.diasSemana.length / 7;
  }

  /// Texto curto da frequência: 'Todos os dias às 08:00 e 20:00',
  /// 'Seg, Qua e Sex às 08:00', 'De 8 em 8 horas, a partir das 08:00'.
  static String descreverFrequencia(Medicamento med) {
    final List<HoraDoDia> horarios = [...med.horarios]..sort();
    if (med.frequencia == FrequenciaTipo.intervalo) {
      final int? horas = intervaloValido(med);
      if (horas == null || horarios.isEmpty) return 'Em intervalos';
      if (horas == 24) return 'Uma vez ao dia, às ${horarios.first}';
      return 'De $horas em $horas horas, a partir das ${horarios.first}';
    }
    final String horas = _juntar(horarios.map((h) => h.formatado).toList());
    final List<int> dias = med.diasSemana.toList()..sort();
    final String quando = dias.length == 7
        ? 'Todos os dias'
        : _juntar([for (final d in dias) diasDaSemana[d - 1]]);
    return horas.isEmpty ? quando : '$quando às $horas';
  }

  static String _juntar(List<String> itens) {
    if (itens.length <= 1) return itens.join();
    return '${itens.sublist(0, itens.length - 1).join(', ')} e ${itens.last}';
  }
}
