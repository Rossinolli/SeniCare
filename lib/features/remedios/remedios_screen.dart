// Aba Remédios: os remédios em uso, com dose, frequência e motivo. Tocar
// num remédio abre a edição; o botão flutuante cadastra um novo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/componentes.dart';
import '../../core/estado.dart';
import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../domain/dose_schedule.dart';
import '../../domain/medicamento.dart';
import 'formulario_remedio_screen.dart';

class RemediosScreen extends ConsumerWidget {
  const RemediosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Medicamento>> meds = ref.watch(
      medicamentosAtivosProvider,
    );
    final bool estoque = ref.watch(preferenciasProvider).estoqueAtivo;

    final bool vazio = meds.value?.isEmpty ?? true;
    return Scaffold(
      // Com a lista vazia, o estado vazio já tem o botão de adicionar.
      floatingActionButton: vazio
          ? null
          : FloatingActionButton.extended(
              onPressed: () => abrirFormularioRemedio(context),
              icon: const Icon(Icons.add_rounded, size: 28),
              label: const Text('Adicionar remédio'),
            ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          ConteudoResponsivo(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const TituloCaligrafico('Meus remédios'),
                const SizedBox(height: 16),
                ...meds.when(
                  loading: () => const [
                    Center(child: CircularProgressIndicator()),
                  ],
                  error: (e, _) => [Text('Erro ao carregar: $e')],
                  data: (lista) => lista.isEmpty
                      ? [
                          EstadoVazio(
                            icone: Icons.medication_rounded,
                            titulo: 'Nenhum remédio ainda',
                            mensagem:
                                'Toque em "Adicionar remédio" para cadastrar o primeiro.',
                            rotuloAcao: 'Adicionar remédio',
                            onAcao: () => abrirFormularioRemedio(context),
                          ),
                        ]
                      : [
                          for (final m in lista) ...[
                            _CartaoRemedio(
                              medicamento: m,
                              mostrarEstoque: estoque,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoRemedio extends StatelessWidget {
  final Medicamento medicamento;
  final bool mostrarEstoque;

  const _CartaoRemedio({
    required this.medicamento,
    required this.mostrarEstoque,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final Medicamento m = medicamento;
    final DateTime? fim = m.dataFim;
    final bool encerrado =
        fim != null && fim.isBefore(inicioDoDia(DateTime.now()));
    final List<(IconData, String)> linhas = [
      if (m.textoDose != null) (Icons.medication_liquid_rounded, m.textoDose!),
      (Icons.schedule_rounded, DoseSchedule.descreverFrequencia(m)),
      (
        Icons.event_rounded,
        fim == null
            ? 'Uso contínuo'
            : (encerrado
                  ? 'Terminou em ${dataCurta(fim)}'
                  : 'Até ${dataCurta(fim)}'),
      ),
      if (mostrarEstoque && (m.quantidadeTotal ?? 0) > 0)
        (
          Icons.inventory_2_rounded,
          'Estoque informado: ${m.quantidadeTotal} '
              '${m.formaFarmaceutica?.plural ?? 'unidades'}',
        ),
    ];

    // Ícones acompanham o tamanho do texto (na fonte máxima ficavam
    // pequenos e acima da linha).
    final TextScaler escala = MediaQuery.textScalerOf(context);
    final double icone = escala.scale(20).clamp(20, 32);
    return Opacity(
      opacity: encerrado ? 0.7 : 1,
      child: Cartao(
        onTap: () => abrirFormularioRemedio(context, medicamento: m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarRemedio(fotoPath: m.fotoPath, raio: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.nome, style: context.textos.titleLarge),
                  if (m.textoMotivo != null) ...[
                    const SizedBox(height: 6),
                    _Etiqueta(m.textoMotivo!),
                  ],
                  const SizedBox(height: 8),
                  for (final (ic, texto) in linhas)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Centraliza o ícone na altura da 1ª linha.
                          SizedBox(
                            height: escala.scale(
                              (context.textos.bodyMedium?.fontSize ?? 16) *
                                  (context.textos.bodyMedium?.height ?? 1.4),
                            ),
                            child: Icon(
                              ic,
                              size: icone,
                              color: c.textoSecundario,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              texto,
                              style: context.textos.bodyMedium?.copyWith(
                                color: c.textoSecundario,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Espaço próprio para o lápis: o nome não encosta nele.
            const SizedBox(width: 8),
            Icon(Icons.edit_rounded, color: c.textoSecundario),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;

  const _Etiqueta(this.texto);

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.suave,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.borda),
      ),
      child: Text(
        texto,
        style: context.textos.labelMedium?.copyWith(color: c.texto),
      ),
    );
  }
}
