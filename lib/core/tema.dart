// Sistema visual do SeniCare: três temas (Padrão azul, Claro e Escuro)
// definidos num só lugar, com cores semânticas ([CoresSeniCare]) que as
// telas leem via `context.cores` — nenhuma tela decide cor por conta própria
// comparando strings de tema.
//
// Contraste (WCAG 2.1): todo texto principal ≥ 7:1 e secundário ≥ 4,5:1
// sobre o próprio fundo; bordas de campos e cards ≥ 3:1 (exigência para
// componentes de interface). No tema Claro, os cards eram brancos
// translúcidos sobre cinza — as bordas sumiam e o conjunto ficava
// amarelado; agora são superfícies brancas sólidas com borda definida.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'preferencias.dart';

/// Família da fonte caligráfica, EMBUTIDA no app (assets/fonts). Antes ela
/// vinha do pacote google_fonts, que baixa a fonte da internet na primeira
/// execução — sem internet (ou antes do download) o texto aparecia na fonte
/// padrão do sistema. Embutida, aparece igual em qualquer aparelho.
const String fonteCaligrafica = 'GreatVibes';

const Color azulMarca = Color(0xFF1565C0);
const Color azulMarcaEscuro = Color(0xFF0D47A1);

@immutable
class CoresSeniCare extends ThemeExtension<CoresSeniCare> {
  /// De qual tema são estas cores.
  final TemaApp tema;

  /// Fundo das telas (gradiente no tema Padrão).
  final Gradient? fundoGradiente;
  final Color fundo;

  /// Cards e painéis.
  final Color superficie;

  /// Borda de cards e painéis. No tema Claro, ≥ 3:1 sobre a superfície
  /// (WCAG 1.4.11); no Padrão e no Escuro, discreta (o fundo já separa).
  final Color borda;

  /// Contorno de controles interativos não selecionados (opções, chips):
  /// no tema Claro, mais forte que [borda] para deixar claro o que é
  /// tocável; nos demais, igual à borda.
  final Color bordaControle;

  /// Texto principal / secundário / sobre o botão principal.
  final Color texto;
  final Color textoSecundario;

  /// Cor de ação (botões, seleção) e o texto sobre ela.
  final Color destaque;
  final Color sobreDestaque;

  /// Estados da dose.
  final Color sucesso;
  final Color atencao;
  final Color perigo;

  /// Fundo suave de chips e itens não selecionados.
  final Color suave;

  /// Trilho (parte vazia) de barras e anéis de progresso.
  final Color trilha;

  /// Contorno dos campos de formulário.
  final Color campo;

  final Color barraNavegacao;
  final SystemUiOverlayStyle barraDeStatus;

  const CoresSeniCare({
    required this.tema,
    this.fundoGradiente,
    required this.fundo,
    required this.superficie,
    required this.borda,
    required this.bordaControle,
    required this.texto,
    required this.textoSecundario,
    required this.destaque,
    required this.sobreDestaque,
    required this.sucesso,
    required this.atencao,
    required this.perigo,
    required this.suave,
    required this.trilha,
    required this.campo,
    required this.barraNavegacao,
    required this.barraDeStatus,
  });

  BoxDecoration get decoracaoDeFundo => fundoGradiente != null
      ? BoxDecoration(gradient: fundoGradiente)
      : BoxDecoration(color: fundo);

  static const CoresSeniCare padrao = CoresSeniCare(
    tema: TemaApp.padrao,
    fundoGradiente: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [azulMarcaEscuro, azulMarca],
    ),
    fundo: azulMarcaEscuro,
    superficie: Color(0x24FFFFFF), // branco 14%
    borda: Color(0x66FFFFFF), // branco 40%
    bordaControle: Color(0x66FFFFFF),
    texto: Colors.white,
    textoSecundario: Color(0xFFDCE8F7), // 6,5:1 sobre #1565C0
    destaque: Colors.white,
    sobreDestaque: azulMarcaEscuro,
    sucesso: Color(0xFF7CF2A9),
    atencao: Color(0xFFFFD166),
    perigo: Color(0xFFFFB4AB),
    suave: Color(0x1FFFFFFF),
    trilha: Color(0x1FFFFFFF),
    campo: Color(0xCCFFFFFF),
    barraNavegacao: Color(0xFF0B3D91),
    barraDeStatus: SystemUiOverlayStyle.light,
  );

  static const CoresSeniCare claro = CoresSeniCare(
    tema: TemaApp.claro,
    fundo: Color(0xFFEDF1F6), // cinza-azulado frio (sem tom amarelado)
    superficie: Colors.white,
    // Antes #C9D2DE (1,5:1 sobre o branco): as bordas sumiam no tema
    // Claro. Agora 3:1 nos cards e 4,3:1 nos controles.
    borda: Color(0xFF8796AB),
    bordaControle: Color(0xFF6E7B8F),
    texto: Color(0xFF0F172A), // 17:1
    textoSecundario: Color(0xFF475569), // 7,5:1
    destaque: azulMarca,
    sobreDestaque: Colors.white,
    sucesso: Color(0xFF15803D),
    atencao: Color(0xFFB45309),
    perigo: Color(0xFFC62828),
    suave: Color(0xFFE8EEF6),
    // O trilho em #E8EEF6 sumia sobre o branco: o anel do relatório parecia
    // um semicírculo e a barra de progresso não aparecia.
    trilha: Color(0xFFB9C5D5),
    campo: Color(0xFF6B778A), // 4,5:1 — contorno claramente visível
    barraNavegacao: Colors.white,
    barraDeStatus: SystemUiOverlayStyle.dark,
  );

  static const CoresSeniCare escuro = CoresSeniCare(
    tema: TemaApp.escuro,
    fundo: Color(0xFF0B1220),
    superficie: Color(0xFF162032),
    borda: Color(0xFF2E3B52),
    bordaControle: Color(0xFF2E3B52),
    texto: Color(0xFFF1F5F9),
    textoSecundario: Color(0xFFB8C4D6),
    destaque: Color(0xFF7AB8FF),
    sobreDestaque: Color(0xFF0B1220),
    sucesso: Color(0xFF4ADE80),
    atencao: Color(0xFFFBBF24),
    perigo: Color(0xFFF87171),
    suave: Color(0xFF1E2A40),
    trilha: Color(0xFF1E2A40),
    campo: Color(0xFF8391A7),
    barraNavegacao: Color(0xFF111A2B),
    barraDeStatus: SystemUiOverlayStyle.light,
  );

  @override
  CoresSeniCare copyWith() => this;

  @override
  CoresSeniCare lerp(covariant CoresSeniCare? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension TemaNoContexto on BuildContext {
  CoresSeniCare get cores => Theme.of(this).extension<CoresSeniCare>()!;
  TextTheme get textos => Theme.of(this).textTheme;
}

CoresSeniCare coresDoTema(TemaApp tema) => switch (tema) {
  TemaApp.padrao => CoresSeniCare.padrao,
  TemaApp.claro => CoresSeniCare.claro,
  TemaApp.escuro => CoresSeniCare.escuro,
};

/// Tipografia pensada para o público sênior: corpo de 17 px (o padrão do
/// Material é 14), títulos fortes e altura de linha confortável. A fonte é a
/// do sistema (Roboto no Android — a mesma do app do Facebook), presente em
/// todo aparelho; o tamanho final ainda é multiplicado pela escala escolhida
/// em Ajustes e pela do próprio Android.
TextTheme _tipografia(Color texto, Color secundario) => TextTheme(
  displaySmall: TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: texto,
  ),
  headlineSmall: TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: texto,
    height: 1.2,
  ),
  titleLarge: TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: texto,
    height: 1.25,
  ),
  titleMedium: TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    color: texto,
    height: 1.25,
  ),
  titleSmall: TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: texto,
  ),
  bodyLarge: TextStyle(fontSize: 18, color: texto, height: 1.35),
  bodyMedium: TextStyle(fontSize: 17, color: texto, height: 1.35),
  bodySmall: TextStyle(fontSize: 15, color: secundario, height: 1.3),
  labelLarge: TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: texto,
  ),
  labelMedium: TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: texto,
  ),
  labelSmall: TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: secundario,
  ),
);

ThemeData construirTema(TemaApp tema) {
  final CoresSeniCare c = coresDoTema(tema);
  // O tema Padrão é azul com texto branco: para o Material, é um tema escuro.
  final Brightness brilho = tema == TemaApp.claro
      ? Brightness.light
      : Brightness.dark;
  // Esquema do Material coerente com o brilho do tema. No Padrão (azul com
  // texto branco) é um esquema ESCURO; diálogos, folhas e seletores abrem
  // com o tema Claro via `comTemaDeJanela` (mais legíveis que azul sobre
  // azul).
  final ColorScheme esquema = switch (tema) {
    TemaApp.claro => ColorScheme.fromSeed(
      seedColor: azulMarca,
      primary: azulMarca,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: c.texto,
      error: c.perigo,
    ),
    TemaApp.escuro => ColorScheme.fromSeed(
      seedColor: azulMarca,
      brightness: Brightness.dark,
      primary: c.destaque,
      onPrimary: c.sobreDestaque,
      surface: c.superficie,
      onSurface: c.texto,
      error: c.perigo,
    ),
    TemaApp.padrao => ColorScheme.fromSeed(
      seedColor: azulMarca,
      brightness: Brightness.dark,
      primary: Colors.white,
      onPrimary: azulMarcaEscuro,
      surface: const Color(0xFF0B3D91),
      onSurface: Colors.white,
      error: c.perigo,
    ),
  };
  final TextTheme textos = _tipografia(c.texto, c.textoSecundario);
  final OutlineInputBorder bordaCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c.campo, width: 1.4),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brilho,
    colorScheme: esquema,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: textos,
    extensions: [c],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: c.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: c.barraDeStatus,
      titleTextStyle: textos.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tema == TemaApp.padrao ? c.suave : c.superficie,
      labelStyle: TextStyle(color: c.textoSecundario, fontSize: 17),
      floatingLabelStyle: TextStyle(color: c.destaque, fontSize: 17),
      hintStyle: TextStyle(color: c.textoSecundario, fontSize: 17),
      helperStyle: TextStyle(color: c.textoSecundario, fontSize: 14),
      errorStyle: TextStyle(
        color: c.perigo,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: c.textoSecundario,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: bordaCampo,
      enabledBorder: bordaCampo,
      focusedBorder: bordaCampo.copyWith(
        borderSide: BorderSide(color: c.destaque, width: 2.4),
      ),
      errorBorder: bordaCampo.copyWith(
        borderSide: BorderSide(color: c.perigo, width: 1.8),
      ),
      focusedErrorBorder: bordaCampo.copyWith(
        borderSide: BorderSide(color: c.perigo, width: 2.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.destaque,
        foregroundColor: c.sobreDestaque,
        disabledBackgroundColor: c.suave,
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.texto,
        minimumSize: const Size(64, 52),
        side: BorderSide(color: c.campo, width: 1.4),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tema == TemaApp.padrao ? Colors.white : c.destaque,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.destaque,
      foregroundColor: c.sobreDestaque,
      extendedTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    // A cor do texto do chip depende do estado: sem isto, no tema Padrão o
    // chip selecionado (fundo branco) herdava o texto branco do tema e o
    // rótulo sumia (ex.: dias da semana).
    chipTheme: ChipThemeData(
      backgroundColor: c.suave,
      selectedColor: c.destaque,
      disabledColor: c.suave,
      labelStyle: TextStyle(
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.sobreDestaque : c.texto,
        ),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: c.sobreDestaque,
      iconTheme: IconThemeData(color: c.texto, size: 18),
      side: WidgetStateBorderSide.resolveWith(
        (s) => BorderSide(
          color: s.contains(WidgetState.selected)
              ? c.destaque
              : c.bordaControle,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.destaque
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.sobreDestaque : c.texto,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.sobreDestaque : c.texto,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: c.campo, width: 1.2)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.sobreDestaque : c.campo,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.destaque : c.suave,
      ),
      trackOutlineColor: WidgetStateProperty.all(c.campo),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.destaque : c.campo,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.destaque,
      inactiveTrackColor: c.suave,
      thumbColor: c.destaque,
      overlayColor: c.destaque.withValues(alpha: 0.12),
      valueIndicatorColor: tema == TemaApp.padrao ? Colors.white : c.destaque,
      valueIndicatorTextStyle: TextStyle(
        color: tema == TemaApp.padrao ? azulMarcaEscuro : c.sobreDestaque,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerTheme: DividerThemeData(color: c.borda, thickness: 1, space: 24),
    listTileTheme: ListTileThemeData(
      iconColor: c.texto,
      textColor: c.texto,
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 12,
    ),
    iconTheme: IconThemeData(color: c.texto),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.barraNavegacao,
      surfaceTintColor: Colors.transparent,
      indicatorColor: tema == TemaApp.padrao
          ? Colors.white.withValues(alpha: 0.22)
          : c.destaque.withValues(alpha: 0.16),
      height: 76,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 14,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? c.texto : c.textoSecundario,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 28,
          color: s.contains(WidgetState.selected)
              ? (tema == TemaApp.padrao ? Colors.white : c.destaque)
              : c.textoSecundario,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(fontSize: 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tema == TemaApp.escuro ? c.superficie : Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(surfaceTintColor: Colors.transparent),
  );
}

/// Tema usado por diálogos, folhas e seletores quando o app está no tema
/// Padrão (ver `comTemaDeJanela`).
final ThemeData temaDeJanelaPadrao = construirTema(TemaApp.claro);
