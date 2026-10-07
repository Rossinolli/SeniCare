// Tela Início: o dia de hoje, dose a dose. Mostra quanto do dia já foi
// cumprido, a próxima dose e permite responder cada uma com um toque.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/componentes.dart';
import '../../core/estado.dart';
import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../domain/agenda.dart';
import '../../domain/medicamento.dart';
import '../../services/notification_service.dart';
import '../remedios/formulario_remedio_screen.dart';

class InicioScreen extends ConsumerWidget {
  final VoidCallback irParaRemedios;

  const InicioScreen({super.key, required this.irParaRemedios});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime agora = ref.watch(relogioProvider).value ?? DateTime.now();
    final AsyncValue<AgendaDoDia> agenda = ref.watch(agendaDeHojeProvider);
    final List<Medicamento>? meds = ref.watch(medicamentosAtivosProvider).value;
    final AlarmHealth? saude = ref.watch(saudeDoAlarmeProvider).value;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ConteudoResponsivo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const TituloCaligrafico('Olá'),
              Text(
                dataPorExtenso(agora),
                style: context.textos.bodyLarge?.copyWith(
                  color: context.cores.textoSecundario,
                ),
              ),
              const SizedBox(height: 20),
              if (saude != null && !saude.essenciaisOk) ...[
                _AvisoDePermissao(saude: saude),
                const SizedBox(height: 16),
              ],
              ...agenda.when(
                loading: () => const [
                  Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (e, _) => [
                  Text('Não foi possível carregar a agenda de hoje. ($e)'),
                ],
                data: (a) => _conteudo(context, a, meds ?? const []),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _conteudo(
    BuildContext context,
    AgendaDoDia agenda,
    List<Medicamento> meds,
  ) {
    if (meds.isEmpty) {
      return [
        EstadoVazio(
          icone: Icons.medication_rounded,
          titulo: 'Vamos começar?',
          mensagem:
              'Cadastre seu primeiro remédio e o SeniCare avisa você na hora certa de tomar.',
          rotuloAcao: 'Adicionar meu primeiro remédio',
          onAcao: () => abrirFormularioRemedio(context),
          destaques: const [
            (
              Icons.alarm_rounded,
              'Alarme na hora exata, mesmo com o celular bloqueado',
            ),
            (Icons.touch_app_rounded, 'Responda "Tomei" direto na notificação'),
            (
              Icons.insights_rounded,
              'Histórico e relatório para levar ao médico',
            ),
          ],
        ),
      ];
    }
    if (agenda.doses.isEmpty) {
      return [
        Cartao(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Icon(
                Icons.event_available_rounded,
                size: 48,
                color: context.cores.sucesso,
              ),
              const SizedBox(height: 12),
              Text(
                'Nenhuma dose para hoje',
                textAlign: TextAlign.center,
                style: context.textos.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Seus remédios não têm horário marcado para hoje.',
                textAlign: TextAlign.center,
                style: context.textos.bodyMedium?.copyWith(
                  color: context.cores.textoSecundario,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: irParaRemedios,
                child: const Text('Ver meus remédios'),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      _ResumoDoDia(agenda: agenda),
      const CabecalhoSecao('Doses de hoje'),
      for (final dose in agenda.doses) ...[
        _CartaoDose(dose: dose),
        const SizedBox(height: 12),
      ],
    ];
  }
}

class _ResumoDoDia extends StatelessWidget {
  final AgendaDoDia agenda;

  const _ResumoDoDia({required this.agenda});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final DoseDoDia? proxima = agenda.proxima;
    final double progresso = agenda.total == 0
        ? 0
        : agenda.tomadas / agenda.total;
    final int naoTomadas = agenda.doses
        .where((d) => d.status == StatusDose.naoTomada)
        .length;
    final (IconData icone, Color cor, String mensagem) = proxima != null
        ? (
            Icons.schedule_rounded,
            c.textoSecundario,
            'Próxima: ${hhmm(proxima.horario)} · ${proxima.medicamento.nome}',
          )
        : naoTomadas > 0
        ? (
            Icons.info_rounded,
            c.atencao,
            naoTomadas == 1
                ? '1 dose não foi tomada hoje.'
                : '$naoTomadas doses não foram tomadas hoje.',
          )
        : (Icons.verified_rounded, c.sucesso, 'Tudo certo por hoje!');
    return Cartao(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Você tomou ${agenda.tomadas} de ${agenda.total} '
            '${agenda.total == 1 ? 'dose' : 'doses'} hoje',
            style: context.textos.titleMedium,
          ),
          const SizedBox(height: 12),
          Semantics(
            label: '${(progresso * 100).round()}% das doses de hoje',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progresso,
                minHeight: 12,
                backgroundColor: c.suave,
                color: c.sucesso,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(icone, color: cor),
              const SizedBox(width: 10),
              Expanded(child: Text(mensagem, style: context.textos.bodyLarge)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Aparência de cada status: ícone + texto (nunca só a cor — acessível
/// para quem tem daltonismo).
(IconData, Color, String) aparenciaDoStatus(BuildContext context, DoseDoDia d) {
  final c = context.cores;
  return switch (d.status) {
    StatusDose.tomada => (
      Icons.check_circle_rounded,
      c.sucesso,
      'Tomada às ${hhmm(d.registros.last.dataTomada)}',
    ),
    StatusDose.naoTomada => (Icons.cancel_rounded, c.perigo, 'Não tomada'),
    StatusDose.atrasada => (Icons.error_rounded, c.atencao, 'Atrasada'),
    StatusDose.agora => (
      Icons.notifications_active_rounded,
      c.destaque,
      'Hora de tomar',
    ),
    StatusDose.futura => (
      Icons.radio_button_unchecked_rounded,
      c.textoSecundario,
      'A tomar',
    ),
  };
}

class _CartaoDose extends ConsumerWidget {
  final DoseDoDia dose;

  const _CartaoDose({required this.dose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cores;
    final Medicamento med = dose.medicamento;
    final (IconData icone, Color cor, String rotulo) = aparenciaDoStatus(
      context,
      dose,
    );
    final String? detalhe = med.textoDose;
    final bool destacar =
        dose.status == StatusDose.agora || dose.status == StatusDose.atrasada;
    // A coluna do horário cresce com a escala do texto (sem isso "19:49"
    // quebrava em duas linhas a 160%); em escalas grandes o avatar sai para
    // sobrar espaço ao nome do remédio.
    final TextScaler escala = MediaQuery.textScalerOf(context);
    final double larguraHorario = escala.scale(64);
    final bool comAvatar = escala.scale(1) <= 1.35;

    return Semantics(
      button: true,
      label: '${hhmm(dose.horario)}, ${med.nome}, $rotulo',
      excludeSemantics: true,
      child: Cartao(
        corDaBorda: destacar ? cor : null,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        onTap: () => mostrarAcoesDaDose(context, ref, dose),
        child: Row(
          children: [
            SizedBox(
              width: larguraHorario,
              child: Text(
                hhmm(dose.horario),
                maxLines: 1,
                softWrap: false,
                style: context.textos.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (comAvatar) ...[
              AvatarRemedio(fotoPath: med.fotoPath, raio: 24),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(med.nome, style: context.textos.titleMedium),
                  if (detalhe != null)
                    Text(
                      detalhe,
                      style: context.textos.bodyMedium?.copyWith(
                        color: c.textoSecundario,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(icone, color: cor, size: 20),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          rotulo,
                          style: context.textos.labelMedium?.copyWith(
                            color: cor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textoSecundario),
          ],
        ),
      ),
    );
  }
}

/// Folha com as ações de uma dose: Tomei / Não vou tomar / Desfazer / Editar.
Future<void> mostrarAcoesDaDose(
  BuildContext context,
  WidgetRef ref,
  DoseDoDia dose,
) async {
  final Medicamento med = dose.medicamento;
  final String? acao = await mostrarFolha<String>(context, (ctx) {
    final c = ctx.cores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(med.nome, style: ctx.textos.headlineSmall),
          Text(
            ['Dose das ${hhmm(dose.horario)}', ?med.textoDose].join(' · '),
            style: ctx.textos.bodyLarge?.copyWith(color: c.textoSecundario),
          ),
          if (med.textoMotivo != null)
            Text(
              'Para: ${med.textoMotivo}',
              style: ctx.textos.bodyMedium?.copyWith(color: c.textoSecundario),
            ),
          const SizedBox(height: 20),
          if (dose.status != StatusDose.tomada)
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, 'tomei'),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Tomei'),
            ),
          if (dose.status != StatusDose.naoTomada &&
              dose.status != StatusDose.tomada) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'nao'),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Não vou tomar'),
            ),
          ],
          if (dose.respondida) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'desfazer'),
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Desfazer resposta'),
            ),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, 'editar'),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Editar remédio'),
          ),
        ],
      ),
    );
  });
  if (acao == null || !context.mounted) return;

  final repo = ref.read(repositorioProvider);
  switch (acao) {
    case 'tomei' || 'nao':
      final bool tomado = acao == 'tomei';
      await repo.registrarResposta(
        med,
        tomado: tomado,
        horarioDose: dose.horario,
      );
      // Se o alarme desta dose ainda estiver tocando/na barra, some.
      await NotificationService().dispensarAlarmeDaDose(med.id, dose.horario);
      if (context.mounted) {
        avisar(
          context,
          tomado ? 'Dose registrada. Muito bem!' : 'Anotado: dose não tomada.',
        );
      }
    case 'desfazer':
      await repo.apagarRegistros(dose.registros.map((r) => r.id));
      // A dose voltou a ficar pendente: se ainda não passou, o alarme dela
      // volta a ser agendado.
      await NotificationService().sincronizarAlarmes();
      if (context.mounted) avisar(context, 'Resposta desfeita.');
    case 'editar':
      await abrirFormularioRemedio(context, medicamento: med);
  }
}

class _AvisoDePermissao extends StatelessWidget {
  final AlarmHealth saude;

  const _AvisoDePermissao({required this.saude});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final String tipo = saude.notificacoes ? 'exactAlarms' : 'notifications';
    return Cartao(
      corDaBorda: c.atencao,
      onTap: () => NotificationService().abrirConfiguracaoDePermissao(tipo),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: c.atencao, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              saude.notificacoes
                  ? 'Os alarmes podem tocar atrasados. Toque aqui para permitir alarmes no horário exato.'
                  : 'As notificações estão desligadas e os alarmes NÃO vão tocar. Toque aqui para permitir.',
              style: context.textos.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
