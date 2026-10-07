// Catálogo offline de medicamentos usado no autocompletar do cadastro.
// Pedido dos orientadores: ao digitar o início do nome, o app já sugere o
// remédio — o usuário não depende do corretor do teclado (que trocava
// "dipirona" por outra palavra) nem da própria grafia.

import 'posologia.dart';

class ItemCatalogo {
  final String nome;

  /// Nomes comerciais / sinônimos ('Novalgina' para Dipirona).
  final List<String> sinonimos;

  /// Forma farmacêutica mais comum (chave de [FormaFarmaceutica]).
  final String? forma;

  /// Gramaturas comuns, já padronizadas ('500 mg').
  final List<String> dosagens;

  final String _nomeNormalizado;
  final List<String> _sinonimosNormalizados;

  ItemCatalogo({
    required this.nome,
    this.sinonimos = const [],
    this.forma,
    this.dosagens = const [],
  }) : _nomeNormalizado = normalizarBusca(nome),
       _sinonimosNormalizados = sinonimos.map(normalizarBusca).toList();

  factory ItemCatalogo.fromJson(Map<String, dynamic> json) => ItemCatalogo(
    nome: json['n'] as String,
    sinonimos: [for (final s in (json['a'] as List? ?? const [])) s as String],
    forma: FormaFarmaceutica.daChave(json['f'] as String?)?.chave,
    dosagens: [for (final d in (json['d'] as List? ?? const [])) d as String],
  );
}

/// Uma sugestão exibida no autocompletar.
class SugestaoCatalogo {
  final ItemCatalogo item;

  /// Sinônimo que casou com a busca (para mostrar "Novalgina → Dipirona").
  final String? viaSinonimo;

  const SugestaoCatalogo(this.item, {this.viaSinonimo});
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

  /// Item cujo nome é exatamente [nome] (sem acento/caixa), se houver.
  ItemCatalogo? porNome(String nome) {
    final String alvo = normalizarBusca(nome);
    for (final item in itens) {
      if (item._nomeNormalizado == alvo) return item;
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
    achados.sort((a, b) {
      final int c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.item.nome.compareTo(b.$2.item.nome);
    });
    return [for (final a in achados.take(limite)) a.$2];
  }
}
