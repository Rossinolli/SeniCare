// Cadastro e edição de remédio.
//
// Pedidos dos orientadores atendidos aqui:
//  * o nome tem SUGESTÕES do catálogo ao digitar as primeiras letras (e o
//    corretor do teclado fica desligado — ele trocava "dipirona");
//  * gramatura, quantidade, forma e motivo são ESCOLHIDOS em listas, não
//    digitados — o alarme sempre mostra um texto padronizado;
//  * intervalo de horas também por seleção (4, 6, 8, 12, 24 h).

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/componentes.dart';
import '../../core/estado.dart';
import '../../core/formatos.dart';
import '../../core/preferencias.dart';
import '../../core/tema.dart';
import '../../data/database.dart';
import '../../domain/catalogo.dart';
import '../../domain/dose_schedule.dart';
import '../../domain/medicamento.dart';
import '../../domain/posologia.dart';
import '../../services/med_photo.dart';
import '../../services/notification_service.dart';

Future<void> abrirFormularioRemedio(
  BuildContext context, {
  Medicamento? medicamento,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => FormularioRemedioScreen(medicamento: medicamento),
  ),
);

class FormularioRemedioScreen extends ConsumerStatefulWidget {
  final Medicamento? medicamento;

  const FormularioRemedioScreen({super.key, this.medicamento});

  @override
  ConsumerState<FormularioRemedioScreen> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<FormularioRemedioScreen> {
  static const List<int> _intervalosComuns = [4, 6, 8, 12, 24];

  final TextEditingController _nome = TextEditingController();
  final FocusNode _focoNome = FocusNode();
  final TextEditingController _complementoMotivo = TextEditingController();
  final TextEditingController _quantidadeCaixa = TextEditingController();
  final TextEditingController _diasAntecedencia = TextEditingController();

  String? _fotoPath;
  final List<String> _fotosNaoSalvas = [];
  bool _salvou = false;

  ItemCatalogo? _itemCatalogo;
  String? _dosagem;
  double _quantidade = 1;
  FormaFarmaceutica _forma = FormaFarmaceutica.comprimido;
  MotivoDeUso? _motivo;

  FrequenciaTipo _frequencia = FrequenciaTipo.horariosFixos;
  final List<HoraDoDia> _horarios = [];
  final Set<int> _dias = {1, 2, 3, 4, 5, 6, 7};
  int _intervalo = 8;

  bool _usoContinuo = true;
  DateTime? _dataFim;

  bool _salvando = false;
  bool _tentouSalvar = false;

  Medicamento? get _original => widget.medicamento;

  @override
  void initState() {
    super.initState();
    final Medicamento? m = _original;
    if (m == null) {
      _diasAntecedencia.text = '5';
      return;
    }
    _nome.text = m.nome;
    _fotoPath = m.fotoPath;
    _dosagem = m.dosagem;
    _quantidade = m.quantidadePorDose ?? 1;
    _forma = m.formaFarmaceutica ?? FormaFarmaceutica.comprimido;
    _motivo = m.motivoDeUso;
    if (_motivo == MotivoDeUso.outro) {
      _complementoMotivo.text = m.descricao ?? '';
    }
    _frequencia = m.frequencia;
    _horarios.addAll(m.horarios);
    _dias
      ..clear()
      ..addAll(m.diasSemana.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : m.diasSemana);
    _intervalo = DoseSchedule.intervaloValido(m) ?? 8;
    _usoContinuo = m.dataFim == null;
    _dataFim = m.dataFim;
    _quantidadeCaixa.text = m.quantidadeTotal?.toString() ?? '';
    _diasAntecedencia.text = m.diasAntecedencia.toString();
  }

  @override
  void dispose() {
    // Saiu sem salvar: descarta as fotos tiradas aqui; salvou: descarta só
    // as que foram trocadas antes de salvar.
    for (final String foto in _fotosNaoSalvas) {
      if (!_salvou || foto != _fotoPath) MedPhotoStorage.apagar(foto);
    }
    _nome.dispose();
    _focoNome.dispose();
    _complementoMotivo.dispose();
    _quantidadeCaixa.dispose();
    _diasAntecedencia.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Validação
  // ------------------------------------------------------------------

  String? get _erroNome =>
      _nome.text.trim().isEmpty ? 'Escreva o nome do remédio.' : null;

  String? get _erroHorario => _horarios.isEmpty
      ? (_frequencia == FrequenciaTipo.intervalo
            ? 'Escolha o horário da primeira dose.'
            : 'Adicione pelo menos um horário.')
      : null;

  String? get _erroDias =>
      _frequencia == FrequenciaTipo.horariosFixos && _dias.isEmpty
      ? 'Escolha pelo menos um dia da semana.'
      : null;

  String? get _erroDataFim => !_usoContinuo && _dataFim == null
      ? 'Escolha até quando tomar, ou marque "Uso contínuo".'
      : null;

  bool get _valido =>
      _erroNome == null &&
      _erroHorario == null &&
      _erroDias == null &&
      _erroDataFim == null;

  // ------------------------------------------------------------------
  // Ações
  // ------------------------------------------------------------------

  void _aoEscolherDoCatalogo(SugestaoCatalogo s) {
    setState(() {
      _itemCatalogo = s.item;
      _nome.text = s.item.nome;
      final FormaFarmaceutica? forma = FormaFarmaceutica.daChave(s.item.forma);
      if (forma != null) _forma = forma;
      // Uma única gramatura comum: já vem marcada.
      if (s.item.dosagens.length == 1) _dosagem = s.item.dosagens.single;
    });
    _focoNome.unfocus();
  }

  Future<void> _escolherFoto() async {
    final String? escolha = await mostrarFolha<String>(
      context,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Tirar foto da caixa'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(ctx, 'galeria'),
            ),
            if (_fotoPath != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: ctx.cores.perigo),
                title: const Text('Remover foto'),
                onTap: () => Navigator.pop(ctx, 'remover'),
              ),
          ],
        ),
      ),
    );
    if (escolha == null) return;
    if (escolha == 'remover') {
      setState(() => _fotoPath = null);
      return;
    }
    try {
      final String? caminho = await MedPhotoStorage.capturar(
        escolha == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
      if (caminho == null || !mounted) return;
      _fotosNaoSalvas.add(caminho);
      setState(() => _fotoPath = caminho);
    } catch (e) {
      if (mounted) {
        avisar(context, 'Não foi possível obter a foto.', erro: true);
      }
    }
  }

  Future<HoraDoDia?> _escolherHora(HoraDoDia? inicial) async {
    final TimeOfDay agora = TimeOfDay.now();
    final TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: inicial == null
          ? agora
          : TimeOfDay(hour: inicial.hora, minute: inicial.minuto),
      helpText: 'Que horas tomar?',
      cancelText: 'Cancelar',
      confirmText: 'OK',
      builder: (ctx, child) => comTemaDeJanela(
        context,
        MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      ),
    );
    return t == null ? null : HoraDoDia(t.hour, t.minute);
  }

  Future<void> _adicionarHorario() async {
    final HoraDoDia? h = await _escolherHora(null);
    if (h == null || !mounted) return;
    setState(() {
      if (!_horarios.contains(h)) _horarios.add(h);
      _horarios.sort();
    });
  }

  Future<void> _definirPrimeiraDose() async {
    final HoraDoDia? h = await _escolherHora(
      _horarios.isEmpty ? null : _horarios.first,
    );
    if (h == null || !mounted) return;
    setState(() {
      _horarios
        ..clear()
        ..add(h);
    });
  }

  Future<void> _escolherDataFim() async {
    final DateTime hoje = inicioDoDia(DateTime.now());
    final DateTime? atual = _dataFim;
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: atual != null && !atual.isBefore(hoje)
          ? atual
          : hoje.add(const Duration(days: 7)),
      firstDate: hoje,
      lastDate: hoje.add(const Duration(days: 365 * 5)),
      helpText: 'Tomar até quando?',
      builder: (ctx, child) => comTemaDeJanela(context, child!),
    );
    if (d != null && mounted) setState(() => _dataFim = d);
  }

  Future<void> _outraDosagem() async {
    final TextEditingController valor = TextEditingController();
    String unidade = 'mg';
    final String? atual = _dosagem;
    if (atual != null) {
      final int espaco = atual.indexOf(' ');
      if (espaco > 0 &&
          unidadesDeDosagem.contains(atual.substring(espaco + 1))) {
        valor.text = atual.substring(0, espaco);
        unidade = atual.substring(espaco + 1);
      }
    }
    final String? nova = await mostrarDialogo<String>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final String? montada = montarDosagem(valor.text, unidade);
          return AlertDialog(
            title: const Text('Gramatura'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Confira na caixa ou na receita. Ex.: 500 mg.'),
                const SizedBox(height: 16),
                TextField(
                  controller: valor,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: const InputDecoration(labelText: 'Valor'),
                  onChanged: (_) => setLocal(() {}),
                ),
                const SizedBox(height: 16),
                Text('Unidade', style: ctx.textos.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final u in unidadesDeDosagem)
                      ChoiceChip(
                        label: Text(u),
                        selected: unidade == u,
                        onSelected: (_) => setLocal(() => unidade = u),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: montada == null
                    ? null
                    : () => Navigator.pop(ctx, montada),
                child: Text(montada ?? 'Usar'),
              ),
            ],
          );
        },
      ),
    );
    valor.dispose();
    if (nova != null && mounted) setState(() => _dosagem = nova);
  }

  Future<void> _salvar() async {
    if (_salvando) return; // trava contra duplo toque
    FocusScope.of(context).unfocus();
    setState(() => _tentouSalvar = true);
    if (!_valido) {
      avisar(context, 'Confira os campos marcados em vermelho.', erro: true);
      return;
    }
    setState(() => _salvando = true);

    final Medicamento? original = _original;
    final DateTime agora = DateTime.now();
    final List<HoraDoDia> horarios = [..._horarios]..sort();
    final bool intervalo = _frequencia == FrequenciaTipo.intervalo;

    // data_inicio NÃO é reescrita a cada edição (apagaria o passado do
    // Relatório). Só no modo Intervalo, se a 1ª dose ou o intervalo mudarem,
    // a série recomeça hoje — é a âncora do cálculo das doses.
    DateTime dataInicio = original?.dataInicio ?? agora;
    if (original != null &&
        intervalo &&
        (original.frequencia != FrequenciaTipo.intervalo ||
            original.intervaloHoras != _intervalo ||
            original.horarios.isEmpty ||
            original.horarios.first != horarios.first)) {
      dataInicio = agora;
    }

    final bool estoqueAtivo = ref.read(preferenciasProvider).estoqueAtivo;
    final int? caixa = int.tryParse(_quantidadeCaixa.text);
    final String nome = _nome.text.trim();
    final String complemento = _complementoMotivo.text.trim();

    final MedicamentosCompanion dados = MedicamentosCompanion(
      nome: Value(nome),
      descricao: Value(
        _motivo == MotivoDeUso.outro
            ? (complemento.isEmpty ? null : complemento)
            : (_motivo == null ? original?.descricao : null),
      ),
      horarios: Value(horarios),
      diasSemana: Value(intervalo ? {1, 2, 3, 4, 5, 6, 7} : {..._dias}),
      fotoPath: Value(_fotoPath),
      frequencia: Value(_frequencia),
      intervaloHoras: Value(intervalo ? _intervalo : null),
      dosesPorDia: Value(intervalo ? 24 ~/ _intervalo : horarios.length),
      dataInicio: Value(dataInicio),
      dataFim: Value(_usoContinuo ? null : _dataFim),
      dosagem: Value(_dosagem),
      quantidadePorDose: Value(_quantidade),
      forma: Value(_forma.chave),
      motivo: Value(_motivo?.chave),
      // Com o controle de estoque desligado, os dados já salvos ficam
      // como estão (não são zerados).
      quantidadeTotal: estoqueAtivo ? Value(caixa) : const Value.absent(),
      diasAntecedencia: estoqueAtivo
          ? Value(int.tryParse(_diasAntecedencia.text) ?? 5)
          : const Value.absent(),
      // "estoque desde" só muda quando a quantidade muda (caixa nova).
      estoqueDesde: estoqueAtivo && original?.quantidadeTotal != caixa
          ? Value(agora)
          : const Value.absent(),
    );

    final repo = ref.read(repositorioProvider);
    try {
      if (original == null) {
        await repo.inserir(dados);
      } else {
        await repo.atualizar(original.id, dados);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        avisar(
          context,
          'Não foi possível salvar. Tente novamente.',
          erro: true,
        );
      }
      return;
    }
    _salvou = true;
    if (original?.fotoPath != null && original!.fotoPath != _fotoPath) {
      unawaited(MedPhotoStorage.apagar(original.fotoPath));
    }
    // Reconcilia lembrete, alarme e estoque com o que acabou de ser salvo.
    unawaited(NotificationService().sincronizarAlarmes());
    if (!mounted) return;
    Navigator.of(context).pop();
    avisar(
      context,
      original == null ? 'Remédio cadastrado: $nome' : 'Alterações salvas.',
    );
  }

  Future<void> _remover() async {
    final Medicamento? m = _original;
    if (m == null) return;
    final bool ok = await confirmar(
      context,
      titulo: 'Remover ${m.nome}?',
      mensagem:
          'Os alarmes deste remédio serão cancelados. As doses já registradas continuam no Histórico.',
      confirmarRotulo: 'Remover',
      destrutivo: true,
    );
    if (!ok) return;
    await ref.read(repositorioProvider).arquivar(m.id);
    unawaited(NotificationService().sincronizarAlarmes());
    if (!mounted) return;
    Navigator.of(context).pop();
    avisar(
      context,
      'Removido da lista: ${m.nome}. As doses continuam no Histórico.',
    );
  }

  // ------------------------------------------------------------------
  // Interface
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final bool estoqueAtivo = ref.watch(preferenciasProvider).estoqueAtivo;
    return Scaffold(
      appBar: AppBar(
        title: Text(_original == null ? 'Novo remédio' : 'Editar remédio'),
        backgroundColor: c.fundoGradiente != null ? azulMarcaEscuro : c.fundo,
        actions: [
          if (_original != null)
            IconButton(
              tooltip: 'Remover remédio',
              icon: Icon(Icons.delete_outline_rounded, color: c.perigo),
              onPressed: _remover,
            ),
        ],
      ),
      body: FundoDoTema(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            ConteudoResponsivo(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _secaoIdentificacao(),
                  _secaoDose(),
                  _secaoMotivo(),
                  _secaoQuando(),
                  _secaoDuracao(),
                  if (estoqueAtivo) _secaoEstoque(),
                ],
              ),
            ),
          ],
        ),
      ),
      // Fundo sólido atrás do botão (o Scaffold é transparente: sem isto a
      // faixa aparecia preta).
      bottomNavigationBar: ColoredBox(
        color: c.fundoGradiente != null ? azulMarca : c.fundo,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: larguraMaximaConteudo,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _salvando ? null : _salvar,
                    child: _salvando
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Text('Salvar remédio'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _secao(String titulo, List<Widget> filhos, {String? ajuda}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Cartao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: context.textos.titleMedium),
            if (ajuda != null) ...[
              const SizedBox(height: 4),
              Text(ajuda, style: context.textos.bodySmall),
            ],
            const SizedBox(height: 14),
            ...filhos,
          ],
        ),
      ),
    );
  }

  Widget _erro(String? texto) => texto == null || !_tentouSalvar
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: context.cores.perigo, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    color: context.cores.perigo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

  Widget _secaoIdentificacao() {
    final CatalogoMedicamentos catalogo =
        ref.watch(catalogoProvider).value ?? CatalogoMedicamentos.vazio;
    return _secao('Remédio', [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: _fotoPath == null ? 'Adicionar foto' : 'Trocar foto',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _escolherFoto,
              child: Stack(
                children: [
                  AvatarRemedio(fotoPath: _fotoPath, raio: 34),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: context.cores.destaque,
                      child: Icon(
                        Icons.photo_camera_rounded,
                        size: 15,
                        color: context.cores.sobreDestaque,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: RawAutocomplete<SugestaoCatalogo>(
              textEditingController: _nome,
              focusNode: _focoNome,
              displayStringForOption: (s) => s.item.nome,
              optionsBuilder: (v) => catalogo.buscar(v.text),
              onSelected: _aoEscolherDoCatalogo,
              fieldViewBuilder: (ctx, controller, foco, aoEnviar) => TextField(
                controller: controller,
                focusNode: foco,
                // O corretor do teclado trocava nomes de remédio ("dipirona"):
                // aqui as sugestões vêm do catálogo, não do teclado.
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                inputFormatters: [LengthLimitingTextInputFormatter(60)],
                style: context.textos.titleMedium,
                decoration: InputDecoration(
                  labelText: 'Nome do remédio',
                  hintText: 'Ex.: Losartana',
                  errorText: _tentouSalvar ? _erroNome : null,
                ),
                onChanged: (_) => setState(() {
                  if (_itemCatalogo != null &&
                      normalizarBusca(_nome.text) !=
                          normalizarBusca(_itemCatalogo!.nome)) {
                    _itemCatalogo = null;
                  }
                }),
                onSubmitted: (_) => aoEnviar(),
              ),
              optionsViewBuilder: (ctx, aoEscolher, opcoes) =>
                  _ListaDeSugestoes(opcoes: opcoes, aoEscolher: aoEscolher),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _secaoDose() {
    final ItemCatalogo? item =
        _itemCatalogo ?? ref.watch(catalogoProvider).value?.porNome(_nome.text);
    final List<String> opcoes = [
      ...?item?.dosagens,
      if (_dosagem != null && !(item?.dosagens.contains(_dosagem) ?? false))
        _dosagem!,
    ];
    return _secao(
      'Dose',
      ajuda: 'Toque para escolher. Confira na caixa ou na receita.',
      [
        Text('Gramatura', style: context.textos.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in opcoes)
              ChoiceChip(
                label: Text(d),
                selected: _dosagem == d,
                onSelected: (sel) => setState(() => _dosagem = sel ? d : null),
              ),
            ActionChip(
              avatar: const Icon(Icons.edit_rounded, size: 18),
              label: Text(opcoes.isEmpty ? 'Informar gramatura' : 'Outra'),
              onPressed: _outraDosagem,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Quanto tomar de cada vez', style: context.textos.labelLarge),
        const SizedBox(height: 8),
        _SeletorQuantidade(
          quantidade: _quantidade,
          forma: _forma,
          aoMudar: (q) => setState(() => _quantidade = q),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in FormaFarmaceutica.values)
              ChoiceChip(
                label: Text(f.rotulo),
                selected: _forma == f,
                onSelected: (_) => setState(() {
                  _forma = f;
                  // Ajusta a quantidade ao passo da nova forma (sem ½ gota).
                  _quantidade = (_quantidade / f.passo).round() * f.passo;
                  if (_quantidade < f.passo) _quantidade = f.passo;
                  if (_quantidade > f.maximo) _quantidade = f.maximo;
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _secaoMotivo() {
    return _secao('Para que serve?', ajuda: 'Opcional — aparece no alarme.', [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final m in MotivoDeUso.values)
            ChoiceChip(
              label: Text(m.rotulo),
              selected: _motivo == m,
              onSelected: (sel) => setState(() => _motivo = sel ? m : null),
            ),
        ],
      ),
      if (_motivo == MotivoDeUso.outro) ...[
        const SizedBox(height: 14),
        TextField(
          controller: _complementoMotivo,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(30)],
          decoration: const InputDecoration(
            labelText: 'Qual? (curto)',
            hintText: 'Ex.: Enxaqueca',
          ),
        ),
      ],
    ]);
  }

  Widget _secaoQuando() {
    final bool intervalo = _frequencia == FrequenciaTipo.intervalo;
    return _secao('Quando tomar', [
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<FrequenciaTipo>(
          segments: const [
            ButtonSegment(
              value: FrequenciaTipo.horariosFixos,
              label: Text('Horários fixos'),
              icon: Icon(Icons.schedule_rounded),
            ),
            ButtonSegment(
              value: FrequenciaTipo.intervalo,
              label: Text('De X em X horas'),
              icon: Icon(Icons.update_rounded),
            ),
          ],
          selected: {_frequencia},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() {
            _frequencia = s.first;
            // No intervalo só a 1ª dose importa.
            if (_frequencia == FrequenciaTipo.intervalo &&
                _horarios.length > 1) {
              _horarios.removeRange(1, _horarios.length);
            }
          }),
        ),
      ),
      const SizedBox(height: 18),
      if (!intervalo) ...[
        Text('Horários', style: context.textos.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in _horarios)
              InputChip(
                label: Text(
                  h.formatado,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onDeleted: () => setState(() => _horarios.remove(h)),
                deleteButtonTooltipMessage: 'Remover horário',
              ),
            ActionChip(
              avatar: const Icon(Icons.add_alarm_rounded),
              label: Text(
                _horarios.isEmpty ? 'Adicionar horário' : 'Outro horário',
              ),
              onPressed: _adicionarHorario,
            ),
          ],
        ),
        _erro(_erroHorario),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text('Dias da semana', style: context.textos.labelLarge),
            ),
            TextButton(
              onPressed: () => setState(() {
                if (_dias.length == 7) {
                  _dias.clear();
                } else {
                  _dias.addAll({1, 2, 3, 4, 5, 6, 7});
                }
              }),
              child: Text(_dias.length == 7 ? 'Limpar' : 'Todos os dias'),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: [
            for (int d = 1; d <= 7; d++)
              FilterChip(
                label: Text(DoseSchedule.diasDaSemana[d - 1]),
                selected: _dias.contains(d),
                showCheckmark: false,
                tooltip: DoseSchedule.diasDaSemanaExtenso[d - 1],
                onSelected: (sel) =>
                    setState(() => sel ? _dias.add(d) : _dias.remove(d)),
              ),
          ],
        ),
        _erro(_erroDias),
      ] else ...[
        Text('De quantas em quantas horas?', style: context.textos.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in _intervalosComuns)
              ChoiceChip(
                label: Text('$h em $h h'),
                selected: _intervalo == h,
                onSelected: (_) => setState(() => _intervalo = h),
              ),
            if (!_intervalosComuns.contains(_intervalo))
              ChoiceChip(
                label: Text('$_intervalo em $_intervalo h'),
                selected: true,
                onSelected: (_) {},
              ),
            ActionChip(
              avatar: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Outro'),
              onPressed: () async {
                final int? h = await _escolherIntervalo();
                if (h != null && mounted) setState(() => _intervalo = h);
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _definirPrimeiraDose,
          icon: const Icon(Icons.alarm_rounded),
          label: Text(
            _horarios.isEmpty
                ? 'Horário da 1ª dose'
                : '1ª dose às ${_horarios.first.formatado}',
          ),
        ),
        _erro(_erroHorario),
        if (_horarios.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Próximas doses: ${_previaIntervalo()}',
            style: context.textos.bodyMedium?.copyWith(
              color: context.cores.textoSecundario,
            ),
          ),
        ],
      ],
    ]);
  }

  String _previaIntervalo() {
    final Medicamento previa = Medicamento(
      id: 0,
      nome: '',
      horarios: _horarios,
      diasSemana: const {1, 2, 3, 4, 5, 6, 7},
      frequencia: FrequenciaTipo.intervalo,
      intervaloHoras: _intervalo,
      dataInicio: DateTime.now(),
    );
    // A partir de agora (a 1ª dose de hoje pode já ter passado).
    final DateTime agora = DateTime.now();
    return DoseSchedule.proximasDoses(
      previa,
      agora.subtract(const Duration(minutes: 1)),
      janela: const Duration(days: 2),
      limite: 4,
    ).map(hhmm).join(', ');
  }

  Future<int?> _escolherIntervalo() {
    int valor = _intervalo;
    return mostrarDialogo<int>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Intervalo entre as doses'),
          content: _SeletorNumero(
            valor: valor,
            minimo: DoseSchedule.intervaloMinimoHoras,
            maximo: DoseSchedule.intervaloMaximoHoras,
            sufixo: valor == 1 ? 'hora' : 'horas',
            aoMudar: (v) => setLocal(() => valor = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, valor),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secaoDuracao() {
    return _secao('Por quanto tempo', [
      SwitchListTile(
        value: _usoContinuo,
        title: Text('Uso contínuo', style: context.textos.titleSmall),
        subtitle: Text(
          'Sem data para terminar',
          style: context.textos.bodySmall,
        ),
        onChanged: (v) => setState(() => _usoContinuo = v),
      ),
      if (!_usoContinuo) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _escolherDataFim,
          icon: const Icon(Icons.event_rounded),
          label: Text(
            _dataFim == null
                ? 'Escolher a data final'
                : 'Até ${dataCurta(_dataFim!)}',
          ),
        ),
        _erro(_erroDataFim),
      ],
    ]);
  }

  Widget _secaoEstoque() {
    return _secao(
      'Estoque',
      ajuda: 'O SeniCare avisa quando estiver na hora de comprar mais.',
      [
        TextField(
          controller: _quantidadeCaixa,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(
            labelText: 'Quantos ${_forma.plural} você tem?',
            prefixIcon: const Icon(Icons.inventory_2_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _diasAntecedencia,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: const InputDecoration(
            labelText: 'Avisar quantos dias antes de acabar?',
            prefixIcon: Icon(Icons.notifications_active_rounded),
          ),
        ),
      ],
    );
  }
}

class _ListaDeSugestoes extends StatelessWidget {
  final Iterable<SugestaoCatalogo> opcoes;
  final AutocompleteOnSelected<SugestaoCatalogo> aoEscolher;

  const _ListaDeSugestoes({required this.opcoes, required this.aoEscolher});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final bool escuro = c.tema == TemaApp.escuro;
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 6,
        color: escuro ? c.superficie : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300, maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            shrinkWrap: true,
            children: [
              for (final s in opcoes)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Icon(
                    Icons.medication_rounded,
                    color: escuro ? c.destaque : azulMarca,
                  ),
                  title: Text(
                    s.item.nome,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: escuro ? c.texto : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: s.viaSinonimo == null && s.item.dosagens.isEmpty
                      ? null
                      : Text(
                          [
                            if (s.viaSinonimo != null) s.viaSinonimo!,
                            if (s.item.dosagens.isNotEmpty)
                              s.item.dosagens.take(3).join(' · '),
                          ].join(' — '),
                          style: TextStyle(
                            fontSize: 15,
                            color: escuro
                                ? c.textoSecundario
                                : const Color(0xFF475569),
                          ),
                        ),
                  onTap: () => aoEscolher(s),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeletorQuantidade extends StatelessWidget {
  final double quantidade;
  final FormaFarmaceutica forma;
  final ValueChanged<double> aoMudar;

  const _SeletorQuantidade({
    required this.quantidade,
    required this.forma,
    required this.aoMudar,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final bool podeDiminuir = quantidade - forma.passo >= forma.passo - 1e-9;
    final bool podeAumentar = quantidade + forma.passo <= forma.maximo + 1e-9;
    return Container(
      decoration: BoxDecoration(
        color: c.suave,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borda),
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: 30,
            tooltip: 'Menos',
            onPressed: podeDiminuir
                ? () => aoMudar(quantidade - forma.passo)
                : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Text(
              forma.descrever(quantidade),
              textAlign: TextAlign.center,
              style: context.textos.titleLarge,
            ),
          ),
          IconButton(
            iconSize: 30,
            tooltip: 'Mais',
            onPressed: podeAumentar
                ? () => aoMudar(quantidade + forma.passo)
                : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _SeletorNumero extends StatelessWidget {
  final int valor;
  final int minimo;
  final int maximo;
  final String sufixo;
  final ValueChanged<int> aoMudar;

  const _SeletorNumero({
    required this.valor,
    required this.minimo,
    required this.maximo,
    required this.sufixo,
    required this.aoMudar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          iconSize: 28,
          onPressed: valor > minimo ? () => aoMudar(valor - 1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        Expanded(
          child: Text(
            '$valor $sufixo',
            textAlign: TextAlign.center,
            style: context.textos.titleLarge,
          ),
        ),
        IconButton.filledTonal(
          iconSize: 28,
          onPressed: valor < maximo ? () => aoMudar(valor + 1) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
