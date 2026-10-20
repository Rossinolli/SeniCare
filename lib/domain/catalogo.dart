// Catálogo offline de medicamentos usado no autocompletar do cadastro.
// Pedido dos orientadores: ao digitar o início do nome, o app já sugere o
// remédio — o usuário não depende do corretor do teclado (que trocava
// "dipirona" por outra palavra) nem da própria grafia.

import 'posologia.dart';

class ItemCatalogo {
  final String nome;

  /// Nomes comerciais / sinônimos ('Novalgina' para Dipirona).
  final List<String> sinonimos;

  /// Formas em que o remédio existe (chaves de [FormaFarmaceutica]); a
  /// primeira é a mais comum e vem pré-selecionada. No cadastro, só estas
  /// aparecem (Dipirona não mostra "Jato" nem "Unidades (UI)").
  final List<String> formas;

  /// Forma farmacêutica mais comum.
  String? get forma => formas.isEmpty ? null : formas.first;

  /// Gramaturas comuns, já padronizadas ('500 mg').
  final List<String> dosagens;

  /// Usos do remédio (chaves de [MotivoDeUso]); o primeiro é o mais comum
  /// e vem pré-selecionado. No cadastro, "Para que serve?" mostra só estes —
  /// menos opções para ler. Vazio quando os usos variam demais.
  final List<String> motivos;

  /// Uso mais comum, sugerido no cadastro.
  String? get motivo => motivos.isEmpty ? null : motivos.first;

  final String _nomeNormalizado;
  final List<String> _sinonimosNormalizados;

  ItemCatalogo({
    required this.nome,
    this.sinonimos = const [],
    this.formas = const [],
    this.dosagens = const [],
    this.motivos = const [],
  }) : _nomeNormalizado = normalizarBusca(nome),
       _sinonimosNormalizados = sinonimos.map(normalizarBusca).toList();

  factory ItemCatalogo.fromJson(Map<String, dynamic> json) => ItemCatalogo(
    nome: json['n'] as String,
    sinonimos: [for (final s in (json['a'] as List? ?? const [])) s as String],
    formas: [
      // 'f' é uma lista de formas (v2) ou uma forma só (versões antigas).
      for (final f in _lista(json['f'])) ?FormaFarmaceutica.daChave(f)?.chave,
    ],
    dosagens: [for (final d in (json['d'] as List? ?? const [])) d as String],
    motivos: [
      // 'm' é uma lista de usos (v2) ou um uso só (versões antigas).
      for (final m in _lista(json['m'])) ?MotivoDeUso.daChave(m)?.chave,
    ],
  );
}

/// Campo do JSON que pode ser uma lista de textos ou um texto só.
List<String> _lista(Object? valor) => switch (valor) {
  final List<dynamic> l => [for (final v in l) v as String],
  final String v => [v],
  _ => const [],
};

/// Uma sugestão exibida no autocompletar.
class SugestaoCatalogo {
  final ItemCatalogo item;

  /// Sinônimo que casou com a busca (para mostrar "Novalgina → Dipirona").
  final String? viaSinonimo;

  const SugestaoCatalogo(this.item, {this.viaSinonimo});

  /// O nome que fica no cadastro: o nome comercial que casou com a busca
  /// ("Microvlar") ou, se a pessoa digitou o princípio ativo, ele.
  String get nomeEscolhido => viaSinonimo ?? item.nome;
}

String normalizarBusca(String texto) =>
    removerAcentos(texto.toLowerCase()).replaceAll(RegExp(r'\s+'), ' ').trim();

class CatalogoMedicamentos {
  final List<ItemCatalogo> itens;

  const CatalogoMedicamentos(this.itens);

  static const CatalogoMedicamentos vazio = CatalogoMedicamentos([]);

  factory CatalogoMedicamentos.fromJson(Map<String, dynamic> json) =>
      CatalogoMedicamentos([
        for (final item in json['itens'] as List)
          ItemCatalogo.fromJson(item as Map<String, dynamic>),
      ]);

  /// Item cujo nome — ou nome comercial ('Yasmin') — é exatamente [nome]
  /// (sem acento/caixa), se houver.
  ItemCatalogo? porNome(String nome) {
    final String alvo = normalizarBusca(nome);
    if (alvo.isEmpty) return null;
    for (final item in itens) {
      if (item._nomeNormalizado == alvo) return item;
    }
    for (final item in itens) {
      if (item._sinonimosNormalizados.contains(alvo)) return item;
    }
    return null;
  }

  /// Busca por início do nome, início de sinônimo, início de qualquer
  /// palavra e, por fim, trecho — nessa ordem de relevância. Pede ao menos
  /// 2 letras (com 1 a lista seria grande demais para ajudar).
  List<SugestaoCatalogo> buscar(String consulta, {int limite = 6}) {
    final String q = normalizarBusca(consulta);
    if (q.length < 2) return const [];

    final List<(int, SugestaoCatalogo)> achados = [];
    for (final item in itens) {
      final String nome = item._nomeNormalizado;
      if (nome == q) continue; // já é exatamente o que foi digitado
      if (nome.startsWith(q)) {
        achados.add((0, SugestaoCatalogo(item)));
        continue;
      }
      final int s = item._sinonimosNormalizados.indexWhere(
        (sin) => sin.startsWith(q),
      );
      if (s >= 0) {
        achados.add((
          1,
          SugestaoCatalogo(item, viaSinonimo: item.sinonimos[s]),
        ));
        continue;
      }
      if (nome.split(RegExp(r'[\s+]+')).any((p) => p.startsWith(q))) {
        achados.add((2, SugestaoCatalogo(item)));
        continue;
      }
      if (q.length >= 3 && nome.contains(q)) {
        achados.add((3, SugestaoCatalogo(item)));
      }
    }
    // Na mesma relevância, primeiro os remédios com gramaturas conhecidas
    // (os de uso comum, curados) e os nomes mais curtos.
    achados.sort((a, b) {
      int c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      c = (a.$2.item.dosagens.isEmpty ? 1 : 0).compareTo(
        b.$2.item.dosagens.isEmpty ? 1 : 0,
      );
      if (c != 0) return c;
      c = a.$2.nomeEscolhido.length.compareTo(b.$2.nomeEscolhido.length);
      return c != 0 ? c : a.$2.nomeEscolhido.compareTo(b.$2.nomeEscolhido);
    });
    return [for (final a in achados.take(limite)) a.$2];
  }
}
