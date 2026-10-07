// Repositório: a única porta de entrada para os dados do SeniCare. As telas,
// os alarmes e as tarefas em segundo plano conversam com ele, nunca com SQL.

import 'package:drift/drift.dart';

import '../domain/dose_schedule.dart';
import '../domain/medicamento.dart';
import 'database.dart';

class Repositorio {
  Repositorio(this._db);

  final AppDatabase _db;

  static final Repositorio instance = Repositorio(AppDatabase.instance);

  AppDatabase get banco => _db;

  // ------------------------------------------------------------------
  // Medicamentos
  // ------------------------------------------------------------------

  SimpleSelectStatement<$MedicamentosTable, Medicamento> _ativos() =>
      _db.select(_db.medicamentos)
        ..where((m) => m.arquivadoEm.isNull())
        ..orderBy([(m) => OrderingTerm.asc(m.nome.collate(Collate.noCase))]);

  /// Remédios em uso (não removidos), em ordem alfabética.
  Stream<List<Medicamento>> observarAtivos() => _ativos().watch();

  Future<List<Medicamento>> ativos() => _ativos().get();

  /// Remédios removidos pelo usuário (mais recentes primeiro).
  Stream<List<Medicamento>> observarArquivados() =>
      (_db.select(_db.medicamentos)
            ..where((m) => m.arquivadoEm.isNotNull())
            ..orderBy([(m) => OrderingTerm.desc(m.arquivadoEm)]))
          .watch();

  /// Todos, inclusive removidos — o Relatório precisa deles para o passado.
  Future<List<Medicamento>> todos() => _db.select(_db.medicamentos).get();

  Stream<List<Medicamento>> observarTodos() =>
      _db.select(_db.medicamentos).watch();

  Future<Medicamento?> porId(int id) => (_db.select(
    _db.medicamentos,
  )..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<int> inserir(MedicamentosCompanion dados) =>
      _db.into(_db.medicamentos).insert(dados);

  Future<void> atualizar(int id, MedicamentosCompanion dados) => (_db.update(
    _db.medicamentos,
  )..where((m) => m.id.equals(id))).write(dados);

  /// "Remover" não apaga: o remédio sai da agenda e dos alarmes, mas as
  /// doses já registradas continuam no histórico e no relatório.
  Future<void> arquivar(int id, {DateTime? quando}) => atualizar(
    id,
    MedicamentosCompanion(arquivadoEm: Value(quando ?? DateTime.now())),
  );

  Future<void> restaurar(int id) =>
      atualizar(id, const MedicamentosCompanion(arquivadoEm: Value(null)));

  // ------------------------------------------------------------------
  // Histórico de doses
  // ------------------------------------------------------------------

  /// Registra a resposta do usuário a uma dose. [horarioDose] é o horário
  /// agendado da dose (do alarme ou da linha tocada na Home); com ele a
  /// resposta cai no dia e na dose certos, mesmo se dada depois da
  /// meia-noite.
  Future<void> registrarResposta(
    Medicamento med, {
    required bool tomado,
    DateTime? horarioDose,
    DateTime? agora,
  }) async {
    final DateTime momento = agora ?? DateTime.now();
    final DateTime dia = horarioDose == null
        ? inicioDoDia(momento)
        : DoseSchedule.diaDaDose(med, horarioDose);
    await _db
        .into(_db.historico)
        .insert(
          HistoricoCompanion.insert(
            medicamentoId: Value(med.id),
            dataTomada: momento,
            tomado: Value(tomado),
            nomeMedicamento: Value(med.nome),
            diaReferencia: Value(chaveDoDia(dia)),
            horarioDose: Value(horarioDose),
          ),
        );
  }

  /// Desfaz respostas (botão "Desfazer" da Home).
  Future<void> apagarRegistros(Iterable<int> ids) =>
      (_db.delete(_db.historico)..where((h) => h.id.isIn(ids))).go();

  /// Respostas do dia [dia] (o dia a que a dose pertence), em ordem.
  Stream<List<RegistroDose>> observarRegistrosDoDia(DateTime dia) =>
      (_db.select(_db.historico)
            ..where((h) => h.diaReferencia.equals(chaveDoDia(dia)))
            ..orderBy([(h) => OrderingTerm.asc(h.dataTomada)]))
          .watch();

  /// Respostas de [de] até [ate] (inclusive), para o relatório.
  Future<List<RegistroDose>> registrosEntre(DateTime de, DateTime ate) =>
      (_db.select(_db.historico)..where(
            (h) => h.diaReferencia.isBetweenValues(
              chaveDoDia(de),
              chaveDoDia(ate),
            ),
          ))
          .get();

  /// Por dia: quantas doses ficaram tomadas / não tomadas (marcas do
  /// calendário). Conta só a ÚLTIMA resposta de cada dose — "não vou tomar"
  /// corrigido depois para "tomei" vale como tomada. Registros antigos, sem
  /// horário da dose, contam cada um por si.
  Stream<Map<String, ({int tomadas, int naoTomadas})>> observarResumoPorDia() {
    return _db
        .customSelect(
          '''
          SELECT dia_referencia AS dia,
                 SUM(CASE WHEN tomado = 1 THEN 1 ELSE 0 END) AS tomadas,
                 SUM(CASE WHEN tomado = 0 THEN 1 ELSE 0 END) AS nao_tomadas
          FROM (
            SELECT dia_referencia, tomado,
                   ROW_NUMBER() OVER (
                     PARTITION BY medicamento_id, dia_referencia,
                                  COALESCE(horario_dose, 'id:' || id)
                     ORDER BY data_tomada DESC, id DESC
                   ) AS ordem
            FROM historico
            WHERE dia_referencia IS NOT NULL
          )
          WHERE ordem = 1
          GROUP BY dia_referencia
          ''',
          readsFrom: {_db.historico},
        )
        .watch()
        .map(
          (linhas) => {
            for (final l in linhas)
              l.read<String>('dia'): (
                tomadas: l.read<int>('tomadas'),
                naoTomadas: l.read<int>('nao_tomadas'),
              ),
          },
        );
  }

  /// Quantas doses de cada remédio já foram tomadas (todo o período).
  Stream<Map<int, int>> observarTotalTomadasPorMedicamento() {
    final contagem = _db.historico.id.count();
    final consulta = _db.selectOnly(_db.historico)
      ..addColumns([_db.historico.medicamentoId, contagem])
      ..where(_db.historico.tomado.equals(true))
      ..groupBy([_db.historico.medicamentoId]);
    return consulta.watch().map(
      (linhas) => {
        for (final l in linhas)
          if (l.read(_db.historico.medicamentoId) != null)
            l.read(_db.historico.medicamentoId)!: l.read(contagem) ?? 0,
      },
    );
  }
}
