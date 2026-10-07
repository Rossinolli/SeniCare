// Componentes visuais compartilhados por todas as telas: cartão, cabeçalho,
// estado vazio, selo da marca, avatar do remédio e as janelas (diálogo,
// folha inferior, seletores) já com o tema certo.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) =>
      DecoratedBox(decoration: context.cores.decoracaoDeFundo, child: child);
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
    return Material(
      color: cor ?? c.superficie,
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
    return ClipOval(
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
