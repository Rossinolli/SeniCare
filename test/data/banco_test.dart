// Testes da camada de dados (Drift) num SQLite em memória: a migração de um
// banco criado pela versão antiga do app (sqflite, schema v7) e as regras do
// repositório — principalmente que remover um remédio NÃO apaga o histórico.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senicare/data/database.dart';
import 'package:senicare/data/repositorio.dart';
import 'package:senicare/domain/medicamento.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQL exato com que o app antigo (sqflite, versão 7) criava as tabelas.
void _criarBancoV7(Database db) {
  db.execute('''
    CREATE TABLE medicamentos (
      id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, descricao TEXT,
      horario TEXT NOT NULL, dias_semana TEXT NOT NULL, foto_path TEXT,
      quantidade_total INTEGER, doses_por_dia INTEGER,
      dias_antecedencia INTEGER DEFAULT 3,
      frequencia_tipo TEXT DEFAULT 'Horários Fixos', intervalo_horas INTEGER,
      data_inicio TEXT, data_fim TEXT, estoque_desde TEXT)''');
  db.execute('''
    CREATE TABLE historico (
      id INTEGER PRIMARY KEY AUTOINCREMENT, medicamento_id INTEGER,
      data_tomada TEXT NOT NULL, tomado INTEGER NOT NULL DEFAULT 1)''');
  db.execute('''
    INSERT INTO medicamentos (nome, descricao, horario, dias_semana,
      frequencia_tipo, data_inicio)
    VALUES ('Losartana', 'Pressão', '08:00, 20:00', 'Seg, Qua, Sex',
      'Horários Fixos', '2026-09-01T10:00:00.000')''');
  db.execute('''
    INSERT INTO historico (medicamento_id, data_tomada, tomado)
    VALUES (1, '2026-09-21T08:05:00.000', 1)''');
  db.execute('PRAGMA user_version = 7');
}

void main() {
  test('migra um banco v7 do app antigo sem perder dados', () async {
    final db = AppDatabase(NativeDatabase.memory(setup: _criarBancoV7));
    addTearDown(db.close);
    final repo = Repositorio(db);

    final meds = await repo.todos();
    expect(meds, hasLength(1));
    final med = meds.single;
    expect(med.nome, 'Losartana');
    expect(med.horarios, const [HoraDoDia(8, 0), HoraDoDia(20, 0)]);
    expect(med.diasSemana, {1, 3, 5});
    expect(med.frequencia, FrequenciaTipo.horariosFixos);
    expect(med.dataInicio, DateTime(2026, 9, 1, 10));
    expect(med.arquivado, isFalse);
    // Descrição antiga continua aparecendo como motivo.
    expect(med.textoMotivo, 'Pressão');

    // Histórico antigo ganhou o dia de referência e o nome do remédio.
    final registros = await repo.registrosEntre(
      DateTime(2026, 9, 21),
      DateTime(2026, 9, 21),
    );
    expect(registros.single.diaReferencia, '2026-09-21');
    expect(registros.single.nomeMedicamento, 'Losartana');

    final versao = await db.customSelect('PRAGMA user_version').getSingle();
    expect(versao.data.values.first, 8);
  });

  group('Repositório', () {
    late AppDatabase db;
    late Repositorio repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = Repositorio(db);
    });
    tearDown(() => db.close());

    Future<Medicamento> criar(String nome) async {
      final id = await repo.inserir(
        MedicamentosCompanion.insert(
          nome: nome,
          horarios: const [HoraDoDia(8, 0)],
          diasSemana: const {1, 2, 3, 4, 5, 6, 7},
          dataInicio: Value(DateTime(2026, 9, 1)),
        ),
      );
      return (await repo.porId(id))!;
    }

    test('remover um remédio mantém as doses no histórico', () async {
      final med = await criar('Dipirona');
      await repo.registrarResposta(
        med,
        tomado: true,
        horarioDose: DateTime(2026, 9, 21, 8),
        agora: DateTime(2026, 9, 21, 8, 3),
      );

      await repo.arquivar(med.id);

      expect(await repo.ativos(), isEmpty);
      final registros = await repo.registrosEntre(
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 21),
      );
      expect(registros.single.nomeMedicamento, 'Dipirona');
      expect(registros.single.tomado, isTrue);

      final arquivados = await repo.observarArquivados().first;
      expect(arquivados.single.nome, 'Dipirona');

      await repo.restaurar(med.id);
      expect(await repo.ativos(), hasLength(1));
    });

    test('dose adiada para depois da meia-noite cai no dia certo', () async {
      final med = await criar('Losartana');
      await repo.registrarResposta(
        med,
        tomado: true,
        horarioDose: DateTime(2026, 9, 25, 23, 41),
        agora: DateTime(2026, 9, 26, 0, 2),
      );
      final registros = await repo.registrosEntre(
        DateTime(2026, 9, 25),
        DateTime(2026, 9, 26),
      );
      expect(registros.single.diaReferencia, '2026-09-25');
    });

    test('resumo do dia considera só a última resposta de cada dose', () async {
      final med = await criar('X');
      final d8 = DateTime(2026, 9, 21, 8);
      final d20 = DateTime(2026, 9, 21, 20);
      // Dose das 08h: "não vou tomar" corrigido para "tomei".
      await repo.registrarResposta(
        med,
        tomado: false,
        horarioDose: d8,
        agora: d8,
      );
      await repo.registrarResposta(
        med,
        tomado: true,
        horarioDose: d8,
        agora: d8.add(const Duration(minutes: 5)),
      );
      // Dose das 20h: não tomada.
      await repo.registrarResposta(
        med,
        tomado: false,
        horarioDose: d20,
        agora: d20,
      );
      final resumo = await repo.observarResumoPorDia().first;
      expect(resumo['2026-09-21'], (tomadas: 1, naoTomadas: 1));
    });
  });

  test('sqlite3 nativo disponível', () {
    expect(sqlite3.version.libVersion, isNotEmpty);
  });
}
