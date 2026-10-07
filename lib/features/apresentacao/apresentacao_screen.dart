// Tela de abertura exibida na primeira vez que o app é aberto: o selo da
// marca e o nome "SeniCare" — no estilo do Facebook: fonte do sistema em
// negrito, sem fonte baixada da internet, então aparece igual em qualquer
// aparelho. Nas aberturas seguintes, o Android mostra só a splash nativa
// (o selo) e o app vai direto para o Início.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/componentes.dart';
import '../../core/estado.dart';
import '../../core/preferencias.dart';
import '../../core/tema.dart';

class ApresentacaoScreen extends ConsumerStatefulWidget {
  const ApresentacaoScreen({super.key});

  @override
  ConsumerState<ApresentacaoScreen> createState() => _ApresentacaoState();
}

class _ApresentacaoState extends ConsumerState<ApresentacaoScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1800), _seguir);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// A raiz do app (RaizDoApp) observa esta preferência e troca para a
  /// tela principal com um fade — sem navegação manual.
  Future<void> _seguir() async {
    if (!mounted) return;
    await ref.read(preferenciasProvider.notifier).marcarApresentacaoVista();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Scaffold(
      body: FundoDoTema(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // No tema Padrão o selo (azul) ficaria azul sobre azul:
                // ganha um anel branco para se destacar do fundo.
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.tema == TemaApp.padrao
                        ? Colors.white
                        : Colors.transparent,
                  ),
                  child: const SeloMarca(tamanho: 112),
                ),
                const SizedBox(height: 24),
                Text(
                  'SeniCare',
                  // Logotipo: tamanho fixo, não acompanha a escala de texto.
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.5,
                    // Branco no Padrão, azul da marca no Claro (como o
                    // "facebook" azul sobre branco), azul-claro no Escuro.
                    color: c.destaque,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Seu remédio na hora certa',
                  style: context.textos.bodyLarge?.copyWith(
                    color: c.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
