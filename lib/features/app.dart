// Raiz visual do app: tema, idioma, escala de texto e a primeira tela.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/estado.dart';
import '../core/preferencias.dart';
import '../core/tema.dart';
import 'apresentacao/apresentacao_screen.dart';
import 'shell/main_shell.dart';

/// Navegador raiz: a tela de alarme é empilhada nele de qualquer lugar.
final GlobalKey<NavigatorState> navegadorRaiz = GlobalKey<NavigatorState>();

class SeniCareApp extends ConsumerWidget {
  const SeniCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Preferencias prefs = ref.watch(preferenciasProvider);
    return MaterialApp(
      title: 'SeniCare',
      debugShowCheckedModeBanner: false,
      navigatorKey: navegadorRaiz,
      theme: construirTema(prefs.tema),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Tamanho do texto = escala do Android (acessibilidade do sistema,
      // agora RESPEITADA — antes era travada entre 0,9x e 1,15x) × escala
      // escolhida em Ajustes, com teto de 2x para o layout não quebrar.
      builder: (context, child) {
        final MediaQueryData mq = MediaQuery.of(context);
        final double sistema = mq.textScaler.scale(100) / 100;
        final double total = (sistema * prefs.escalaTexto).clamp(0.85, 2.0);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(total)),
          child: child!,
        );
      },
      home: const _RaizDoApp(),
    );
  }
}

/// Primeira abertura: apresentação; depois, o app. Reativo à preferência —
/// a troca acontece com um fade, sem rotas duplicadas.
class _RaizDoApp extends ConsumerWidget {
  const _RaizDoApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool viu = ref.watch(
      preferenciasProvider.select((p) => p.viuApresentacao),
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: viu ? const MainShell() : const ApresentacaoScreen(),
    );
  }
}
