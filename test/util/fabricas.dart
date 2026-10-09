// Fábricas de objetos de teste.

import 'package:senicare/domain/medicamento.dart';

Medicamento medFixo({
  int id = 1,
  String nome = 'Losartana',
  List<HoraDoDia> horarios = const [HoraDoDia(8, 0)],
  Set<int> dias = const {1, 2, 3, 4, 5, 6, 7},
  DateTime? fim,
  DateTime? arquivadoEm,
  bool inicioNulo = false,
  DateTime? cadastro,
}) => Medicamento(
  id: id,
  nome: nome,
  horarios: horarios,
  diasSemana: dias,
  frequencia: FrequenciaTipo.horariosFixos,
  dataInicio: inicioNulo ? null : (cadastro ?? DateTime(2026, 9, 1, 10)),
  dataFim: fim,
  arquivadoEm: arquivadoEm,
);

Medicamento medIntervalo({
  int id = 2,
  String nome = 'Amoxicilina',
  int horas = 8,
  HoraDoDia primeira = const HoraDoDia(8, 0),
}) => Medicamento(
  id: id,
  nome: nome,
  horarios: [primeira],
  diasSemana: const {1, 2, 3, 4, 5, 6, 7},
  frequencia: FrequenciaTipo.intervalo,
  intervaloHoras: horas,
  dataInicio: DateTime(2026, 9, 1, 10),
);

RegistroDose resposta({
  int id = 1,
  required Medicamento med,
  required DateTime em,
  bool tomado = true,
  DateTime? horarioDose,
  String? dia,
}) => RegistroDose(
  id: id,
  medicamentoId: med.id,
  dataTomada: em,
  tomado: tomado,
  nomeMedicamento: med.nome,
  diaReferencia: dia ?? chaveDoDia(horarioDose ?? em),
  horarioDose: horarioDose,
);
