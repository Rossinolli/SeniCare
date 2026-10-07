// Preferências do usuário (tema, tamanho do texto, modo de aviso...), lidas
// e gravadas sempre pelas mesmas chaves e com os mesmos valores padrão.

import 'package:shared_preferences/shared_preferences.dart';

enum TemaApp {
  /// Gradiente azul da marca.
  padrao('Default', 'Padrão'),
  claro('Light', 'Claro'),
  escuro('Dark', 'Escuro');

  /// Valor gravado (mantido igual ao das versões anteriores).
  final String valor;
  final String rotulo;

  const TemaApp(this.valor, this.rotulo);

  static TemaApp doValor(String? v) =>
      values.firstWhere((t) => t.valor == v, orElse: () => padrao);
}

enum ModoAviso {
  ambos('both', 'Notificações e alarmes'),
  apenasNotificacoes('notifications_only', 'Apenas notificações'),
  apenasAlarmes('alarms_only', 'Apenas alarmes');

  final String valor;
  final String rotulo;

  const ModoAviso(this.valor, this.rotulo);

  static ModoAviso doValor(String? v) =>
      values.firstWhere((m) => m.valor == v, orElse: () => ambos);

  /// O alarme ocupa a tela inteira e toca em loop?
  bool get telaCheia => this != apenasNotificacoes;

  /// Há o lembrete 30 minutos antes?
  bool get lembretePrevio => this != apenasAlarmes;
}

class ChavesPreferencia {
  ChavesPreferencia._();

  static const String tema = 'theme_choice';
  // Chave nova: a antiga ('font_size') guardava um multiplicador de 0,8 a
  // 1,1 que começava no MÍNIMO — o oposto do que um público idoso precisa.
  static const String escalaTexto = 'escala_texto';
  static const String estoqueAtivo = 'reabastecimento_lembrete';
  static const String modoAviso = 'alert_mode';
  static const String somAlarme = 'alarm_sound_enabled';
  static const String vibracaoAlarme = 'alarm_vibration_enabled';
  static const String viuApresentacao = 'has_seen_splash';
  static const String miuiAvisoMostrado = 'miui_aviso_mostrado';
}

class Preferencias {
  final TemaApp tema;

  /// Multiplicador do tamanho do texto, aplicado SOBRE a escala de fonte do
  /// próprio Android (acessibilidade do sistema é respeitada, não travada).
  final double escalaTexto;
  final bool estoqueAtivo;
  final ModoAviso modoAviso;
  final bool somAlarme;
  final bool vibracaoAlarme;
  final bool viuApresentacao;

  static const double escalaMinima = 0.9;
  static const double escalaMaxima = 1.6;
  static const double escalaPadrao = 1.0;

  const Preferencias({
    this.tema = TemaApp.padrao,
    this.escalaTexto = escalaPadrao,
    this.estoqueAtivo = false,
    this.modoAviso = ModoAviso.ambos,
    this.somAlarme = true,
    this.vibracaoAlarme = true,
    this.viuApresentacao = false,
  });

  factory Preferencias.ler(SharedPreferences p) => Preferencias(
    tema: TemaApp.doValor(p.getString(ChavesPreferencia.tema)),
    escalaTexto: (p.getDouble(ChavesPreferencia.escalaTexto) ?? escalaPadrao)
        .clamp(escalaMinima, escalaMaxima),
    estoqueAtivo: p.getBool(ChavesPreferencia.estoqueAtivo) ?? false,
    modoAviso: ModoAviso.doValor(p.getString(ChavesPreferencia.modoAviso)),
    somAlarme: p.getBool(ChavesPreferencia.somAlarme) ?? true,
    vibracaoAlarme: p.getBool(ChavesPreferencia.vibracaoAlarme) ?? true,
    viuApresentacao: p.getBool(ChavesPreferencia.viuApresentacao) ?? false,
  );

  /// Lê do disco, descartando o cache em memória: os alarmes também rodam
  /// em motores Flutter de segundo plano, que precisam enxergar a última
  /// escolha feita na tela de Ajustes.
  static Future<Preferencias> lerAtualizado() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.reload();
    return Preferencias.ler(p);
  }

  Preferencias copyWith({
    TemaApp? tema,
    double? escalaTexto,
    bool? estoqueAtivo,
    ModoAviso? modoAviso,
    bool? somAlarme,
    bool? vibracaoAlarme,
    bool? viuApresentacao,
  }) => Preferencias(
    tema: tema ?? this.tema,
    escalaTexto: escalaTexto ?? this.escalaTexto,
    estoqueAtivo: estoqueAtivo ?? this.estoqueAtivo,
    modoAviso: modoAviso ?? this.modoAviso,
    somAlarme: somAlarme ?? this.somAlarme,
    vibracaoAlarme: vibracaoAlarme ?? this.vibracaoAlarme,
    viuApresentacao: viuApresentacao ?? this.viuApresentacao,
  );

  Future<void> salvar(SharedPreferences p) async {
    await p.setString(ChavesPreferencia.tema, tema.valor);
    await p.setDouble(ChavesPreferencia.escalaTexto, escalaTexto);
    await p.setBool(ChavesPreferencia.estoqueAtivo, estoqueAtivo);
    await p.setString(ChavesPreferencia.modoAviso, modoAviso.valor);
    await p.setBool(ChavesPreferencia.somAlarme, somAlarme);
    await p.setBool(ChavesPreferencia.vibracaoAlarme, vibracaoAlarme);
    await p.setBool(ChavesPreferencia.viuApresentacao, viuApresentacao);
  }
}
