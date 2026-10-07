// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MedicamentosTable extends Medicamentos
    with TableInfo<$MedicamentosTable, Medicamento> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MedicamentosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descricaoMeta = const VerificationMeta(
    'descricao',
  );
  @override
  late final GeneratedColumn<String> descricao = GeneratedColumn<String>(
    'descricao',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<HoraDoDia>, String>
  horarios = GeneratedColumn<String>(
    'horario',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<HoraDoDia>>($MedicamentosTable.$converterhorarios);
  @override
  late final GeneratedColumnWithTypeConverter<Set<int>, String> diasSemana =
      GeneratedColumn<String>(
        'dias_semana',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Set<int>>($MedicamentosTable.$converterdiasSemana);
  static const VerificationMeta _fotoPathMeta = const VerificationMeta(
    'fotoPath',
  );
  @override
  late final GeneratedColumn<String> fotoPath = GeneratedColumn<String>(
    'foto_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantidadeTotalMeta = const VerificationMeta(
    'quantidadeTotal',
  );
  @override
  late final GeneratedColumn<int> quantidadeTotal = GeneratedColumn<int>(
    'quantidade_total',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dosesPorDiaMeta = const VerificationMeta(
    'dosesPorDia',
  );
  @override
  late final GeneratedColumn<int> dosesPorDia = GeneratedColumn<int>(
    'doses_por_dia',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diasAntecedenciaMeta = const VerificationMeta(
    'diasAntecedencia',
  );
  @override
  late final GeneratedColumn<int> diasAntecedencia = GeneratedColumn<int>(
    'dias_antecedencia',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  @override
  late final GeneratedColumnWithTypeConverter<FrequenciaTipo, String>
  frequencia = GeneratedColumn<String>(
    'frequencia_tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Horários Fixos'),
  ).withConverter<FrequenciaTipo>($MedicamentosTable.$converterfrequencia);
  static const VerificationMeta _intervaloHorasMeta = const VerificationMeta(
    'intervaloHoras',
  );
  @override
  late final GeneratedColumn<int> intervaloHoras = GeneratedColumn<int>(
    'intervalo_horas',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> dataInicio =
      GeneratedColumn<String>(
        'data_inicio',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($MedicamentosTable.$converterdataInicion);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> dataFim =
      GeneratedColumn<String>(
        'data_fim',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($MedicamentosTable.$converterdataFimn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> estoqueDesde =
      GeneratedColumn<String>(
        'estoque_desde',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($MedicamentosTable.$converterestoqueDesden);
  static const VerificationMeta _dosagemMeta = const VerificationMeta(
    'dosagem',
  );
  @override
  late final GeneratedColumn<String> dosagem = GeneratedColumn<String>(
    'dosagem',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantidadePorDoseMeta = const VerificationMeta(
    'quantidadePorDose',
  );
  @override
  late final GeneratedColumn<double> quantidadePorDose =
      GeneratedColumn<double>(
        'quantidade_por_dose',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _formaMeta = const VerificationMeta('forma');
  @override
  late final GeneratedColumn<String> forma = GeneratedColumn<String>(
    'forma',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _motivoMeta = const VerificationMeta('motivo');
  @override
  late final GeneratedColumn<String> motivo = GeneratedColumn<String>(
    'motivo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> arquivadoEm =
      GeneratedColumn<String>(
        'arquivado_em',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($MedicamentosTable.$converterarquivadoEmn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nome,
    descricao,
    horarios,
    diasSemana,
    fotoPath,
    quantidadeTotal,
    dosesPorDia,
    diasAntecedencia,
    frequencia,
    intervaloHoras,
    dataInicio,
    dataFim,
    estoqueDesde,
    dosagem,
    quantidadePorDose,
    forma,
    motivo,
    arquivadoEm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'medicamentos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Medicamento> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('descricao')) {
      context.handle(
        _descricaoMeta,
        descricao.isAcceptableOrUnknown(data['descricao']!, _descricaoMeta),
      );
    }
    if (data.containsKey('foto_path')) {
      context.handle(
        _fotoPathMeta,
        fotoPath.isAcceptableOrUnknown(data['foto_path']!, _fotoPathMeta),
      );
    }
    if (data.containsKey('quantidade_total')) {
      context.handle(
        _quantidadeTotalMeta,
        quantidadeTotal.isAcceptableOrUnknown(
          data['quantidade_total']!,
          _quantidadeTotalMeta,
        ),
      );
    }
    if (data.containsKey('doses_por_dia')) {
      context.handle(
        _dosesPorDiaMeta,
        dosesPorDia.isAcceptableOrUnknown(
          data['doses_por_dia']!,
          _dosesPorDiaMeta,
        ),
      );
    }
    if (data.containsKey('dias_antecedencia')) {
      context.handle(
        _diasAntecedenciaMeta,
        diasAntecedencia.isAcceptableOrUnknown(
          data['dias_antecedencia']!,
          _diasAntecedenciaMeta,
        ),
      );
    }
    if (data.containsKey('intervalo_horas')) {
      context.handle(
        _intervaloHorasMeta,
        intervaloHoras.isAcceptableOrUnknown(
          data['intervalo_horas']!,
          _intervaloHorasMeta,
        ),
      );
    }
    if (data.containsKey('dosagem')) {
      context.handle(
        _dosagemMeta,
        dosagem.isAcceptableOrUnknown(data['dosagem']!, _dosagemMeta),
      );
    }
    if (data.containsKey('quantidade_por_dose')) {
      context.handle(
        _quantidadePorDoseMeta,
        quantidadePorDose.isAcceptableOrUnknown(
          data['quantidade_por_dose']!,
          _quantidadePorDoseMeta,
        ),
      );
    }
    if (data.containsKey('forma')) {
      context.handle(
        _formaMeta,
        forma.isAcceptableOrUnknown(data['forma']!, _formaMeta),
      );
    }
    if (data.containsKey('motivo')) {
      context.handle(
        _motivoMeta,
        motivo.isAcceptableOrUnknown(data['motivo']!, _motivoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Medicamento map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Medicamento(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      descricao: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}descricao'],
      ),
      horarios: $MedicamentosTable.$converterhorarios.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}horario'],
        )!,
      ),
      diasSemana: $MedicamentosTable.$converterdiasSemana.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}dias_semana'],
        )!,
      ),
      fotoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}foto_path'],
      ),
      quantidadeTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantidade_total'],
      ),
      dosesPorDia: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}doses_por_dia'],
      ),
      diasAntecedencia: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dias_antecedencia'],
      )!,
      frequencia: $MedicamentosTable.$converterfrequencia.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}frequencia_tipo'],
        )!,
      ),
      intervaloHoras: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}intervalo_horas'],
      ),
      dataInicio: $MedicamentosTable.$converterdataInicion.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}data_inicio'],
        ),
      ),
      dataFim: $MedicamentosTable.$converterdataFimn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}data_fim'],
        ),
      ),
      estoqueDesde: $MedicamentosTable.$converterestoqueDesden.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}estoque_desde'],
        ),
      ),
      dosagem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dosagem'],
      ),
      quantidadePorDose: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantidade_por_dose'],
      ),
      forma: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}forma'],
      ),
      motivo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}motivo'],
      ),
      arquivadoEm: $MedicamentosTable.$converterarquivadoEmn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}arquivado_em'],
        ),
      ),
    );
  }

  @override
  $MedicamentosTable createAlias(String alias) {
    return $MedicamentosTable(attachedDatabase, alias);
  }

  static TypeConverter<List<HoraDoDia>, String> $converterhorarios =
      const HorariosConverter();
  static TypeConverter<Set<int>, String> $converterdiasSemana =
      const DiasSemanaConverter();
  static TypeConverter<FrequenciaTipo, String> $converterfrequencia =
      const FrequenciaConverter();
  static TypeConverter<DateTime, String> $converterdataInicio =
      const DataHoraConverter();
  static TypeConverter<DateTime?, String?> $converterdataInicion =
      NullAwareTypeConverter.wrap($converterdataInicio);
  static TypeConverter<DateTime, String> $converterdataFim =
      const DataHoraConverter();
  static TypeConverter<DateTime?, String?> $converterdataFimn =
      NullAwareTypeConverter.wrap($converterdataFim);
  static TypeConverter<DateTime, String> $converterestoqueDesde =
      const DataHoraConverter();
  static TypeConverter<DateTime?, String?> $converterestoqueDesden =
      NullAwareTypeConverter.wrap($converterestoqueDesde);
  static TypeConverter<DateTime, String> $converterarquivadoEm =
      const DataHoraConverter();
  static TypeConverter<DateTime?, String?> $converterarquivadoEmn =
      NullAwareTypeConverter.wrap($converterarquivadoEm);
}

class MedicamentosCompanion extends UpdateCompanion<Medicamento> {
  final Value<int> id;
  final Value<String> nome;
  final Value<String?> descricao;
  final Value<List<HoraDoDia>> horarios;
  final Value<Set<int>> diasSemana;
  final Value<String?> fotoPath;
  final Value<int?> quantidadeTotal;
  final Value<int?> dosesPorDia;
  final Value<int> diasAntecedencia;
  final Value<FrequenciaTipo> frequencia;
  final Value<int?> intervaloHoras;
  final Value<DateTime?> dataInicio;
  final Value<DateTime?> dataFim;
  final Value<DateTime?> estoqueDesde;
  final Value<String?> dosagem;
  final Value<double?> quantidadePorDose;
  final Value<String?> forma;
  final Value<String?> motivo;
  final Value<DateTime?> arquivadoEm;
  const MedicamentosCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.descricao = const Value.absent(),
    this.horarios = const Value.absent(),
    this.diasSemana = const Value.absent(),
    this.fotoPath = const Value.absent(),
    this.quantidadeTotal = const Value.absent(),
    this.dosesPorDia = const Value.absent(),
    this.diasAntecedencia = const Value.absent(),
    this.frequencia = const Value.absent(),
    this.intervaloHoras = const Value.absent(),
    this.dataInicio = const Value.absent(),
    this.dataFim = const Value.absent(),
    this.estoqueDesde = const Value.absent(),
    this.dosagem = const Value.absent(),
    this.quantidadePorDose = const Value.absent(),
    this.forma = const Value.absent(),
    this.motivo = const Value.absent(),
    this.arquivadoEm = const Value.absent(),
  });
  MedicamentosCompanion.insert({
    this.id = const Value.absent(),
    required String nome,
    this.descricao = const Value.absent(),
    required List<HoraDoDia> horarios,
    required Set<int> diasSemana,
    this.fotoPath = const Value.absent(),
    this.quantidadeTotal = const Value.absent(),
    this.dosesPorDia = const Value.absent(),
    this.diasAntecedencia = const Value.absent(),
    this.frequencia = const Value.absent(),
    this.intervaloHoras = const Value.absent(),
    this.dataInicio = const Value.absent(),
    this.dataFim = const Value.absent(),
    this.estoqueDesde = const Value.absent(),
    this.dosagem = const Value.absent(),
    this.quantidadePorDose = const Value.absent(),
    this.forma = const Value.absent(),
    this.motivo = const Value.absent(),
    this.arquivadoEm = const Value.absent(),
  }) : nome = Value(nome),
       horarios = Value(horarios),
       diasSemana = Value(diasSemana);
  static Insertable<Medicamento> custom({
    Expression<int>? id,
    Expression<String>? nome,
    Expression<String>? descricao,
    Expression<String>? horarios,
    Expression<String>? diasSemana,
    Expression<String>? fotoPath,
    Expression<int>? quantidadeTotal,
    Expression<int>? dosesPorDia,
    Expression<int>? diasAntecedencia,
    Expression<String>? frequencia,
    Expression<int>? intervaloHoras,
    Expression<String>? dataInicio,
    Expression<String>? dataFim,
    Expression<String>? estoqueDesde,
    Expression<String>? dosagem,
    Expression<double>? quantidadePorDose,
    Expression<String>? forma,
    Expression<String>? motivo,
    Expression<String>? arquivadoEm,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (descricao != null) 'descricao': descricao,
      if (horarios != null) 'horario': horarios,
      if (diasSemana != null) 'dias_semana': diasSemana,
      if (fotoPath != null) 'foto_path': fotoPath,
      if (quantidadeTotal != null) 'quantidade_total': quantidadeTotal,
      if (dosesPorDia != null) 'doses_por_dia': dosesPorDia,
      if (diasAntecedencia != null) 'dias_antecedencia': diasAntecedencia,
      if (frequencia != null) 'frequencia_tipo': frequencia,
      if (intervaloHoras != null) 'intervalo_horas': intervaloHoras,
      if (dataInicio != null) 'data_inicio': dataInicio,
      if (dataFim != null) 'data_fim': dataFim,
      if (estoqueDesde != null) 'estoque_desde': estoqueDesde,
      if (dosagem != null) 'dosagem': dosagem,
      if (quantidadePorDose != null) 'quantidade_por_dose': quantidadePorDose,
      if (forma != null) 'forma': forma,
      if (motivo != null) 'motivo': motivo,
      if (arquivadoEm != null) 'arquivado_em': arquivadoEm,
    });
  }

  MedicamentosCompanion copyWith({
    Value<int>? id,
    Value<String>? nome,
    Value<String?>? descricao,
    Value<List<HoraDoDia>>? horarios,
    Value<Set<int>>? diasSemana,
    Value<String?>? fotoPath,
    Value<int?>? quantidadeTotal,
    Value<int?>? dosesPorDia,
    Value<int>? diasAntecedencia,
    Value<FrequenciaTipo>? frequencia,
    Value<int?>? intervaloHoras,
    Value<DateTime?>? dataInicio,
    Value<DateTime?>? dataFim,
    Value<DateTime?>? estoqueDesde,
    Value<String?>? dosagem,
    Value<double?>? quantidadePorDose,
    Value<String?>? forma,
    Value<String?>? motivo,
    Value<DateTime?>? arquivadoEm,
  }) {
    return MedicamentosCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      horarios: horarios ?? this.horarios,
      diasSemana: diasSemana ?? this.diasSemana,
      fotoPath: fotoPath ?? this.fotoPath,
      quantidadeTotal: quantidadeTotal ?? this.quantidadeTotal,
      dosesPorDia: dosesPorDia ?? this.dosesPorDia,
      diasAntecedencia: diasAntecedencia ?? this.diasAntecedencia,
      frequencia: frequencia ?? this.frequencia,
      intervaloHoras: intervaloHoras ?? this.intervaloHoras,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      estoqueDesde: estoqueDesde ?? this.estoqueDesde,
      dosagem: dosagem ?? this.dosagem,
      quantidadePorDose: quantidadePorDose ?? this.quantidadePorDose,
      forma: forma ?? this.forma,
      motivo: motivo ?? this.motivo,
      arquivadoEm: arquivadoEm ?? this.arquivadoEm,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (descricao.present) {
      map['descricao'] = Variable<String>(descricao.value);
    }
    if (horarios.present) {
      map['horario'] = Variable<String>(
        $MedicamentosTable.$converterhorarios.toSql(horarios.value),
      );
    }
    if (diasSemana.present) {
      map['dias_semana'] = Variable<String>(
        $MedicamentosTable.$converterdiasSemana.toSql(diasSemana.value),
      );
    }
    if (fotoPath.present) {
      map['foto_path'] = Variable<String>(fotoPath.value);
    }
    if (quantidadeTotal.present) {
      map['quantidade_total'] = Variable<int>(quantidadeTotal.value);
    }
    if (dosesPorDia.present) {
      map['doses_por_dia'] = Variable<int>(dosesPorDia.value);
    }
    if (diasAntecedencia.present) {
      map['dias_antecedencia'] = Variable<int>(diasAntecedencia.value);
    }
    if (frequencia.present) {
      map['frequencia_tipo'] = Variable<String>(
        $MedicamentosTable.$converterfrequencia.toSql(frequencia.value),
      );
    }
    if (intervaloHoras.present) {
      map['intervalo_horas'] = Variable<int>(intervaloHoras.value);
    }
    if (dataInicio.present) {
      map['data_inicio'] = Variable<String>(
        $MedicamentosTable.$converterdataInicion.toSql(dataInicio.value),
      );
    }
    if (dataFim.present) {
      map['data_fim'] = Variable<String>(
        $MedicamentosTable.$converterdataFimn.toSql(dataFim.value),
      );
    }
    if (estoqueDesde.present) {
      map['estoque_desde'] = Variable<String>(
        $MedicamentosTable.$converterestoqueDesden.toSql(estoqueDesde.value),
      );
    }
    if (dosagem.present) {
      map['dosagem'] = Variable<String>(dosagem.value);
    }
    if (quantidadePorDose.present) {
      map['quantidade_por_dose'] = Variable<double>(quantidadePorDose.value);
    }
    if (forma.present) {
      map['forma'] = Variable<String>(forma.value);
    }
    if (motivo.present) {
      map['motivo'] = Variable<String>(motivo.value);
    }
    if (arquivadoEm.present) {
      map['arquivado_em'] = Variable<String>(
        $MedicamentosTable.$converterarquivadoEmn.toSql(arquivadoEm.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MedicamentosCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('descricao: $descricao, ')
          ..write('horarios: $horarios, ')
          ..write('diasSemana: $diasSemana, ')
          ..write('fotoPath: $fotoPath, ')
          ..write('quantidadeTotal: $quantidadeTotal, ')
          ..write('dosesPorDia: $dosesPorDia, ')
          ..write('diasAntecedencia: $diasAntecedencia, ')
          ..write('frequencia: $frequencia, ')
          ..write('intervaloHoras: $intervaloHoras, ')
          ..write('dataInicio: $dataInicio, ')
          ..write('dataFim: $dataFim, ')
          ..write('estoqueDesde: $estoqueDesde, ')
          ..write('dosagem: $dosagem, ')
          ..write('quantidadePorDose: $quantidadePorDose, ')
          ..write('forma: $forma, ')
          ..write('motivo: $motivo, ')
          ..write('arquivadoEm: $arquivadoEm')
          ..write(')'))
        .toString();
  }
}

class $HistoricoTable extends Historico
    with TableInfo<$HistoricoTable, RegistroDose> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoricoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _medicamentoIdMeta = const VerificationMeta(
    'medicamentoId',
  );
  @override
  late final GeneratedColumn<int> medicamentoId = GeneratedColumn<int>(
    'medicamento_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> dataTomada =
      GeneratedColumn<String>(
        'data_tomada',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($HistoricoTable.$converterdataTomada);
  static const VerificationMeta _tomadoMeta = const VerificationMeta('tomado');
  @override
  late final GeneratedColumn<bool> tomado = GeneratedColumn<bool>(
    'tomado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tomado" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _nomeMedicamentoMeta = const VerificationMeta(
    'nomeMedicamento',
  );
  @override
  late final GeneratedColumn<String> nomeMedicamento = GeneratedColumn<String>(
    'nome_medicamento',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diaReferenciaMeta = const VerificationMeta(
    'diaReferencia',
  );
  @override
  late final GeneratedColumn<String> diaReferencia = GeneratedColumn<String>(
    'dia_referencia',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> horarioDose =
      GeneratedColumn<String>(
        'horario_dose',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($HistoricoTable.$converterhorarioDosen);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    medicamentoId,
    dataTomada,
    tomado,
    nomeMedicamento,
    diaReferencia,
    horarioDose,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'historico';
  @override
  VerificationContext validateIntegrity(
    Insertable<RegistroDose> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('medicamento_id')) {
      context.handle(
        _medicamentoIdMeta,
        medicamentoId.isAcceptableOrUnknown(
          data['medicamento_id']!,
          _medicamentoIdMeta,
        ),
      );
    }
    if (data.containsKey('tomado')) {
      context.handle(
        _tomadoMeta,
        tomado.isAcceptableOrUnknown(data['tomado']!, _tomadoMeta),
      );
    }
    if (data.containsKey('nome_medicamento')) {
      context.handle(
        _nomeMedicamentoMeta,
        nomeMedicamento.isAcceptableOrUnknown(
          data['nome_medicamento']!,
          _nomeMedicamentoMeta,
        ),
      );
    }
    if (data.containsKey('dia_referencia')) {
      context.handle(
        _diaReferenciaMeta,
        diaReferencia.isAcceptableOrUnknown(
          data['dia_referencia']!,
          _diaReferenciaMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RegistroDose map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegistroDose(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      medicamentoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}medicamento_id'],
      ),
      dataTomada: $HistoricoTable.$converterdataTomada.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}data_tomada'],
        )!,
      ),
      tomado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tomado'],
      )!,
      nomeMedicamento: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome_medicamento'],
      ),
      diaReferencia: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dia_referencia'],
      ),
      horarioDose: $HistoricoTable.$converterhorarioDosen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}horario_dose'],
        ),
      ),
    );
  }

  @override
  $HistoricoTable createAlias(String alias) {
    return $HistoricoTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterdataTomada =
      const DataHoraConverter();
  static TypeConverter<DateTime, String> $converterhorarioDose =
      const DataHoraConverter();
  static TypeConverter<DateTime?, String?> $converterhorarioDosen =
      NullAwareTypeConverter.wrap($converterhorarioDose);
}

class HistoricoCompanion extends UpdateCompanion<RegistroDose> {
  final Value<int> id;
  final Value<int?> medicamentoId;
  final Value<DateTime> dataTomada;
  final Value<bool> tomado;
  final Value<String?> nomeMedicamento;
  final Value<String?> diaReferencia;
  final Value<DateTime?> horarioDose;
  const HistoricoCompanion({
    this.id = const Value.absent(),
    this.medicamentoId = const Value.absent(),
    this.dataTomada = const Value.absent(),
    this.tomado = const Value.absent(),
    this.nomeMedicamento = const Value.absent(),
    this.diaReferencia = const Value.absent(),
    this.horarioDose = const Value.absent(),
  });
  HistoricoCompanion.insert({
    this.id = const Value.absent(),
    this.medicamentoId = const Value.absent(),
    required DateTime dataTomada,
    this.tomado = const Value.absent(),
    this.nomeMedicamento = const Value.absent(),
    this.diaReferencia = const Value.absent(),
    this.horarioDose = const Value.absent(),
  }) : dataTomada = Value(dataTomada);
  static Insertable<RegistroDose> custom({
    Expression<int>? id,
    Expression<int>? medicamentoId,
    Expression<String>? dataTomada,
    Expression<bool>? tomado,
    Expression<String>? nomeMedicamento,
    Expression<String>? diaReferencia,
    Expression<String>? horarioDose,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (medicamentoId != null) 'medicamento_id': medicamentoId,
      if (dataTomada != null) 'data_tomada': dataTomada,
      if (tomado != null) 'tomado': tomado,
      if (nomeMedicamento != null) 'nome_medicamento': nomeMedicamento,
      if (diaReferencia != null) 'dia_referencia': diaReferencia,
      if (horarioDose != null) 'horario_dose': horarioDose,
    });
  }

  HistoricoCompanion copyWith({
    Value<int>? id,
    Value<int?>? medicamentoId,
    Value<DateTime>? dataTomada,
    Value<bool>? tomado,
    Value<String?>? nomeMedicamento,
    Value<String?>? diaReferencia,
    Value<DateTime?>? horarioDose,
  }) {
    return HistoricoCompanion(
      id: id ?? this.id,
      medicamentoId: medicamentoId ?? this.medicamentoId,
      dataTomada: dataTomada ?? this.dataTomada,
      tomado: tomado ?? this.tomado,
      nomeMedicamento: nomeMedicamento ?? this.nomeMedicamento,
      diaReferencia: diaReferencia ?? this.diaReferencia,
      horarioDose: horarioDose ?? this.horarioDose,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (medicamentoId.present) {
      map['medicamento_id'] = Variable<int>(medicamentoId.value);
    }
    if (dataTomada.present) {
      map['data_tomada'] = Variable<String>(
        $HistoricoTable.$converterdataTomada.toSql(dataTomada.value),
      );
    }
    if (tomado.present) {
      map['tomado'] = Variable<bool>(tomado.value);
    }
    if (nomeMedicamento.present) {
      map['nome_medicamento'] = Variable<String>(nomeMedicamento.value);
    }
    if (diaReferencia.present) {
      map['dia_referencia'] = Variable<String>(diaReferencia.value);
    }
    if (horarioDose.present) {
      map['horario_dose'] = Variable<String>(
        $HistoricoTable.$converterhorarioDosen.toSql(horarioDose.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoricoCompanion(')
          ..write('id: $id, ')
          ..write('medicamentoId: $medicamentoId, ')
          ..write('dataTomada: $dataTomada, ')
          ..write('tomado: $tomado, ')
          ..write('nomeMedicamento: $nomeMedicamento, ')
          ..write('diaReferencia: $diaReferencia, ')
          ..write('horarioDose: $horarioDose')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MedicamentosTable medicamentos = $MedicamentosTable(this);
  late final $HistoricoTable historico = $HistoricoTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [medicamentos, historico];
}

typedef $$MedicamentosTableCreateCompanionBuilder =
    MedicamentosCompanion Function({
      Value<int> id,
      required String nome,
      Value<String?> descricao,
      required List<HoraDoDia> horarios,
      required Set<int> diasSemana,
      Value<String?> fotoPath,
      Value<int?> quantidadeTotal,
      Value<int?> dosesPorDia,
      Value<int> diasAntecedencia,
      Value<FrequenciaTipo> frequencia,
      Value<int?> intervaloHoras,
      Value<DateTime?> dataInicio,
      Value<DateTime?> dataFim,
      Value<DateTime?> estoqueDesde,
      Value<String?> dosagem,
      Value<double?> quantidadePorDose,
      Value<String?> forma,
      Value<String?> motivo,
      Value<DateTime?> arquivadoEm,
    });
typedef $$MedicamentosTableUpdateCompanionBuilder =
    MedicamentosCompanion Function({
      Value<int> id,
      Value<String> nome,
      Value<String?> descricao,
      Value<List<HoraDoDia>> horarios,
      Value<Set<int>> diasSemana,
      Value<String?> fotoPath,
      Value<int?> quantidadeTotal,
      Value<int?> dosesPorDia,
      Value<int> diasAntecedencia,
      Value<FrequenciaTipo> frequencia,
      Value<int?> intervaloHoras,
      Value<DateTime?> dataInicio,
      Value<DateTime?> dataFim,
      Value<DateTime?> estoqueDesde,
      Value<String?> dosagem,
      Value<double?> quantidadePorDose,
      Value<String?> forma,
      Value<String?> motivo,
      Value<DateTime?> arquivadoEm,
    });

class $$MedicamentosTableFilterComposer
    extends Composer<_$AppDatabase, $MedicamentosTable> {
  $$MedicamentosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descricao => $composableBuilder(
    column: $table.descricao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<HoraDoDia>, List<HoraDoDia>, String>
  get horarios => $composableBuilder(
    column: $table.horarios,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Set<int>, Set<int>, String> get diasSemana =>
      $composableBuilder(
        column: $table.diasSemana,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get fotoPath => $composableBuilder(
    column: $table.fotoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantidadeTotal => $composableBuilder(
    column: $table.quantidadeTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dosesPorDia => $composableBuilder(
    column: $table.dosesPorDia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diasAntecedencia => $composableBuilder(
    column: $table.diasAntecedencia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FrequenciaTipo, FrequenciaTipo, String>
  get frequencia => $composableBuilder(
    column: $table.frequencia,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get intervaloHoras => $composableBuilder(
    column: $table.intervaloHoras,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get dataInicio =>
      $composableBuilder(
        column: $table.dataInicio,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get dataFim =>
      $composableBuilder(
        column: $table.dataFim,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String>
  get estoqueDesde => $composableBuilder(
    column: $table.estoqueDesde,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get dosagem => $composableBuilder(
    column: $table.dosagem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantidadePorDose => $composableBuilder(
    column: $table.quantidadePorDose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get forma => $composableBuilder(
    column: $table.forma,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get motivo => $composableBuilder(
    column: $table.motivo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get arquivadoEm =>
      $composableBuilder(
        column: $table.arquivadoEm,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$MedicamentosTableOrderingComposer
    extends Composer<_$AppDatabase, $MedicamentosTable> {
  $$MedicamentosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descricao => $composableBuilder(
    column: $table.descricao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get horarios => $composableBuilder(
    column: $table.horarios,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diasSemana => $composableBuilder(
    column: $table.diasSemana,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fotoPath => $composableBuilder(
    column: $table.fotoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantidadeTotal => $composableBuilder(
    column: $table.quantidadeTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dosesPorDia => $composableBuilder(
    column: $table.dosesPorDia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diasAntecedencia => $composableBuilder(
    column: $table.diasAntecedencia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequencia => $composableBuilder(
    column: $table.frequencia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervaloHoras => $composableBuilder(
    column: $table.intervaloHoras,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataInicio => $composableBuilder(
    column: $table.dataInicio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataFim => $composableBuilder(
    column: $table.dataFim,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estoqueDesde => $composableBuilder(
    column: $table.estoqueDesde,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dosagem => $composableBuilder(
    column: $table.dosagem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantidadePorDose => $composableBuilder(
    column: $table.quantidadePorDose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get forma => $composableBuilder(
    column: $table.forma,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get motivo => $composableBuilder(
    column: $table.motivo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get arquivadoEm => $composableBuilder(
    column: $table.arquivadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MedicamentosTableAnnotationComposer
    extends Composer<_$AppDatabase, $MedicamentosTable> {
  $$MedicamentosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get descricao =>
      $composableBuilder(column: $table.descricao, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<HoraDoDia>, String> get horarios =>
      $composableBuilder(column: $table.horarios, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Set<int>, String> get diasSemana =>
      $composableBuilder(
        column: $table.diasSemana,
        builder: (column) => column,
      );

  GeneratedColumn<String> get fotoPath =>
      $composableBuilder(column: $table.fotoPath, builder: (column) => column);

  GeneratedColumn<int> get quantidadeTotal => $composableBuilder(
    column: $table.quantidadeTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dosesPorDia => $composableBuilder(
    column: $table.dosesPorDia,
    builder: (column) => column,
  );

  GeneratedColumn<int> get diasAntecedencia => $composableBuilder(
    column: $table.diasAntecedencia,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<FrequenciaTipo, String> get frequencia =>
      $composableBuilder(
        column: $table.frequencia,
        builder: (column) => column,
      );

  GeneratedColumn<int> get intervaloHoras => $composableBuilder(
    column: $table.intervaloHoras,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, String> get dataInicio =>
      $composableBuilder(
        column: $table.dataInicio,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, String> get dataFim =>
      $composableBuilder(column: $table.dataFim, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get estoqueDesde =>
      $composableBuilder(
        column: $table.estoqueDesde,
        builder: (column) => column,
      );

  GeneratedColumn<String> get dosagem =>
      $composableBuilder(column: $table.dosagem, builder: (column) => column);

  GeneratedColumn<double> get quantidadePorDose => $composableBuilder(
    column: $table.quantidadePorDose,
    builder: (column) => column,
  );

  GeneratedColumn<String> get forma =>
      $composableBuilder(column: $table.forma, builder: (column) => column);

  GeneratedColumn<String> get motivo =>
      $composableBuilder(column: $table.motivo, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get arquivadoEm =>
      $composableBuilder(
        column: $table.arquivadoEm,
        builder: (column) => column,
      );
}

class $$MedicamentosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MedicamentosTable,
          Medicamento,
          $$MedicamentosTableFilterComposer,
          $$MedicamentosTableOrderingComposer,
          $$MedicamentosTableAnnotationComposer,
          $$MedicamentosTableCreateCompanionBuilder,
          $$MedicamentosTableUpdateCompanionBuilder,
          (
            Medicamento,
            BaseReferences<_$AppDatabase, $MedicamentosTable, Medicamento>,
          ),
          Medicamento,
          PrefetchHooks Function()
        > {
  $$MedicamentosTableTableManager(_$AppDatabase db, $MedicamentosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MedicamentosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MedicamentosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MedicamentosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<String?> descricao = const Value.absent(),
                Value<List<HoraDoDia>> horarios = const Value.absent(),
                Value<Set<int>> diasSemana = const Value.absent(),
                Value<String?> fotoPath = const Value.absent(),
                Value<int?> quantidadeTotal = const Value.absent(),
                Value<int?> dosesPorDia = const Value.absent(),
                Value<int> diasAntecedencia = const Value.absent(),
                Value<FrequenciaTipo> frequencia = const Value.absent(),
                Value<int?> intervaloHoras = const Value.absent(),
                Value<DateTime?> dataInicio = const Value.absent(),
                Value<DateTime?> dataFim = const Value.absent(),
                Value<DateTime?> estoqueDesde = const Value.absent(),
                Value<String?> dosagem = const Value.absent(),
                Value<double?> quantidadePorDose = const Value.absent(),
                Value<String?> forma = const Value.absent(),
                Value<String?> motivo = const Value.absent(),
                Value<DateTime?> arquivadoEm = const Value.absent(),
              }) => MedicamentosCompanion(
                id: id,
                nome: nome,
                descricao: descricao,
                horarios: horarios,
                diasSemana: diasSemana,
                fotoPath: fotoPath,
                quantidadeTotal: quantidadeTotal,
                dosesPorDia: dosesPorDia,
                diasAntecedencia: diasAntecedencia,
                frequencia: frequencia,
                intervaloHoras: intervaloHoras,
                dataInicio: dataInicio,
                dataFim: dataFim,
                estoqueDesde: estoqueDesde,
                dosagem: dosagem,
                quantidadePorDose: quantidadePorDose,
                forma: forma,
                motivo: motivo,
                arquivadoEm: arquivadoEm,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nome,
                Value<String?> descricao = const Value.absent(),
                required List<HoraDoDia> horarios,
                required Set<int> diasSemana,
                Value<String?> fotoPath = const Value.absent(),
                Value<int?> quantidadeTotal = const Value.absent(),
                Value<int?> dosesPorDia = const Value.absent(),
                Value<int> diasAntecedencia = const Value.absent(),
                Value<FrequenciaTipo> frequencia = const Value.absent(),
                Value<int?> intervaloHoras = const Value.absent(),
                Value<DateTime?> dataInicio = const Value.absent(),
                Value<DateTime?> dataFim = const Value.absent(),
                Value<DateTime?> estoqueDesde = const Value.absent(),
                Value<String?> dosagem = const Value.absent(),
                Value<double?> quantidadePorDose = const Value.absent(),
                Value<String?> forma = const Value.absent(),
                Value<String?> motivo = const Value.absent(),
                Value<DateTime?> arquivadoEm = const Value.absent(),
              }) => MedicamentosCompanion.insert(
                id: id,
                nome: nome,
                descricao: descricao,
                horarios: horarios,
                diasSemana: diasSemana,
                fotoPath: fotoPath,
                quantidadeTotal: quantidadeTotal,
                dosesPorDia: dosesPorDia,
                diasAntecedencia: diasAntecedencia,
                frequencia: frequencia,
                intervaloHoras: intervaloHoras,
                dataInicio: dataInicio,
                dataFim: dataFim,
                estoqueDesde: estoqueDesde,
                dosagem: dosagem,
                quantidadePorDose: quantidadePorDose,
                forma: forma,
                motivo: motivo,
                arquivadoEm: arquivadoEm,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MedicamentosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MedicamentosTable,
      Medicamento,
      $$MedicamentosTableFilterComposer,
      $$MedicamentosTableOrderingComposer,
      $$MedicamentosTableAnnotationComposer,
      $$MedicamentosTableCreateCompanionBuilder,
      $$MedicamentosTableUpdateCompanionBuilder,
      (
        Medicamento,
        BaseReferences<_$AppDatabase, $MedicamentosTable, Medicamento>,
      ),
      Medicamento,
      PrefetchHooks Function()
    >;
typedef $$HistoricoTableCreateCompanionBuilder =
    HistoricoCompanion Function({
      Value<int> id,
      Value<int?> medicamentoId,
      required DateTime dataTomada,
      Value<bool> tomado,
      Value<String?> nomeMedicamento,
      Value<String?> diaReferencia,
      Value<DateTime?> horarioDose,
    });
typedef $$HistoricoTableUpdateCompanionBuilder =
    HistoricoCompanion Function({
      Value<int> id,
      Value<int?> medicamentoId,
      Value<DateTime> dataTomada,
      Value<bool> tomado,
      Value<String?> nomeMedicamento,
      Value<String?> diaReferencia,
      Value<DateTime?> horarioDose,
    });

class $$HistoricoTableFilterComposer
    extends Composer<_$AppDatabase, $HistoricoTable> {
  $$HistoricoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get medicamentoId => $composableBuilder(
    column: $table.medicamentoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get dataTomada =>
      $composableBuilder(
        column: $table.dataTomada,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get tomado => $composableBuilder(
    column: $table.tomado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nomeMedicamento => $composableBuilder(
    column: $table.nomeMedicamento,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diaReferencia => $composableBuilder(
    column: $table.diaReferencia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get horarioDose =>
      $composableBuilder(
        column: $table.horarioDose,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$HistoricoTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoricoTable> {
  $$HistoricoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get medicamentoId => $composableBuilder(
    column: $table.medicamentoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataTomada => $composableBuilder(
    column: $table.dataTomada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tomado => $composableBuilder(
    column: $table.tomado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nomeMedicamento => $composableBuilder(
    column: $table.nomeMedicamento,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diaReferencia => $composableBuilder(
    column: $table.diaReferencia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get horarioDose => $composableBuilder(
    column: $table.horarioDose,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoricoTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoricoTable> {
  $$HistoricoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get medicamentoId => $composableBuilder(
    column: $table.medicamentoId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, String> get dataTomada =>
      $composableBuilder(
        column: $table.dataTomada,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get tomado =>
      $composableBuilder(column: $table.tomado, builder: (column) => column);

  GeneratedColumn<String> get nomeMedicamento => $composableBuilder(
    column: $table.nomeMedicamento,
    builder: (column) => column,
  );

  GeneratedColumn<String> get diaReferencia => $composableBuilder(
    column: $table.diaReferencia,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, String> get horarioDose =>
      $composableBuilder(
        column: $table.horarioDose,
        builder: (column) => column,
      );
}

class $$HistoricoTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HistoricoTable,
          RegistroDose,
          $$HistoricoTableFilterComposer,
          $$HistoricoTableOrderingComposer,
          $$HistoricoTableAnnotationComposer,
          $$HistoricoTableCreateCompanionBuilder,
          $$HistoricoTableUpdateCompanionBuilder,
          (
            RegistroDose,
            BaseReferences<_$AppDatabase, $HistoricoTable, RegistroDose>,
          ),
          RegistroDose,
          PrefetchHooks Function()
        > {
  $$HistoricoTableTableManager(_$AppDatabase db, $HistoricoTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoricoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoricoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoricoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> medicamentoId = const Value.absent(),
                Value<DateTime> dataTomada = const Value.absent(),
                Value<bool> tomado = const Value.absent(),
                Value<String?> nomeMedicamento = const Value.absent(),
                Value<String?> diaReferencia = const Value.absent(),
                Value<DateTime?> horarioDose = const Value.absent(),
              }) => HistoricoCompanion(
                id: id,
                medicamentoId: medicamentoId,
                dataTomada: dataTomada,
                tomado: tomado,
                nomeMedicamento: nomeMedicamento,
                diaReferencia: diaReferencia,
                horarioDose: horarioDose,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> medicamentoId = const Value.absent(),
                required DateTime dataTomada,
                Value<bool> tomado = const Value.absent(),
                Value<String?> nomeMedicamento = const Value.absent(),
                Value<String?> diaReferencia = const Value.absent(),
                Value<DateTime?> horarioDose = const Value.absent(),
              }) => HistoricoCompanion.insert(
                id: id,
                medicamentoId: medicamentoId,
                dataTomada: dataTomada,
                tomado: tomado,
                nomeMedicamento: nomeMedicamento,
                diaReferencia: diaReferencia,
                horarioDose: horarioDose,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoricoTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HistoricoTable,
      RegistroDose,
      $$HistoricoTableFilterComposer,
      $$HistoricoTableOrderingComposer,
      $$HistoricoTableAnnotationComposer,
      $$HistoricoTableCreateCompanionBuilder,
      $$HistoricoTableUpdateCompanionBuilder,
      (
        RegistroDose,
        BaseReferences<_$AppDatabase, $HistoricoTable, RegistroDose>,
      ),
      RegistroDose,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MedicamentosTableTableManager get medicamentos =>
      $$MedicamentosTableTableManager(_db, _db.medicamentos);
  $$HistoricoTableTableManager get historico =>
      $$HistoricoTableTableManager(_db, _db.historico);
}
