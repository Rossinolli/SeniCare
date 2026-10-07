// Estado global do app (Riverpod). Antes, tema, tamanho da fonte e outras
// preferências eram repassados de tela em tela por parâmetros
// (currentTheme, fontSizeMultiplier...) e cada tela recarregava o banco por
// conta própria. Agora as telas apenas OBSERVAM estes provedores: o banco
// (Drift) avisa quando algo muda e tudo se atualiza sozinho.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositorio.dart';
import '../domain/agenda.dart';
import '../domain/catalogo.dart';
import '../domain/medicamento.dart';
import '../services/notification_service.dart';
import 'preferencias.dart';

/// Sobrescrito em main() com a instância já carregada.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sobrescrito em main()'),
);

final repositorioProvider = Provider<Repositorio>(
  (ref) => Repositorio.instance,
);

// ---------------------------------------------------------------------------
// Preferências
// ---------------------------------------------------------------------------

class ControladorPreferencias extends Notifier<Preferencias> {
  @override
  Preferencias build() =>
      Preferencias.ler(ref.watch(sharedPreferencesProvider));

  Future<void> _salvar(Preferencias nova, {bool reagendar = false}) async {
    state = nova;
    await nova.salvar(ref.read(sharedPreferencesProvider));
    // Alarmes já agendados usam a configuração antiga: reconcilia.
    if (reagendar) unawaited(NotificationService().sincronizarAlarmes());
  }

  Future<void> definirTema(TemaApp t) => _salvar(state.copyWith(tema: t));

  Future<void> definirEscalaTexto(double e) => _salvar(
    state.copyWith(
      escalaTexto: e.clamp(
        Preferencias.escalaMinima,
        Preferencias.escalaMaxima,
      ),
    ),
  );

  Future<void> definirModoAviso(ModoAviso m) =>
      _salvar(state.copyWith(modoAviso: m), reagendar: true);

  Future<void> definirSom(bool v) =>
      _salvar(state.copyWith(somAlarme: v), reagendar: true);

  Future<void> definirVibracao(bool v) =>
      _salvar(state.copyWith(vibracaoAlarme: v), reagendar: true);

  Future<void> definirEstoque(bool v) =>
      _salvar(state.copyWith(estoqueAtivo: v), reagendar: true);

  Future<void> marcarApresentacaoVista() =>
      _salvar(state.copyWith(viuApresentacao: true));
}

final preferenciasProvider =
    NotifierProvider<ControladorPreferencias, Preferencias>(
      ControladorPreferencias.new,
    );

// ---------------------------------------------------------------------------
// Dados
// ---------------------------------------------------------------------------

final medicamentosAtivosProvider = StreamProvider<List<Medicamento>>(
  (ref) => ref.watch(repositorioProvider).observarAtivos(),
);

final medicamentosArquivadosProvider = StreamProvider<List<Medicamento>>(
  (ref) => ref.watch(repositorioProvider).observarArquivados(),
);

final todosMedicamentosProvider = StreamProvider<List<Medicamento>>(
  (ref) => ref.watch(repositorioProvider).observarTodos(),
);

final registrosDoDiaProvider =
    StreamProvider.family<List<RegistroDose>, DateTime>(
      (ref, dia) => ref.watch(repositorioProvider).observarRegistrosDoDia(dia),
    );

final resumoPorDiaProvider =
    StreamProvider<Map<String, ({int tomadas, int naoTomadas})>>(
      (ref) => ref.watch(repositorioProvider).observarResumoPorDia(),
    );

final totalTomadasPorMedicamentoProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(repositorioProvider).observarTotalTomadasPorMedicamento(),
);

/// Relógio do app (a cada 30 s): mantém "atrasada", "agora" e a virada do
/// dia corretos com a tela aberta.
final relogioProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

/// Agenda de hoje (doses com status), combinando remédios, respostas do dia
/// e relógio.
final agendaDeHojeProvider = Provider<AsyncValue<AgendaDoDia>>((ref) {
  final DateTime agora = ref.watch(relogioProvider).value ?? DateTime.now();
  final DateTime hoje = inicioDoDia(agora);
  final AsyncValue<List<Medicamento>> meds = ref.watch(
    medicamentosAtivosProvider,
  );
  final AsyncValue<List<RegistroDose>> registros = ref.watch(
    registrosDoDiaProvider(hoje),
  );
  if (meds.hasError) return AsyncError(meds.error!, meds.stackTrace!);
  if (registros.hasError) {
    return AsyncError(registros.error!, registros.stackTrace!);
  }
  if (!meds.hasValue || !registros.hasValue) return const AsyncLoading();
  return AsyncData(
    montarAgenda(
      dia: hoje,
      medicamentos: meds.value!,
      registros: registros.value!,
      agora: agora,
    ),
  );
});

/// Permissões que decidem se o alarme toca. Invalidado ao voltar ao app
/// (o usuário pode ter mudado algo nas configurações do Android).
final saudeDoAlarmeProvider = FutureProvider<AlarmHealth>(
  (ref) => NotificationService().verificarSaudeDoAlarme(),
);

/// Catálogo offline de medicamentos (autocompletar do cadastro).
final catalogoProvider = FutureProvider<CatalogoMedicamentos>((ref) async {
  try {
    final String json = await rootBundle.loadString(
      'assets/data/medicamentos_br.json',
    );
    return CatalogoMedicamentos.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  } catch (_) {
    return CatalogoMedicamentos.vazio;
  }
});
