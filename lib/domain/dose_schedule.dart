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

  /// Tolerância para doses um pouco anteriores ao cadastro: quem cadastra
  /// às 08:10 o remédio que acabou de tomar às 08:00 ainda consegue
  /// registrar essa dose.
  static const Duration toleranciaDoCadastro = Duration(minutes: 30);

  static bool _ehMeiaNoite(DateTime t) =>
      t.hour == 0 && t.minute == 0 && t.second == 0 && t.millisecond == 0;

  /// Dia (início do dia) a que pertence uma dose agendada para [horario].
  ///
  /// "Paradoxo da meia-noite": para as pessoas, a dose das 00:00 é a da
  /// meia-noite DESTA noite — fecha o dia, não o abre. Então o dia vai de
  /// 00:00:01 até 00:00:00 do dia seguinte, nos dois modos de frequência
  /// (antes valia só no modo Intervalo, e "todos os dias às 00:00"
  /// aparecia como atrasada logo depois de cadastrado).
  static DateTime diaDaDose(Medicamento med, DateTime horario) =>
      _ehMeiaNoite(horario)
      ? inicioDoDia(horario.subtract(const Duration(seconds: 1)))
      : inicioDoDia(horario);

  /// Primeiro dia do tratamento. Remédios anteriores à versão 5 do banco
  /// não têm data de início — são tratados como "sempre ativos".
  static DateTime inicioDoTratamento(Medicamento med) {
    final DateTime? inicio = med.dataInicio;
    return inicio == null ? DateTime(2000) : inicioDoDia(inicio);
  }

  /// A dose de [t] vale? Regras, nesta ordem:
  ///  * pertence a um dia entre o início e a data final do tratamento;
  ///  * não é anterior ao CADASTRO (com tolerância) — um remédio cadastrado
  ///    às 21h não cobra a dose das 08h daquele mesmo dia;
  ///  * não é posterior à remoção do remédio.
  static bool _dentroDoTratamento(Medicamento med, DateTime t) {
    final DateTime dia = diaDaDose(med, t);
    if (dia.isBefore(inicioDoTratamento(med))) return false;
    if (med.dataFim != null && dia.isAfter(inicioDoDia(med.dataFim!))) {
      return false;
    }
    final DateTime? cadastro = med.dataInicio;
    if (cadastro != null &&
        t.isBefore(cadastro.subtract(toleranciaDoCadastro))) {
      return false;
    }
    final DateTime? arquivado = med.arquivadoEm;
    return arquivado == null || t.isBefore(arquivado);
  }

  /// Todas as doses de [med] com instante em [de, ate), em ordem, até
  /// [limite] doses. Já respeita início, fim, cadastro e remoção.
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
    // Começa um dia antes: a dose "das 00:00" de um dia acontece na virada
    // para o dia seguinte e pode cair dentro de [de, ate).
    for (
      DateTime dia = inicioDoDia(de).subtract(const Duration(days: 1));
      dia.isBefore(ate) && !cheio();
      dia = _diaSeguinte(dia)
    ) {
      if (!med.diasSemana.contains(dia.weekday)) continue;
      for (final HoraDoDia h in horarios) {
        final DateTime t = h.emMinutos == 0 ? _diaSeguinte(dia) : h.noDia(dia);
        if (t.isBefore(de) || !t.isBefore(ate)) continue;
        if (!_dentroDoTratamento(med, t)) continue;
        doses.add(t);
      }
    }
    doses.sort();
    return limite == null || doses.length <= limite
        ? doses
        : doses.sublist(0, limite);
  }

  /// Doses que pertencem ao dia [dia], do ponto de vista do usuário (de
  /// 00:00:01 até a meia-noite seguinte — ver [diaDaDose]).
  static List<DateTime> dosesDoDia(Medicamento med, DateTime dia) {
    const Duration umSegundo = Duration(seconds: 1);
    return dosesEntre(
      med,
      inicioDoDia(dia).add(umSegundo),
      _diaSeguinte(dia).add(umSegundo),
    );
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
