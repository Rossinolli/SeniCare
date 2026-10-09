// Componentes visuais compartilhados por todas as telas: cartão, cabeçalho,
// estado vazio, selo da marca, avatar do remédio e as janelas (diálogo,
// folha inferior, seletores) já com o tema certo.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'preferencias.dart';
import 'tema.dart';

/// Largura máxima do conteúdo: em tablets e celulares deitados o texto não
/// se estica de ponta a ponta (linhas longas cansam a leitura).
const double larguraMaximaConteudo = 640;

/// Centraliza e limita a largura do conteúdo, com margens laterais que
/// crescem um pouco em telas maiores.
class ConteudoResponsivo extends StatelessWidget {
  final Widget child;

  const ConteudoResponsivo({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final double lateral = c.maxWidth < 400 ? 16 : 24;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: larguraMaximaConteudo),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: lateral),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Fundo da tela conforme o tema (gradiente azul, cinza claro ou escuro).
class FundoDoTema extends StatelessWidget {
  final Widget child;

  const FundoDoTema({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final Widget fundo = DecoratedBox(
      decoration: c.decoracaoDeFundo,
      child: child,
    );
    if (c.tema != TemaApp.claro) return fundo;
    // Tema Claro: "glassmorphism" — manchas de cor suaves atrás dos cards
    // translúcidos (ver [Cartao]), como luz passando por vidro fosco.
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: const _PintorManchas()),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Manchas de luz do fundo do tema Claro (gradientes radiais: já nascem
/// desfocadas, sem custo de filtro de desfoque).
class _PintorManchas extends CustomPainter {
  const _PintorManchas();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F5FC), Color(0xFFE6ECF6)],
        ).createShader(Offset.zero & size),
    );
    void mancha(double x, double y, double raio, Color cor) {
      final Offset centro = Offset(size.width * x, size.height * y);
      final double r = size.shortestSide * raio;
      canvas.drawCircle(
        centro,
        r,
        Paint()
          ..shader = ui.Gradient.radial(centro, r, [
            cor,
            cor.withValues(alpha: 0),
          ]),
      );
    }

    mancha(0.95, 0.06, 0.85, const Color(0x4D1565C0)); // azul da marca
    mancha(0.0, 0.42, 0.75, const Color(0x3806B6D4)); // ciano
    mancha(1.0, 0.78, 0.8, const Color(0x2E7C3AED)); // violeta
    mancha(0.2, 1.0, 0.7, const Color(0x2E1565C0));
  }

  @override
  bool shouldRepaint(_PintorManchas oldDelegate) => false;
}

/// Cartão padrão: superfície sólida com borda visível em todos os temas.
class Cartao extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? cor;
  final Color? corDaBorda;

  const Cartao({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.cor,
    this.corDaBorda,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final BorderRadius raio = BorderRadius.circular(20);
    if (c.tema == TemaApp.claro && cor == null) {
      return _CartaoDeVidro(
        raio: raio,
        corDaBorda: corDaBorda ?? c.borda,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      );
    }
    return Material(
      color: cor ?? c.superficie,
      // No tema Claro, além da borda, uma sombra suave separa o card do
      // fundo (heurística de Nielsen: visibilidade e clareza dos limites).
      elevation: c.tema == TemaApp.claro ? 1.5 : 0,
      shadowColor: const Color(0x33223355),
      shape: RoundedRectangleBorder(
        borderRadius: raio,
        side: BorderSide(color: corDaBorda ?? c.borda, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Título de tela na fonte caligráfica da marca (como o "Olá").
class TituloCaligrafico extends StatelessWidget {
  final String texto;
  final double tamanho;

  const TituloCaligrafico(this.texto, {super.key, this.tamanho = 44});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      // A caligrafia tem curvas que quebram se esticadas demais pela
      // escala de texto; limita o crescimento a 1,3x.
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
      style: TextStyle(
        fontFamily: fonteCaligrafica,
        fontSize: tamanho,
        height: 1.15,
        color: context.cores.texto,
      ),
    );
  }
}

/// Cabeçalho de seção: título em negrito e, opcionalmente, uma ação.
class CabecalhoSecao extends StatelessWidget {
  final String titulo;
  final Widget? acao;

  const CabecalhoSecao(this.titulo, {super.key, this.acao});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(titulo, style: context.textos.titleMedium),
            ),
          ),
          ?acao,
        ],
      ),
    );
  }
}

/// Estado vazio: ícone, título, explicação e uma ação principal.
class EstadoVazio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String mensagem;
  final String? rotuloAcao;
  final VoidCallback? onAcao;
  final List<(IconData, String)> destaques;

  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.mensagem,
    this.rotuloAcao,
    this.onAcao,
    this.destaques = const [],
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(color: c.suave, shape: BoxShape.circle),
          child: Icon(icone, size: 56, color: c.destaque),
        ),
        const SizedBox(height: 20),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: context.textos.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          mensagem,
          textAlign: TextAlign.center,
          style: context.textos.bodyLarge?.copyWith(color: c.textoSecundario),
        ),
        if (rotuloAcao != null) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAcao,
              icon: const Icon(Icons.add_rounded, size: 26),
              label: Text(rotuloAcao!),
            ),
          ),
        ],
        if (destaques.isNotEmpty) ...[
          const SizedBox(height: 28),
          for (final (icone, texto) in destaques)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Icon(icone, color: c.destaque, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(texto, style: context.textos.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Selo da marca: o "S" caligráfico branco num círculo azul (mesma arte do
/// ícone do app).
class SeloMarca extends StatelessWidget {
  final double tamanho;

  const SeloMarca({super.key, this.tamanho = 96});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SeniCare',
      image: true,
      child: Image.asset(
        'assets/branding/selo.png',
        width: tamanho,
        height: tamanho,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Card de vidro do tema Claro: branco translúcido sobre as manchas do
/// fundo, borda visível (3:1) com um brilho branco por dentro — a "aresta"
/// do vidro — e sombra só do lado de fora (não suja o vidro).
class _CartaoDeVidro extends StatelessWidget {
  final BorderRadius raio;
  final Color corDaBorda;
  final VoidCallback? onTap;
  final Widget child;

  const _CartaoDeVidro({
    required this.raio,
    required this.corDaBorda,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: raio,
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E1E3A8A),
            blurRadius: 16,
            blurStyle: BlurStyle.outer,
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _PintorAresta(raio, corDaBorda),
        child: Material(
          color: const Color(0xA6FFFFFF), // branco 65%
          borderRadius: raio,
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            // Reflexo: mais claro no canto de cima, como luz no vidro.
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x80FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
            child: InkWell(onTap: onTap, child: child),
          ),
        ),
      ),
    );
  }
}

class _PintorAresta extends CustomPainter {
  final BorderRadius raio;
  final Color cor;

  const _PintorAresta(this.raio, this.cor);

  @override
  void paint(Canvas canvas, Size size) {
    final RRect fora = raio.toRRect(Offset.zero & size).deflate(0.6);
    canvas.drawRRect(
      fora,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = cor,
    );
    final Rect r = Offset.zero & size;
    canvas.drawRRect(
      fora.deflate(1.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_PintorAresta old) => old.cor != cor || old.raio != raio;
}

/// Avatar circular do remédio: a foto (decodificada já no tamanho exibido)
/// ou, sem foto / arquivo apagado, o ícone de cápsula.
class AvatarRemedio extends StatelessWidget {
  final String? fotoPath;
  final double raio;

  const AvatarRemedio({super.key, required this.fotoPath, this.raio = 28});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final double d = raio * 2;
    final Widget semFoto = Container(
      width: d,
      height: d,
      color: c.suave,
      alignment: Alignment.center,
      child: IconeCapsula(tamanho: raio * 1.1, cor: c.destaque),
    );
    final int px = (d * MediaQuery.devicePixelRatioOf(context)).round();
    // No tema Claro o círculo #E8EEF6 sumia sobre o card branco: ganha um
    // contorno.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: c.tema == TemaApp.claro
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.borda, width: 1.2),
            )
          : const BoxDecoration(),
      child: ClipOval(
        child: SizedBox(
          width: d,
          height: d,
          child: fotoPath == null
              ? semFoto
              : Image.file(
                  File(fotoPath!),
                  fit: BoxFit.cover,
                  cacheWidth: px,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => semFoto,
                ),
        ),
      ),
    );
  }
}

/// Cápsula desenhada no Canvas (metade sólida, metade translúcida). O
/// Icons.medication do Material desenha um frasco com cruz, não uma pílula.
class IconeCapsula extends StatelessWidget {
  final double tamanho;
  final Color cor;

  const IconeCapsula({super.key, required this.tamanho, required this.cor});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: tamanho,
    height: tamanho,
    child: CustomPaint(painter: _PintorCapsula(cor)),
  );
}

class _PintorCapsula extends CustomPainter {
  final Color cor;

  const _PintorCapsula(this.cor);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 4);
    final double largura = size.width * 0.9;
    final double altura = size.height * 0.42;
    final Rect r = Rect.fromCenter(
      center: Offset.zero,
      width: largura,
      height: altura,
    );
    final RRect capsula = RRect.fromRectAndRadius(
      r,
      Radius.circular(altura / 2),
    );
    canvas.save();
    canvas.clipRRect(capsula);
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, largura / 2, altura),
      Paint()..color = cor,
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left + largura / 2, r.top, largura / 2, altura),
      Paint()..color = cor.withValues(alpha: 0.3),
    );
    canvas.restore();
    canvas.drawRRect(
      capsula,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = altura * 0.14
        ..color = cor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PintorCapsula old) => old.cor != cor;
}

// ---------------------------------------------------------------------------
// Janelas com o tema certo
// ---------------------------------------------------------------------------

/// Diálogos, folhas e seletores são superfícies claras (ou escuras no tema
/// Escuro). No tema Padrão o texto do app é branco — sem isto, o conteúdo
/// das janelas ficaria branco sobre branco.
Widget comTemaDeJanela(BuildContext context, Widget child) {
  if (context.cores.tema == TemaApp.padrao) {
    return Theme(data: temaDeJanelaPadrao, child: child);
  }
  return child;
}

Future<T?> mostrarDialogo<T>(BuildContext context, WidgetBuilder builder) =>
    showDialog<T>(
      context: context,
      builder: (ctx) => comTemaDeJanela(context, Builder(builder: builder)),
    );

Future<T?> mostrarFolha<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => comTemaDeJanela(context, Builder(builder: builder)),
    );

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String confirmarRotulo,
  bool destrutivo = false,
}) async {
  final bool? ok = await mostrarDialogo<bool>(
    context,
    (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Voltar'),
        ),
        FilledButton(
          style: destrutivo
              ? FilledButton.styleFrom(
                  backgroundColor: ctx.cores.perigo,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmarRotulo),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void avisar(BuildContext context, String mensagem, {bool erro = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro
            ? const Color(0xFFB3261E)
            : const Color(0xFF1B5E20),
      ),
    );
}

// ---------------------------------------------------------------------------
// Opções justificadas
// ---------------------------------------------------------------------------

/// Uma opção de [GrupoDeOpcoes].
class Opcao {
  final String rotulo;
  final bool selecionada;
  final VoidCallback onTap;

  /// Ícone à esquerda (ex.: lápis em "Outra"). Opções com ícone são ações,
  /// não escolhas.
  final IconData? icone;
  final String? dica;

  /// Fica sempre depois das demais ("Outro", "Outra", "Ver todos") — não
  /// sobe para preencher vãos das linhas de cima.
  final bool noFim;

  const Opcao({
    required this.rotulo,
    required this.selecionada,
    required this.onTap,
    this.icone,
    this.dica,
    this.noFim = false,
  });
}

/// Grupo de chips de escolha que aproveita os vãos das linhas: quando uma
/// opção não cabe no fim de uma linha, ela desce, mas as opções seguintes
/// que couberem naquele vão sobem para preenchê-lo (ex.: "Alergia" ao lado
/// de "Pressão alta"). Assim não sobram buracos à direita.
///
/// O espaço do ✓ da opção marcada fica reservado em cada linha, para que
/// marcar uma opção nunca faça as outras trocarem de lugar.
class GrupoDeOpcoes extends StatelessWidget {
  final List<Opcao> opcoes;

  /// Mostra o ✓ na opção marcada. Desligado nos dias da semana (opções
  /// curtíssimas, de seleção múltipla).
  final bool comMarca;
  final double espaco;

  const GrupoDeOpcoes({
    super.key,
    required this.opcoes,
    this.comMarca = true,
    this.espaco = 8,
  });

  /// Largura que o ✓ acrescenta a um chip marcado: 16 dp, que crescem com
  /// o tamanho do texto (medido no ChoiceChip do tema).
  static double _larguraDaMarca(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(16).ceilToDouble();

  Widget _chip(Opcao o) {
    final Widget chip = o.icone != null
        ? ActionChip(
            avatar: Icon(o.icone, size: 18),
            label: Text(o.rotulo),
            onPressed: o.onTap,
          )
        : ChoiceChip(
            label: Text(o.rotulo),
            selected: o.selecionada,
            showCheckmark: comMarca,
            onSelected: (_) => o.onTap(),
          );
    return o.dica == null ? chip : Tooltip(message: o.dica!, child: chip);
  }

  @override
  Widget build(BuildContext context) {
    final List<Opcao> livres = [
      for (final o in opcoes)
        if (!o.noFim) o,
    ];
    final List<Opcao> doFim = [
      for (final o in opcoes)
        if (o.noFim) o,
    ];
    return _LinhasPreenchidas(
      espaco: espaco,
      reserva: comMarca ? _larguraDaMarca(context) : 0,
      quantosNoFim: doFim.length,
      marcadas: [
        for (final o in [...livres, ...doFim]) comMarca && o.selecionada,
      ],
      children: [
        for (final o in [...livres, ...doFim]) _chip(o),
      ],
    );
  }
}

class _LinhasPreenchidas extends MultiChildRenderObjectWidget {
  final double espaco;
  final double reserva;
  final int quantosNoFim;
  final List<bool> marcadas;

  const _LinhasPreenchidas({
    required this.espaco,
    required this.reserva,
    required this.quantosNoFim,
    required this.marcadas,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLinhasPreenchidas(espaco, reserva, quantosNoFim, marcadas);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLinhasPreenchidas render,
  ) {
    render
      ..espaco = espaco
      ..reserva = reserva
      ..quantosNoFim = quantosNoFim
      ..marcadas = marcadas;
  }
}

class _DadosDaLinha extends ContainerBoxParentData<RenderBox> {}

class _RenderLinhasPreenchidas extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DadosDaLinha>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DadosDaLinha> {
  _RenderLinhasPreenchidas(
    this._espaco,
    this._reserva,
    this._quantosNoFim,
    this._marcadas,
  );

  /// Quais filhos estão marcados (já desenhados com o ✓).
  List<bool> _marcadas;
  set marcadas(List<bool> v) {
    if (listEquals(v, _marcadas)) return;
    _marcadas = v;
    markNeedsLayout();
  }

  double _espaco;
  set espaco(double v) {
    if (v == _espaco) return;
    _espaco = v;
    markNeedsLayout();
  }

  double _reserva;
  set reserva(double v) {
    if (v == _reserva) return;
    _reserva = v;
    markNeedsLayout();
  }

  int _quantosNoFim;
  set quantosNoFim(int v) {
    if (v == _quantosNoFim) return;
    _quantosNoFim = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DadosDaLinha) child.parentData = _DadosDaLinha();
  }

  List<RenderBox> get _filhos {
    final List<RenderBox> lista = [];
    RenderBox? c = firstChild;
    while (c != null) {
      lista.add(c);
      c = childAfter(c);
    }
    return lista;
  }

  /// Distribui os filhos em linhas ("first fit"): cada opção vai para a
  /// primeira linha onde ainda cabe; as do fim só tentam a última linha.
  /// Devolve as linhas (com os índices na ordem de exibição) e a altura.
  (List<List<int>>, double) _empacotar(double maximo, List<Size> tamanhos) {
    final List<List<int>> linhas = [];
    final List<double> usadas = [];
    // A linha que já tem a opção marcada já inclui a largura do ✓; as
    // demais reservam esse espaço. Assim, marcar outra opção troca a largura
    // de lugar sem mudar nenhuma opção de linha.
    final List<bool> comMarcada = [];
    final int inicioDoFim = tamanhos.length - _quantosNoFim;
    for (int i = 0; i < tamanhos.length; i++) {
      final double w = tamanhos[i].width;
      int destino = -1;
      final int primeira = i >= inicioDoFim ? linhas.length - 1 : 0;
      final bool marcada = i < _marcadas.length && _marcadas[i];
      for (int l = math.max(primeira, 0); l < linhas.length; l++) {
        final double reserva = comMarcada[l] || marcada ? 0 : _reserva;
        final double extra = comMarcada[l] && marcada ? _reserva : 0;
        if (usadas[l] + _espaco + w + reserva + extra <= maximo) {
          destino = l;
          break;
        }
      }
      if (destino < 0) {
        linhas.add([i]);
        usadas.add(w);
        comMarcada.add(marcada);
      } else {
        linhas[destino].add(i);
        usadas[destino] += _espaco + w;
        comMarcada[destino] = comMarcada[destino] || marcada;
      }
    }
    double altura = 0;
    for (int l = 0; l < linhas.length; l++) {
      if (l > 0) altura += _espaco;
      altura += linhas[l].map((i) => tamanhos[i].height).fold(0.0, math.max);
    }
    return (linhas, altura);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final BoxConstraints filho = BoxConstraints(maxWidth: constraints.maxWidth);
    final tamanhos = [for (final c in _filhos) c.getDryLayout(filho)];
    final (_, double altura) = _empacotar(constraints.maxWidth, tamanhos);
    return constraints.constrain(Size(constraints.maxWidth, altura));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _filhos.map((c) => c.getMinIntrinsicWidth(height)).fold(0.0, math.max);

  @override
  double computeMaxIntrinsicWidth(double height) {
    final filhos = _filhos;
    if (filhos.isEmpty) return 0;
    return filhos
            .map((c) => c.getMaxIntrinsicWidth(height))
            .reduce((a, b) => a + b) +
        _espaco * (filhos.length - 1) +
        _reserva;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  void performLayout() {
    final double maximo = constraints.maxWidth;
    final filhos = _filhos;
    for (final c in filhos) {
      c.layout(BoxConstraints(maxWidth: maximo), parentUsesSize: true);
    }
    final (linhas, double altura) = _empacotar(maximo, [
      for (final c in filhos) c.size,
    ]);
    double y = 0;
    for (final linha in linhas) {
      final double h = linha
          .map((i) => filhos[i].size.height)
          .fold(0.0, math.max);
      double x = 0;
      for (final i in linha) {
        final RenderBox c = filhos[i];
        (c.parentData! as _DadosDaLinha).offset = Offset(
          x,
          y + (h - c.size.height) / 2,
        );
        x += c.size.width + _espaco;
      }
      y += h + _espaco;
    }
    size = constraints.constrain(Size(maximo, altura));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
