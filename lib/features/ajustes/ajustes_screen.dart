// Aba Ajustes: aparência, alarmes, permissões, estoque e compartilhamento.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/componentes.dart';
import '../../core/estado.dart';
import '../../core/formatos.dart';
import '../../core/preferencias.dart';
import '../../core/tema.dart';
import '../../domain/dose_schedule.dart';
import '../../domain/medicamento.dart';
import '../../services/indicar_app.dart';
import '../../services/notification_service.dart';

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Preferencias p = ref.watch(preferenciasProvider);
    final ControladorPreferencias ctrl = ref.read(
      preferenciasProvider.notifier,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ConteudoResponsivo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const TituloCaligrafico('Ajustes'),

              const CabecalhoSecao('Aparência'),
              Cartao(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tema', style: context.textos.titleSmall),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final t in TemaApp.values) ...[
                          Expanded(
                            child: _OpcaoTema(
                              tema: t,
                              selecionado: p.tema == t,
                              onTap: () => ctrl.definirTema(t),
                            ),
                          ),
                          if (t != TemaApp.values.last)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                    const Divider(height: 36),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tamanho do texto',
                            style: context.textos.titleSmall,
                          ),
                        ),
                        Text(
                          '${(p.escalaTexto * 100).round()}%',
                          style: context.textos.titleSmall,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('A', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Slider(
                            value: p.escalaTexto,
                            min: Preferencias.escalaMinima,
                            max: Preferencias.escalaMaxima,
                            divisions: 7,
                            label: '${(p.escalaTexto * 100).round()}%',
                            semanticFormatterCallback: (v) =>
                                'Tamanho do texto ${(v * 100).round()} por cento',
                            onChanged: ctrl.definirEscalaTexto,
                          ),
                        ),
                        const Text(
                          'A',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Assim fica o texto do aplicativo.',
                      style: context.textos.bodyLarge,
                    ),
                  ],
                ),
              ),

              const CabecalhoSecao('Alarmes'),
              Cartao(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Como avisar na hora do remédio',
                      style: context.textos.titleSmall,
                    ),
                    RadioGroup<ModoAviso>(
                      groupValue: p.modoAviso,
                      onChanged: (m) {
                        if (m != null) ctrl.definirModoAviso(m);
                      },
                      child: Column(
                        children: [
                          for (final m in ModoAviso.values)
                            RadioListTile<ModoAviso>(
                              value: m,
                              title: Text(m.rotulo),
                              subtitle: Text(switch (m) {
                                ModoAviso.ambos =>
                                  'Lembrete 30 min antes e alarme em tela cheia',
                                ModoAviso.apenasNotificacoes =>
                                  'Só uma notificação, sem tela cheia',
                                ModoAviso.apenasAlarmes =>
                                  'Só o alarme em tela cheia, na hora exata',
                              }, style: context.textos.bodySmall),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 28),
                    SwitchListTile(
                      value: p.somAlarme,
                      title: const Text('Som do alarme'),
                      secondary: const Icon(Icons.volume_up_rounded),
                      onChanged: ctrl.definirSom,
                    ),
                    SwitchListTile(
                      value: p.vibracaoAlarme,
                      title: const Text('Vibração'),
                      secondary: const Icon(Icons.vibration_rounded),
                      onChanged: ctrl.definirVibracao,
                    ),
                  ],
                ),
              ),

              const CabecalhoSecao('Saúde do alarme'),
              const _SaudeDoAlarme(),

              const CabecalhoSecao('Estoque'),
              Cartao(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                child: SwitchListTile(
                  value: p.estoqueAtivo,
                  title: const Text('Avisar quando estiver acabando'),
                  subtitle: Text(
                    'Mostra o campo de estoque no cadastro do remédio',
                    style: context.textos.bodySmall,
                  ),
                  secondary: const Icon(Icons.inventory_2_rounded),
                  onChanged: ctrl.definirEstoque,
                ),
              ),

              const CabecalhoSecao('Compartilhar'),
              Cartao(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.list_alt_rounded),
                      title: const Text('Enviar minha lista de remédios'),
                      subtitle: Text(
                        'Para o cuidador ou o médico (WhatsApp, SMS...)',
                        style: context.textos.bodySmall,
                      ),
                      onTap: () => _compartilharLista(context, ref),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.favorite_border_rounded),
                      title: const Text('Indicar o SeniCare'),
                      subtitle: Text(
                        'Envie o aplicativo para um amigo ou familiar',
                        style: context.textos.bodySmall,
                      ),
                      onTap: () => _indicar(context),
                    ),
                  ],
                ),
              ),

              const CabecalhoSecao('Sobre'),
              Cartao(
                child: Row(
                  children: [
                    const SeloMarca(tamanho: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SeniCare', style: context.textos.titleMedium),
                          Text(
                            'Seus dados ficam só neste aparelho.',
                            style: context.textos.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      // Página de licenças no fundo do tema e sem passar
                      // por baixo dos botões do Android.
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FundoDoTema(
                            child: SafeArea(
                              top: false,
                              child: LicensePage(
                                applicationName: 'SeniCare',
                                applicationIcon: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SeloMarca(tamanho: 64),
                                ),
                                applicationLegalese:
                                    '© 2026 $desenvolvedor. Todos os direitos '
                                    'reservados.',
                              ),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Licenças'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _compartilharLista(BuildContext context, WidgetRef ref) async {
    final List<Medicamento> meds = await ref.read(repositorioProvider).ativos();
    if (!context.mounted) return;
    if (meds.isEmpty) {
      avisar(context, 'Nenhum remédio cadastrado ainda.', erro: true);
      return;
    }
    final StringBuffer t = StringBuffer('Meus remédios (SeniCare):\n');
    for (final m in meds) {
      t.writeln();
      t.writeln('• ${m.nome}${m.textoDose == null ? '' : ' — ${m.textoDose}'}');
      t.writeln('  ${DoseSchedule.descreverFrequencia(m)}');
      if (m.textoMotivo != null) t.writeln('  Para: ${m.textoMotivo}');
      if (m.dataFim != null) t.writeln('  Até ${dataCurta(m.dataFim!)}');
    }
    await SharePlus.instance.share(ShareParams(text: t.toString()));
  }
}

/// Autor do aplicativo, exibido em Ajustes > Licenças.
const String desenvolvedor = 'Hivan';

/// Com link publicado, pergunta se envia o link ou o arquivo; sem link,
/// envia direto o arquivo do aplicativo.
Future<void> _indicar(BuildContext context) async {
  String? escolha = 'arquivo';
  if (IndicarApp.temLink) {
    escolha = await mostrarFolha<String>(
      context,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Enviar o link de download'),
              onTap: () => Navigator.pop(ctx, 'link'),
            ),
            ListTile(
              leading: const Icon(Icons.android_rounded),
              title: const Text('Enviar o aplicativo (arquivo)'),
              subtitle: const Text('Funciona mesmo sem internet na loja'),
              onTap: () => Navigator.pop(ctx, 'arquivo'),
            ),
          ],
        ),
      ),
    );
  }
  if (escolha == 'link') {
    await IndicarApp.enviarLink();
  } else if (escolha == 'arquivo') {
    final bool ok = await IndicarApp.enviarArquivo();
    if (!ok && context.mounted) {
      avisar(context, 'Não foi possível preparar o arquivo.', erro: true);
    }
  }
}

class _OpcaoTema extends StatelessWidget {
  final TemaApp tema;
  final bool selecionado;
  final VoidCallback onTap;

  const _OpcaoTema({
    required this.tema,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final CoresSeniCare previa = coresDoTema(tema);
    final c = context.cores;
    return Semantics(
      selected: selecionado,
      button: true,
      label: 'Tema ${tema.rotulo}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 64,
                  decoration: previa.decoracaoDeFundo.copyWith(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selecionado ? c.destaque : c.borda,
                      width: selecionado ? 3 : 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 16,
                    decoration: BoxDecoration(
                      color: previa.superficie,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: previa.borda),
                    ),
                  ),
                ),
                // O ✓ fica sobre o canto do bloco, não ao lado do nome: na
                // fonte grande ele empurrava o rótulo para duas linhas e o
                // bloco escolhido subia em relação aos outros.
                if (selecionado)
                  Positioned(
                    top: -7,
                    right: -7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.tema == TemaApp.claro ? Colors.white : c.fundo,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 24,
                        color: c.destaque,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Uma linha só, encolhendo se a fonte for muito grande: os três
            // rótulos ficam sempre na mesma altura.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tema.rotulo,
                maxLines: 1,
                style: context.textos.labelLarge?.copyWith(
                  fontWeight: selecionado ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaudeDoAlarme extends ConsumerWidget {
  const _SaudeDoAlarme();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AlarmHealth? s = ref.watch(saudeDoAlarmeProvider).value;
    if (s == null) {
      return const Cartao(child: Center(child: CircularProgressIndicator()));
    }
    Widget item(
      String titulo,
      String descricao,
      bool ok,
      String tipo, {
      bool essencial = false,
    }) {
      final c = context.cores;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: ok ? c.sucesso : (essencial ? c.perigo : c.atencao),
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: context.textos.titleSmall),
                  Text(descricao, style: context.textos.bodySmall),
                  if (!ok)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: () => NotificationService()
                            .abrirConfiguracaoDePermissao(tipo),
                        child: const Text('Permitir'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Cartao(
      child: Column(
        children: [
          if (s.tudoOk)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Tudo pronto: os alarmes vão tocar na hora certa.',
                style: context.textos.bodyMedium?.copyWith(
                  color: context.cores.sucesso,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          item(
            'Notificações',
            'Sem esta permissão nenhum alarme ou lembrete aparece.',
            s.notificacoes,
            'notifications',
            essencial: true,
          ),
          item(
            'Alarmes no horário exato',
            'Garante que o alarme toque no minuto certo.',
            s.alarmesExatos,
            'exactAlarms',
            essencial: true,
          ),
          item(
            'Alarme em tela cheia',
            'Mostra o alarme ocupando a tela, mesmo bloqueada.',
            s.telaCheia,
            'fullScreen',
          ),
          item(
            'Abrir por cima de outros apps',
            'Abre o alarme sozinho mesmo com o celular em uso.',
            s.sobreporApps,
            'overlay',
          ),
          item(
            'Sem restrição de bateria',
            'Impede que a economia de bateria atrase os alarmes.',
            s.semOtimizacaoDeBateria,
            'batteryUnrestricted',
          ),
        ],
      ),
    );
  }
}
