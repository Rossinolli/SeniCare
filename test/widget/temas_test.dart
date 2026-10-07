// Monta os componentes visuais nos três temas: garante que nenhum tema
// dispara asserção do Material (ex.: brilho do tema diferente do esquema de
// cores) e que o texto escala sem estourar o layout.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senicare/core/componentes.dart';
import 'package:senicare/core/preferencias.dart';
import 'package:senicare/core/tema.dart';

Widget _app(TemaApp tema, Widget filho, {double escala = 1}) => MaterialApp(
  theme: construirTema(tema),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(360, 800),
      textScaler: TextScaler.linear(escala),
    ),
    child: Scaffold(
      body: FundoDoTema(
        child: SingleChildScrollView(child: ConteudoResponsivo(child: filho)),
      ),
    ),
  ),
);

void main() {
  for (final tema in TemaApp.values) {
    for (final escala in [1.0, 2.0]) {
      testWidgets('tema ${tema.rotulo} com texto em ${escala}x', (t) async {
        await t.pumpWidget(
          _app(
            tema,
            EstadoVazio(
              icone: Icons.medication_rounded,
              titulo: 'Vamos começar?',
              mensagem: 'Cadastre seu primeiro remédio.',
              rotuloAcao: 'Adicionar meu primeiro remédio',
              onAcao: () {},
              destaques: const [(Icons.alarm, 'Alarme na hora exata')],
            ),
            escala: escala,
          ),
        );
        expect(t.takeException(), isNull);
        expect(find.text('Vamos começar?'), findsOneWidget);
      });
    }
  }

  testWidgets('cores semânticas disponíveis em todos os temas', (t) async {
    for (final tema in TemaApp.values) {
      late CoresSeniCare cores;
      await t.pumpWidget(
        MaterialApp(
          theme: construirTema(tema),
          home: Builder(
            builder: (context) {
              cores = context.cores;
              return const SizedBox();
            },
          ),
        ),
      );
      await t.pumpAndSettle(); // fim da animação de troca de tema
      expect(cores.tema, tema);
    }
  });
}
