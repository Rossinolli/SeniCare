// Vocabulário padronizado da posologia: forma farmacêutica, unidade da
// gramatura e motivo de uso. Antes eram campos de texto livre — o alarme
// mostrava o que o usuário digitou ("pressao", "Pressão Alta!!", "p/ dor")
// e cada cadastro ficava diferente. Agora são listas fechadas, com rótulos
// e plurais corretos, escolhidas por toque.

enum FormaFarmaceutica {
  comprimido('comprimido', 'comprimido', 'comprimidos', passo: 0.5),
  capsula('capsula', 'cápsula', 'cápsulas'),
  gotas('gotas', 'gota', 'gotas', maximo: 100),
  ml('ml', 'mL', 'mL', passo: 0.5, maximo: 50),
  sache('sache', 'sachê', 'sachês'),
  jato('jato', 'jato', 'jatos'),
  unidades('unidades', 'unidade (UI)', 'unidades (UI)', maximo: 100),
  aplicacao('aplicacao', 'aplicação', 'aplicações'),
  adesivo('adesivo', 'adesivo', 'adesivos'),
  ampola('ampola', 'ampola', 'ampolas');

  final String chave;
  final String singular;
  final String plural;

  /// Incremento do seletor de quantidade (½ comprimido é comum).
  final double passo;
  final double maximo;

  const FormaFarmaceutica(
    this.chave,
    this.singular,
    this.plural, {
    this.passo = 1,
    this.maximo = 10,
  });

  /// Rótulo do botão de escolha ('Comprimido', 'Gotas', 'mL').
  String get rotulo => switch (this) {
    gotas => 'Gotas',
    ml => 'mL',
    unidades => 'Unidades (UI)',
    _ => singular[0].toUpperCase() + singular.substring(1),
  };

  /// Aceita a chave nova e os rótulos do catálogo ('cápsula', 'mL'...).
  static FormaFarmaceutica? daChave(String? valor) {
    if (valor == null) return null;
    final String v = removerAcentos(valor.trim().toLowerCase());
    for (final f in values) {
      if (f.chave == v || removerAcentos(f.singular.toLowerCase()) == v) {
        return f;
      }
    }
    return null;
  }

  /// '1 comprimido', '2 comprimidos', '½ comprimido', '1½ comprimido'.
  String descrever(double quantidade) {
    final String numero = formatarQuantidade(quantidade);
    // Em português o plural começa em 2: "1½ comprimido", "2 comprimidos".
    final bool usaPlural = this != ml && quantidade >= 2;
    return '$numero ${usaPlural ? plural : singular}';
  }
}

/// 1 → '1', 0.5 → '½', 1.5 → '1½', 2.25 → '2,25'.
String formatarQuantidade(double q) {
  final int inteiro = q.truncate();
  final double resto = q - inteiro;
  if (resto.abs() < 1e-9) return '$inteiro';
  if ((resto - 0.5).abs() < 1e-9) return inteiro == 0 ? '½' : '$inteiro½';
  return q
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll('.', ',');
}

/// Unidades aceitas na gramatura (o valor numérico é digitado à parte).
const List<String> unidadesDeDosagem = [
  'mg',
  'g',
  'mcg',
  'mL',
  'UI',
  'mg/mL',
  'UI/mL',
  '%',
];

/// Monta a gramatura padronizada a partir do valor digitado e da unidade:
/// ('500', 'mg') → '500 mg'; ('0.5', 'mg') → '0,5 mg'. null se inválido.
String? montarDosagem(String valor, String unidade) {
  final String limpo = valor.trim().replaceAll('.', ',');
  if (!RegExp(r'^\d{1,6}(,\d{1,3})?$').hasMatch(limpo)) return null;
  final double? numero = double.tryParse(limpo.replaceAll(',', '.'));
  if (numero == null || numero <= 0) return null;
  if (!unidadesDeDosagem.contains(unidade)) return null;
  return '$limpo $unidade';
}

enum MotivoDeUso {
  dor('dor', 'Dor'),
  febre('febre', 'Febre'),
  pressao('pressao', 'Pressão alta'),
  diabetes('diabetes', 'Diabetes'),
  colesterol('colesterol', 'Colesterol'),
  coracao('coracao', 'Coração'),
  circulacao('circulacao', 'Circulação / sangue'),
  infeccao('infeccao', 'Infecção'),
  alergia('alergia', 'Alergia'),
  respiracao('respiracao', 'Respiração'),
  estomago('estomago', 'Estômago / intestino'),
  tireoide('tireoide', 'Tireoide'),
  humor('humor', 'Ansiedade / humor'),
  sono('sono', 'Sono'),
  memoria('memoria', 'Memória'),
  ossos('ossos', 'Ossos / articulações'),
  anticoncepcional('anticoncepcional', 'Anticoncepcional'),
  vitamina('vitamina', 'Vitamina / suplemento'),
  outro('outro', 'Outro');

  final String chave;
  final String rotulo;

  const MotivoDeUso(this.chave, this.rotulo);

  static MotivoDeUso? daChave(String? chave) {
    for (final m in values) {
      if (m.chave == chave) return m;
    }
    return null;
  }
}

/// 'Dipirona Sódica' → 'dipirona sodica'. Usado na busca do catálogo, para
/// "dipir", "DIPIR" e "dípir" acharem o mesmo remédio.
String removerAcentos(String texto) {
  // Caminho rápido: texto sem acento (a maioria) volta como está, sem cópia.
  // Roda milhares de vezes ao preparar o catálogo e a cada letra digitada.
  final List<int> unidades = texto.codeUnits;
  int i = 0;
  while (i < unidades.length && unidades[i] < 0xC0) {
    i++;
  }
  if (i == unidades.length) return texto;
  final List<int> saida = List<int>.of(unidades);
  for (; i < saida.length; i++) {
    final int? troca = _semAcento[saida[i]];
    if (troca != null) saida[i] = troca;
  }
  return String.fromCharCodes(saida);
}

/// Letra acentuada (código UTF-16) → letra sem acento.
final Map<int, int> _semAcento = () {
  const String com = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const String sem = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  return {
    for (int k = 0; k < com.length; k++) com.codeUnitAt(k): sem.codeUnitAt(k),
  };
}();
