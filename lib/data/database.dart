// Banco de dados local (SQLite) via Drift: tabelas tipadas, consultas
// verificadas em tempo de compilação e migrações versionadas e testáveis.
//
// Substitui o antigo DatabaseHelper (sqflite + SQL em texto + Map<String,
// dynamic>). O ARQUIVO e o FORMATO das colunas continuam os mesmos — datas em
// texto ISO-8601, horários como '08:00, 20:00', dias como 'Seg, Qua' —, então
// um banco criado por qualquer versão anterior do app abre e migra sem perda.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/dose_schedule.dart';
import '../domain/medicamento.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Conversores: tipos do domínio <-> texto no banco (formato legado mantido).
// ---------------------------------------------------------------------------

class DataHoraConverter extends TypeConverter<DateTime, String> {
  const DataHoraConverter();

  @override
  DateTime fromSql(String fromDb) =>
      DateTime.tryParse(fromDb) ?? DateTime(2000);

  @override
  String toSql(DateTime value) => value.toIso8601String();
}

class HorariosConverter extends TypeConverter<List<HoraDoDia>, String> {
  const HorariosConverter();

  @override
  List<HoraDoDia> fromSql(String fromDb) =>
      [for (final parte in fromDb.split(',')) ?HoraDoDia.tentarLer(parte)]
        ..sort();

  @override
  String toSql(List<HoraDoDia> value) =>
      ([...value]..sort()).map((h) => h.formatado).join(', ');
}

class DiasSemanaConverter extends TypeConverter<Set<int>, String> {
  const DiasSemanaConverter();

  static const String todos = 'Todos os dias';

  @override
  Set<int> fromSql(String fromDb) {
    final String v = fromDb.trim();
    if (v.isEmpty || v == 'Nenhum') return {};
    // 'S, T, Q, Q, S, S, D' é o formato legado, só gravado com a semana toda.
    if (v == todos || v == 'S, T, Q, Q, S, S, D') return {1, 2, 3, 4, 5, 6, 7};
    final Set<String> tokens = v.split(',').map((d) => d.trim()).toSet();
    return {
      for (int i = 0; i < DoseSchedule.diasDaSemana.length; i++)
        if (tokens.contains(DoseSchedule.diasDaSemana[i])) i + 1,
    };
  }

  @override
  String toSql(Set<int> value) {
    if (value.length == 7) return todos;
    final List<int> dias = value.toList()..sort();
    return dias.map((d) => DoseSchedule.diasDaSemana[d - 1]).join(', ');
  }
}

class FrequenciaConverter extends TypeConverter<FrequenciaTipo, String> {
  const FrequenciaConverter();

  @override
  FrequenciaTipo fromSql(String fromDb) => FrequenciaTipo.doBanco(fromDb);

  @override
  String toSql(FrequenciaTipo value) => value.valorNoBanco;
}

// ---------------------------------------------------------------------------
// Tabelas
// ---------------------------------------------------------------------------

@UseRowClass(Medicamento)
class Medicamentos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nome => text()();
  TextColumn get descricao => text().nullable()();
  TextColumn get horarios =>
      text().named('horario').map(const HorariosConverter())();
  TextColumn get diasSemana =>
      text().named('dias_semana').map(const DiasSemanaConverter())();
  TextColumn get fotoPath => text().nullable()();
  IntColumn get quantidadeTotal => integer().nullable()();
  IntColumn get dosesPorDia => integer().nullable()();
  IntColumn get diasAntecedencia => integer().withDefault(const Constant(3))();
  TextColumn get frequencia => text()
      .named('frequencia_tipo')
      .withDefault(const Constant('Horários Fixos'))
      .map(const FrequenciaConverter())();
  IntColumn get intervaloHoras => integer().nullable()();
  TextColumn get dataInicio =>
      text().nullable().map(const DataHoraConverter())();
  TextColumn get dataFim => text().nullable().map(const DataHoraConverter())();
  TextColumn get estoqueDesde =>
      text().nullable().map(const DataHoraConverter())();
  // --- v8: posologia padronizada e remoção sem apagar ---
  TextColumn get dosagem => text().nullable()();
  RealColumn get quantidadePorDose => real().nullable()();
  TextColumn get forma => text().nullable()();
  TextColumn get motivo => text().nullable()();
  TextColumn get arquivadoEm =>
      text().nullable().map(const DataHoraConverter())();
}

@UseRowClass(RegistroDose)
class Historico extends Table {
  @override
  String get tableName => 'historico';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicamentoId => integer().nullable()();
  TextColumn get dataTomada => text().map(const DataHoraConverter())();
  BoolColumn get tomado => boolean().withDefault(const Constant(true))();
  // --- v8 ---
  TextColumn get nomeMedicamento => text().nullable()();
  TextColumn get diaReferencia => text().nullable()();
  TextColumn get horarioDose =>
      text().nullable().map(const DataHoraConverter())();
}

// ---------------------------------------------------------------------------
// Banco
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Medicamentos, Historico])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _abrir());

  /// Instância única do processo (UI, alarmes, tarefas em segundo plano).
  static final AppDatabase instance = AppDatabase();

  @override
  int get schemaVersion => 8;

  static QueryExecutor _abrir() => driftDatabase(
    name: 'senicare_database',
    native: DriftNativeOptions(databasePath: _caminhoDoBanco),
  );

  /// Mesmo arquivo usado pelas versões com sqflite
  /// (`/data/data/<app>/databases/senicare_database.db` no Android).
  static Future<String> _caminhoDoBanco() async {
    if (Platform.isAndroid) {
      final Directory suporte = await getApplicationSupportDirectory();
      final Directory pasta = Directory(
        p.join(suporte.parent.path, 'databases'),
      );
      await pasta.create(recursive: true);
      return p.join(pasta.path, 'senicare_database.db');
    }
    final Directory docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'senicare_database.db');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _criarIndices();
    },
    onUpgrade: (m, de, para) async {
      if (de < 7) await _migracoesLegadas(de);
      if (de < 8) {
        await m.addColumn(medicamentos, medicamentos.dosagem);
        await m.addColumn(medicamentos, medicamentos.quantidadePorDose);
        await m.addColumn(medicamentos, medicamentos.forma);
        await m.addColumn(medicamentos, medicamentos.motivo);
        await m.addColumn(medicamentos, medicamentos.arquivadoEm);
        await m.addColumn(historico, historico.nomeMedicamento);
        await m.addColumn(historico, historico.diaReferencia);
        await m.addColumn(historico, historico.horarioDose);
        await customStatement(
          'UPDATE historico SET dia_referencia = substr(data_tomada, 1, 10) '
          'WHERE dia_referencia IS NULL',
        );
        await customStatement(
          'UPDATE historico SET nome_medicamento = (SELECT nome FROM '
          'medicamentos m WHERE m.id = historico.medicamento_id) '
          'WHERE nome_medicamento IS NULL',
        );
        await _criarIndices();
      }
    },
    beforeOpen: (detalhes) async {
      // WAL: os botões da notificação e a sincronização em segundo plano
      // rodam em outro motor Flutter, com outra conexão ao mesmo arquivo;
      // WAL permite leitura e escrita simultâneas sem "database is locked".
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );

  Future<void> _criarIndices() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_historico_data ON historico (data_tomada)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_historico_med '
      'ON historico (medicamento_id, data_tomada)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_historico_dia ON historico (dia_referencia)',
    );
  }

  /// Migrações das versões 1 a 7 (época do sqflite), preservadas para que
  /// um aparelho com qualquer versão antiga do app chegue à v8 sem perda.
  Future<void> _migracoesLegadas(int de) async {
    if (de < 2) {
      await customStatement(
        'ALTER TABLE medicamentos ADD COLUMN foto_path TEXT',
      );
    }
    if (de < 3) {
      await customStatement(
        'ALTER TABLE medicamentos ADD COLUMN quantidade_total INTEGER',
      );
      await customStatement(
        'ALTER TABLE medicamentos ADD COLUMN doses_por_dia INTEGER',
      );
      await customStatement(
        'ALTER TABLE medicamentos ADD COLUMN dias_antecedencia INTEGER DEFAULT 3',
      );
    }
    if (de < 4) {
      await customStatement(
        'CREATE TABLE historico (id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'medicamento_id INTEGER, data_tomada TEXT NOT NULL)',
      );
    }
    if (de < 5) {
      await customStatement(
        "ALTER TABLE medicamentos ADD COLUMN frequencia_tipo TEXT DEFAULT 'Dias da Semana'",
      );
      await customStatement(
        'ALTER TABLE medicamentos ADD COLUMN intervalo_horas INTEGER',
      );
      await customStatement(
        'ALTER TABLE medicamentos ADD COLUMN data_inicio TEXT',
      );
      await customStatement(
        'ALTER TABLE medicamentos ADD COLUMN data_fim TEXT',
      );
    }
    if (de < 6) {
      await customStatement(
        'ALTER TABLE historico ADD COLUMN tomado INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (de < 7) {
      await customStatement(
        'ALTER TABLE medicamentos ADD COLUMN estoque_desde TEXT',
      );
      await customStatement(
        'UPDATE medicamentos SET estoque_desde = data_inicio '
        'WHERE estoque_desde IS NULL',
      );
    }
  }

  /// Força as consultas observadas (telas abertas) a recarregar. Usado ao
  /// voltar para o app: uma resposta dada pelos botões da notificação é
  /// gravada por outro motor Flutter, que não avisa este.
  void recarregarTelas() => notifyUpdates({
    TableUpdate.onTable(medicamentos),
    TableUpdate.onTable(historico),
  });
}
