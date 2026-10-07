// Entidades do domínio do SeniCare: o remédio cadastrado e cada resposta do
// usuário a uma dose. Dart puro (sem Flutter nem banco): a camada de dados
// (Drift) usa estas mesmas classes como "row class", então o app inteiro
// trabalha com tipos verificados em vez de Map<String, dynamic>.

import 'posologia.dart';

/// Horário do dia (hora:minuto), independente de data e de Flutter.
class HoraDoDia implements Comparable<HoraDoDia> {
  final int hora;
  final int minuto;

  const HoraDoDia(this.hora, this.minuto)
    : assert(hora >= 0 && hora < 24),
      assert(minuto >= 0 && minuto < 60);

  /// Lê 'HH:mm'; null se o texto não for um horário válido.
  static HoraDoDia? tentarLer(String texto) {
    final match = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*$').firstMatch(texto);
    if (match == null) return null;
    final int h = int.parse(match.group(1)!);
    final int m = int.parse(match.group(2)!);
    if (h > 23 || m > 59) return null;
    return HoraDoDia(h, m);
  }

  int get emMinutos => hora * 60 + minuto;

  DateTime noDia(DateTime dia) =>
      DateTime(dia.year, dia.month, dia.day, hora, minuto);

  String get formatado =>
      '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';

  @override
  int compareTo(HoraDoDia outra) => emMinutos.compareTo(outra.emMinutos);

  @override
  bool operator ==(Object other) =>
      other is HoraDoDia && other.hora == hora && other.minuto == minuto;

  @override
  int get hashCode => emMinutos;

  @override
  String toString() => formatado;
}

enum FrequenciaTipo {
  /// Horários fixos em dias da semana escolhidos (ex.: 08:00 e 20:00, Seg-Sex).
  horariosFixos('Horários Fixos'),

  /// De N em N horas a partir da 1ª dose (ex.: de 8 em 8 horas).
  intervalo('Intervalo');

  /// Valor gravado no banco (mantido igual ao das versões anteriores).
  final String valorNoBanco;

  const FrequenciaTipo(this.valorNoBanco);

  /// Qualquer valor desconhecido (inclusive o legado 'Dias da Semana') é
  /// tratado como Horários Fixos.
  static FrequenciaTipo doBanco(String? valor) =>
      valor == intervalo.valorNoBanco ? intervalo : horariosFixos;
}

class Medicamento {
  final int id;
  final String nome;

  /// Texto livre. Desde a v8 só é usado como complemento do motivo "Outro";
  /// em cadastros antigos guarda a antiga "Descrição/Motivo".
  final String? descricao;
  final List<HoraDoDia> horarios;

  /// Dias da semana (1 = segunda ... 7 = domingo, igual a DateTime.weekday).
  final Set<int> diasSemana;
  final String? fotoPath;
  final int? quantidadeTotal;

  /// Coluna legada (versões < 8); mantida só por compatibilidade do banco.
  final int? dosesPorDia;
  final int diasAntecedencia;
  final FrequenciaTipo frequencia;
  final int? intervaloHoras;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final DateTime? estoqueDesde;

  /// Gramatura padronizada, ex.: '500 mg', '100 UI/mL'.
  final String? dosagem;

  /// Quanto tomar por dose, na unidade de [forma] (ex.: 1, 0.5, 20).
  final double? quantidadePorDose;

  /// Chave de [FormaFarmaceutica] (ex.: 'comprimido').
  final String? forma;

  /// Chave de [MotivoDeUso] (ex.: 'pressao').
  final String? motivo;

  /// Quando o usuário removeu o remédio. Remédios removidos NÃO são
  /// apagados: saem da agenda e dos alarmes, mas continuam no histórico.
  final DateTime? arquivadoEm;

  const Medicamento({
    required this.id,
    required this.nome,
    this.descricao,
    required this.horarios,
    required this.diasSemana,
    this.fotoPath,
    this.quantidadeTotal,
    this.dosesPorDia,
    this.diasAntecedencia = 3,
    this.frequencia = FrequenciaTipo.horariosFixos,
    this.intervaloHoras,
    this.dataInicio,
    this.dataFim,
    this.estoqueDesde,
    this.dosagem,
    this.quantidadePorDose,
    this.forma,
    this.motivo,
    this.arquivadoEm,
  });

  bool get arquivado => arquivadoEm != null;

  FormaFarmaceutica? get formaFarmaceutica => FormaFarmaceutica.daChave(forma);

  MotivoDeUso? get motivoDeUso => MotivoDeUso.daChave(motivo);

  /// '1 comprimido', '½ comprimido', '20 gotas' — ou null se não informado.
  String? get textoQuantidade {
    final FormaFarmaceutica? f = formaFarmaceutica;
    final double? q = quantidadePorDose;
    if (f == null || q == null || q <= 0) return null;
    return f.descrever(q);
  }

  /// Linha padronizada exibida no alarme e nas listas:
  /// '500 mg · 1 comprimido'.
  String? get textoDose {
    final List<String> partes = [
      if (dosagem != null && dosagem!.trim().isNotEmpty) dosagem!.trim(),
      ?textoQuantidade,
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  /// Para que serve, já padronizado ('Pressão alta'); "Outro" mostra o
  /// complemento digitado. Cadastros antigos caem na descrição livre.
  String? get textoMotivo {
    final MotivoDeUso? m = motivoDeUso;
    if (m == null) {
      final String d = (descricao ?? '').trim();
      return d.isEmpty ? null : d;
    }
    if (m == MotivoDeUso.outro) {
      final String d = (descricao ?? '').trim();
      return d.isEmpty ? m.rotulo : d;
    }
    return m.rotulo;
  }
}

/// Uma resposta do usuário a uma dose (linha da tabela 'historico').
class RegistroDose {
  final int id;
  final int? medicamentoId;

  /// Quando a resposta foi dada (momento real do toque).
  final DateTime dataTomada;

  /// true = tomou; false = disse que não tomou.
  final bool tomado;

  /// Nome do remédio no momento da resposta — o histórico continua legível
  /// mesmo que o remédio seja editado ou removido depois.
  final String? nomeMedicamento;

  /// Dia (aaaa-mm-dd) a que a dose pertence. Normalmente o dia de
  /// [dataTomada]; difere quando, por exemplo, a dose das 23:41 é adiada e
  /// confirmada às 00:02.
  final String? diaReferencia;

  /// Horário agendado da dose a que esta resposta se refere (null em
  /// registros antigos, anteriores à v8).
  final DateTime? horarioDose;

  const RegistroDose({
    required this.id,
    this.medicamentoId,
    required this.dataTomada,
    this.tomado = true,
    this.nomeMedicamento,
    this.diaReferencia,
    this.horarioDose,
  });

  String get dia => diaReferencia ?? chaveDoDia(dataTomada);
}

/// 'aaaa-mm-dd' no horário LOCAL.
String chaveDoDia(DateTime dia) =>
    '${dia.year.toString().padLeft(4, '0')}-'
    '${dia.month.toString().padLeft(2, '0')}-'
    '${dia.day.toString().padLeft(2, '0')}';

DateTime inicioDoDia(DateTime d) => DateTime(d.year, d.month, d.day);
