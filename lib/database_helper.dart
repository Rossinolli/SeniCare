// Guarda os remédios cadastrados e o histórico de doses tomadas no banco de
// dados do celular.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Instância Singleton
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Inicializa o banco de dados
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'senicare_database.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Cria a tabela 'medicamentos' com as novas colunas
    await db.execute('''
      CREATE TABLE medicamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        descricao TEXT,
        horario TEXT NOT NULL,
        dias_semana TEXT NOT NULL,
        foto_path TEXT,
        quantidade_total INTEGER,
        doses_por_dia INTEGER,
        dias_antecedencia INTEGER DEFAULT 3,
        frequencia_tipo TEXT DEFAULT 'Dias da Semana',
        intervalo_horas INTEGER,
        data_inicio TEXT,
        data_fim TEXT
      )
    ''');

    // Cria a tabela 'historico'
    await db.execute('''
      CREATE TABLE historico (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicamento_id INTEGER,
        data_tomada TEXT NOT NULL,
        tomado INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  // Atualiza a estrutura do banco de dados sem perder os dados antigos
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE medicamentos ADD COLUMN foto_path TEXT;');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE medicamentos ADD COLUMN quantidade_total INTEGER;',
      );
      await db.execute(
        'ALTER TABLE medicamentos ADD COLUMN doses_por_dia INTEGER;',
      );
      await db.execute(
        'ALTER TABLE medicamentos ADD COLUMN dias_antecedencia INTEGER DEFAULT 3;',
      );
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE historico (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medicamento_id INTEGER,
          data_tomada TEXT NOT NULL
        )
      ''');
    }
    // NOVA ATUALIZAÇÃO - Versão 5
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE medicamentos ADD COLUMN frequencia_tipo TEXT DEFAULT \'Dias da Semana\';',
      );
      await db.execute(
        'ALTER TABLE medicamentos ADD COLUMN intervalo_horas INTEGER;',
      );
      await db.execute('ALTER TABLE medicamentos ADD COLUMN data_inicio TEXT;');
      await db.execute('ALTER TABLE medicamentos ADD COLUMN data_fim TEXT;');
    }
    // NOVA ATUALIZAÇÃO - Versão 6: separa 'tomado' de 'cancelado' no
    // histórico. Antes, o botão Cancelar do alarme não gravava nada; agora
    // ele grava tomado=0, então a Home e o Relatório de Adesão conseguem
    // distinguir "usuário disse que não tomou" de "ainda sem resposta hoje".
    // Todo registro já existente antes desta versão só podia ter sido
    // criado por uma confirmação real, então o DEFAULT 1 é seguro.
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE historico ADD COLUMN tomado INTEGER NOT NULL DEFAULT 1;',
      );
    }
  }

  // Insere um novo medicamento
  Future<int> insertMedicamento(Map<String, dynamic> medicamento) async {
    Database db = await database;
    return await db.insert('medicamentos', medicamento);
  }

  // Retorna todos os medicamentos cadastrados
  Future<List<Map<String, dynamic>>> getMedicamentos() async {
    Database db = await database;
    return await db.query('medicamentos');
  }

  /// Busca um único medicamento pelo ID (usado pela AlarmScreen para carregar
  /// os dados mesmo quando o app é aberto do zero por uma notificação).
  Future<Map<String, dynamic>?> getMedicamentoById(int id) async {
    Database db = await database;
    final result = await db.query(
      'medicamentos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : result.first;
  }

  // Atualiza um medicamento existente
  Future<int> updateMedicamento(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.update(
      'medicamentos',
      row,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  // Deleta um medicamento pelo ID
  Future<int> deleteMedicamento(int id) async {
    Database db = await database;
    // Opcional no futuro: Deletar o histórico atrelado a esse medicamento também
    return await db.delete('medicamentos', where: 'id = ?', whereArgs: [id]);
  }

  // --- Métodos para a tabela 'historico' ---

  /// Salva a resposta do usuário a um alarme: [tomado] true = confirmou que
  /// tomou (botão Confirmar, ou toque manual no check da Home); false =
  /// disse explicitamente que não tomou (botão Cancelar do alarme).
  Future<void> registrarDose(int medicamentoId, {bool tomado = true}) async {
    final db = await database;
    // Armazena o timestamp completo para incluir a hora da dose
    final String dataAtual = DateTime.now().toIso8601String();
    await db.insert('historico', {
      'medicamento_id': medicamentoId,
      'data_tomada': dataAtual,
      'tomado': tomado ? 1 : 0,
    });
  }

  /// Retorna as doses genuinamente TOMADAS (tomado = 1) — nunca inclui uma
  /// dose que o usuário marcou como não tomada ao cancelar o alarme.
  Future<List<Map<String, dynamic>>> getDosesTomadas() async {
    final db = await database;
    return await db.query('historico', where: 'tomado = 1');
  }

  /// Retorna, para cada medicamento com alguma resposta hoje, se a resposta
  /// mais recente foi 'tomado' (true) ou 'não tomado' (false, veio do botão
  /// Cancelar do alarme). Um medicamento ausente deste mapa ainda não teve
  /// nenhuma resposta hoje.
  Future<Map<int, bool>> getStatusDosesHoje() async {
    final db = await database;
    final String dataAtual = DateTime.now().toIso8601String().substring(0, 10);
    final List<Map<String, dynamic>> linhas = await db.query(
      'historico',
      where: 'SUBSTR(data_tomada, 1, 10) = ?',
      whereArgs: [dataAtual],
      orderBy: 'data_tomada ASC',
    );

    final Map<int, bool> status = {};
    for (final linha in linhas) {
      final int? medId = linha['medicamento_id'] as int?;
      if (medId == null) continue;
      // ORDER BY ASC + sobrescrita: a resposta mais recente do dia vence se
      // houver mais de uma (ex.: cancelou de manhã, confirmou à tarde).
      status[medId] = (linha['tomado'] as int? ?? 1) == 1;
    }
    return status;
  }

  /// Retorna as doses tomadas em uma data específica, incluindo o nome do medicamento.
  Future<List<Map<String, dynamic>>> getDosesWithMedicationDetailsByDate(
    String date,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT
        h.data_tomada,
        m.nome
      FROM
        historico h
      JOIN
        medicamentos m ON h.medicamento_id = m.id
      WHERE
        SUBSTR(h.data_tomada, 1, 10) = ? AND h.tomado = 1
      ORDER BY
        h.data_tomada ASC;
    ''',
      [date],
    );
  }
}
