// Tela de formulário para cadastrar ou editar um remédio: nome, foto,
// horários, frequência, por quanto tempo deve ser tomado e controle de
// estoque.

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';
import 'glass_card.dart';
import 'notification_service.dart';

class AddMedicationScreen extends StatefulWidget {
  final Map<String, dynamic>? medicationData;
  final String currentTheme;
  final double fontSizeMultiplier;
  final bool isRestockEnabled;

  const AddMedicationScreen({
    super.key,
    this.medicationData,
    required this.currentTheme,
    required this.fontSizeMultiplier,
    this.isRestockEnabled = false,
  });

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _quantidadeTotalController =
      TextEditingController();
  final TextEditingController _diasAntecedenciaController =
      TextEditingController();
  final TextEditingController _intervaloController = TextEditingController();

  String _frequenciaTipo = 'Horários Fixos';
  List<TimeOfDay> _selectedTimes = [];
  bool _isUsoContinuo = true;
  DateTime? _dataFim;
  XFile? _imageFile;

  final List<String> _daysOfWeek = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];
  final List<bool> _selectedDays = List.generate(7, (index) => false);

  // Trava contra duplo clique: sem isso, o usuário conseguia tocar em
  // 'Salvar Medicamento' várias vezes enquanto o banco/agendamento ainda
  // estavam em andamento, criando remédios duplicados.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.medicationData != null) {
      final data = widget.medicationData!;
      _nameController.text = data['nome'] ?? '';
      _descController.text = data['descricao'] ?? '';
      _quantidadeTotalController.text =
          data['quantidade_total']?.toString() ?? '';
      _diasAntecedenciaController.text =
          data['dias_antecedencia']?.toString() ?? '3';

      _frequenciaTipo = data['frequencia_tipo'] ?? 'Horários Fixos';
      if (data['intervalo_horas'] != null) {
        _intervaloController.text = data['intervalo_horas'].toString();
      }

      if (data['data_fim'] != null) {
        _isUsoContinuo = false;
        _dataFim = DateTime.parse(data['data_fim']);
      }

      if (data['horario'] != null) {
        final timesStr = (data['horario'] as String).split(', ');
        for (var t in timesStr) {
          final match = RegExp(r'(\d+):(\d+)').firstMatch(t);
          if (match != null) {
            _selectedTimes.add(
              TimeOfDay(
                hour: int.parse(match.group(1)!),
                minute: int.parse(match.group(2)!),
              ),
            );
          }
        }
      }

      if (data['dias_semana'] != null && data['dias_semana'] != 'Nenhum') {
        final savedDays = (data['dias_semana'] as String).split(', ');
        for (int i = 0; i < _daysOfWeek.length; i++) {
          if (savedDays.contains(_daysOfWeek[i])) {
            _selectedDays[i] = true;
          }
        }
      }

      if (data['foto_path'] != null) {
        _imageFile = XFile(data['foto_path']);
      }
    } else {
      _diasAntecedenciaController.text = '3';
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        // Tanto 'Horários Fixos' quanto 'Intervalo' agora permitem apenas 1 horário
        // cadastrado por registro, então cada seleção substitui a anterior.
        _selectedTimes
          ..clear()
          ..add(picked);
      });
    }
  }

  Future<void> _pickDataFim() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _dataFim = picked;
      });
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
      );
      if (photo != null) setState(() => _imageFile = photo);
    } catch (e) {
      debugPrint('Erro ao capturar a imagem: $e');
    }
  }

  /// Calcula a próxima ocorrência futura de um horário (hora:minuto),
  /// avançando dia a dia até cair estritamente no futuro. Se [weekday] for
  /// informado (1=Seg...7=Dom, igual a DateTime.weekday — usado no modo
  /// 'Horários Fixos'), também avança até bater com esse dia da semana.
  ///
  /// O NotificationService nunca deve receber um horário que já passou;
  /// centralizar esse cálculo aqui (em vez de duplicá-lo por modo) evita que
  /// um dos dois caminhos fique com uma conta errada.
  DateTime _proximaOcorrenciaFutura({
    required int hora,
    required int minuto,
    int? weekday,
  }) {
    final DateTime agora = DateTime.now();
    DateTime proxima = DateTime(
      agora.year,
      agora.month,
      agora.day,
      hora,
      minuto,
    );
    while ((weekday != null && proxima.weekday != weekday) ||
        !proxima.isAfter(agora)) {
      proxima = proxima.add(const Duration(days: 1));
    }
    assert(proxima.isAfter(DateTime.now()));
    return proxima;
  }

  void _toggleTodosOsDias() {
    setState(() {
      bool allSelected = _selectedDays.every((element) => element == true);
      for (int i = 0; i < _selectedDays.length; i++) {
        _selectedDays[i] = !allSelected;
      }
    });
  }

  Future<void> _salvarMedicamento() async {
    // Trava contra duplo clique: se já existe um salvamento em andamento,
    // ignora o toque em vez de disparar outra gravação em paralelo.
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // CORREÇÃO: Força o teclado a fechar para o usuário ver os alertas vermelhos!
      FocusScope.of(context).unfocus();

      final nome = _nameController.text.trim();

      if (nome.isEmpty || _selectedTimes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nome e pelo menos um horário são obrigatórios!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validação de Dias da Semana: no modo 'Horários Fixos' basta pelo
      // menos 1 dia marcado (ex.: só Segunda e Quarta) — não é obrigatório
      // marcar a semana toda.
      if (_frequenciaTipo == 'Horários Fixos' && !_selectedDays.any((d) => d)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione pelo menos um dia da semana!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_frequenciaTipo == 'Intervalo' && _intervaloController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informe o intervalo de horas!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final String diasSelecionados = _frequenciaTipo == 'Intervalo'
          ? 'Todos os dias'
          : _daysOfWeek
                .asMap()
                .entries
                .where((e) => _selectedDays[e.key])
                .map((e) => e.value)
                .join(', ');

      final String horariosFormatados = _selectedTimes
          .map(
            (t) => DateFormat(
              'HH:mm',
            ).format(DateTime(2000, 1, 1, t.hour, t.minute)),
          )
          .join(', ');

      // Não perguntamos "doses por dia" ao usuário (form mais simples e didático):
      // em 'Horários Fixos' agora é sempre 1 dose/dia; em 'Intervalo' estimamos
      // pela frequência das horas, para o alerta de reabastecimento funcionar.
      final int dosesPorDiaCalculado = _frequenciaTipo == 'Intervalo'
          ? (24 ~/ (int.tryParse(_intervaloController.text) ?? 24)).clamp(1, 24)
          : 1;

      final dados = {
        'nome': nome,
        'descricao': _descController.text.trim(),
        'horario': horariosFormatados,
        'dias_semana': diasSelecionados,
        'foto_path': _imageFile?.path,
        'frequencia_tipo': _frequenciaTipo,
        'intervalo_horas': _frequenciaTipo == 'Intervalo'
            ? int.tryParse(_intervaloController.text)
            : null,
        'data_inicio': DateTime.now().toIso8601String(),
        'data_fim': _isUsoContinuo ? null : _dataFim?.toIso8601String(),
        'quantidade_total': widget.isRestockEnabled
            ? (int.tryParse(_quantidadeTotalController.text) ?? 0)
            : 0,
        'doses_por_dia': widget.isRestockEnabled ? dosesPorDiaCalculado : 0,
        'dias_antecedencia': widget.isRestockEnabled
            ? (int.tryParse(_diasAntecedenciaController.text) ?? 3)
            : 0,
      };

      try {
        if (widget.medicationData != null) {
          dados['id'] = widget.medicationData!['id'];
          await DatabaseHelper().updateMedicamento(dados);
          try {
            await NotificationService().scheduleStockAlert(dados);
          } catch (e) {} // Silencia erros não vitais
        } else {
          final newId = await DatabaseHelper().insertMedicamento(dados);
          dados['id'] = newId;
          try {
            await NotificationService().scheduleStockAlert(dados);
          } catch (e) {} // Silencia erros não vitais
        }
      } catch (e) {
        debugPrint('[SALVAR] ERRO ao salvar no banco de dados: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erro no Banco de Dados: $e\n(Talvez falte atualizar a tabela)',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Agenda os alarmes reais (lembrete de 30 min + alarme em tela cheia)
      // para cada horário/dia configurado. Falhas aqui não devem impedir o
      // medicamento de ser salvo — o registro já foi persistido acima.
      try {
        final int medId = dados['id'] as int;
        await NotificationService().cancelMedicationAlarms(medId);

        final List<String> horarios = horariosFormatados
            .split(', ')
            .where((h) => h.trim().isNotEmpty)
            .toList();

        for (final String horarioStr in horarios) {
          final partes = horarioStr.split(':');
          if (partes.length != 2) continue;
          final int? hora = int.tryParse(partes[0]);
          final int? minuto = int.tryParse(partes[1]);
          if (hora == null || minuto == null) continue;

          if (_frequenciaTipo == 'Horários Fixos') {
            // Um alarme por dia da semana selecionado.
            for (int i = 0; i < _daysOfWeek.length; i++) {
              if (!_selectedDays[i]) continue;
              final int weekday =
                  i + 1; // Seg=1 ... Dom=7, igual ao DateTime.weekday
              final DateTime proximaOcorrencia = _proximaOcorrenciaFutura(
                hora: hora,
                minuto: minuto,
                weekday: weekday,
              );
              debugPrint(
                '[Agendar] ${_daysOfWeek[i]} $horarioStr -> próxima ocorrência: $proximaOcorrencia',
              );
              await NotificationService().scheduleMedicationAlarms(
                dados,
                proximaOcorrencia,
              );
            }
          } else {
            // Intervalo: alarme diário a partir do horário da 1ª dose.
            final DateTime proximaOcorrencia = _proximaOcorrenciaFutura(
              hora: hora,
              minuto: minuto,
            );
            debugPrint(
              '[Agendar] Intervalo $horarioStr -> próxima ocorrência: $proximaOcorrencia',
            );
            await NotificationService().scheduleMedicationAlarms(
              dados,
              proximaOcorrencia,
            );
          }
        }
      } catch (e) {
        debugPrint('[SALVAR] ERRO ao agendar alarmes: $e');
      }

      if (context.mounted) Navigator.pop(context, true);
    } finally {
      // Garante que o botão volte ao normal mesmo se algo der errado acima
      // (ou não faz nada se o Navigator.pop já desmontou a tela).
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.fontSizeMultiplier;
    final useWhiteText =
        widget.currentTheme == 'Dark' || widget.currentTheme == 'Default';
    final textColor = useWhiteText ? Colors.white : Colors.black87;
    final subTextColor = useWhiteText ? Colors.white70 : Colors.black54;
    final accentColor = widget.currentTheme == 'Light'
        ? const Color(0xFF0D47A1)
        : const Color(0xFF00B4DB);
    final bool isDefault = widget.currentTheme == 'Default';
    // No tema Default o fundo já é um gradiente azul/ciano, então um botão selecionado
    // nessas mesmas cores quase desaparecia. Selecionado = branco sólido com texto azul
    // (mesmo padrão do botão flutuante); não selecionado = branco translúcido com texto branco.
    // Light e Dark mantêm o esquema anterior (accentColor), sem alteração.
    final Color freqSelectedBg = isDefault ? Colors.white : accentColor;
    final Color freqSelectedFg = isDefault
        ? const Color(0xFF0D47A1)
        : Colors.white;
    final Color freqUnselectedBg = isDefault
        ? Colors.white.withValues(alpha: 0.15)
        : (useWhiteText
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.grey.shade200);
    final Color freqUnselectedFg = isDefault ? Colors.white : textColor;
    final Color botaoTextColor = isDefault
        ? const Color(0xFF0D47A1)
        : Colors.white;

    return Scaffold(
      backgroundColor: widget.currentTheme == 'Light'
          ? Colors.grey.shade50
          : (widget.currentTheme == 'Dark'
                ? const Color(0xFF121212)
                : const Color(0xFF0D47A1)),
      appBar: AppBar(
        title: Text(
          widget.medicationData == null
              ? 'Adicionar Remédio'
              : 'Editar Remédio',
          style: TextStyle(
            fontSize: 24.0 * m,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: widget.currentTheme == 'Default'
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D47A1), Color(0xFF00B4DB)],
                ),
              )
            : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _takePicture,
                  child: CircleAvatar(
                    radius: 60.0,
                    backgroundColor: useWhiteText
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey.shade200,
                    backgroundImage: _imageFile != null
                        ? FileImage(File(_imageFile!.path))
                        : null,
                    child: _imageFile == null
                        ? Icon(
                            Icons.camera_alt,
                            size: 50.0,
                            color: useWhiteText ? Colors.white70 : Colors.grey,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              _buildLargeTextField(
                controller: _nameController,
                label: 'Nome do Remédio',
                icon: Icons.medication,
                useWhiteText: useWhiteText,
                textColor: textColor,
                subTextColor: subTextColor,
                m: m,
              ),
              const SizedBox(height: 16.0),
              _buildLargeTextField(
                controller: _descController,
                label: 'Descrição/Motivo',
                icon: Icons.description,
                useWhiteText: useWhiteText,
                textColor: textColor,
                subTextColor: subTextColor,
                m: m,
              ),
              const SizedBox(height: 32.0),

              // === FREQUÊNCIA E HORÁRIOS ===
              Text(
                'Frequência',
                style: TextStyle(
                  fontSize: 22.0 * m,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // CORREÇÃO: Só limpa a hora se realmente mudar de modo!
                        if (_frequenciaTipo != 'Horários Fixos') {
                          setState(() {
                            _frequenciaTipo = 'Horários Fixos';
                            _selectedTimes.clear();
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _frequenciaTipo == 'Horários Fixos'
                            ? freqSelectedBg
                            : freqUnselectedBg,
                        foregroundColor: _frequenciaTipo == 'Horários Fixos'
                            ? freqSelectedFg
                            : freqUnselectedFg,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Horários Fixos',
                        style: TextStyle(
                          fontSize: 16 * m,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // CORREÇÃO: Só limpa a hora se realmente mudar de modo!
                        if (_frequenciaTipo != 'Intervalo') {
                          setState(() {
                            _frequenciaTipo = 'Intervalo';
                            _selectedTimes.clear();
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _frequenciaTipo == 'Intervalo'
                            ? freqSelectedBg
                            : freqUnselectedBg,
                        foregroundColor: _frequenciaTipo == 'Intervalo'
                            ? freqSelectedFg
                            : freqUnselectedFg,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Intervalos',
                        style: TextStyle(
                          fontSize: 16 * m,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24.0),

              if (_frequenciaTipo == 'Intervalo') ...[
                _buildLargeTextField(
                  controller: _intervaloController,
                  label: 'De quantas em quantas horas?',
                  icon: Icons.hourglass_bottom,
                  useWhiteText: useWhiteText,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  m: m,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16.0),
              ],

              // No modo 'Horários Fixos' só é permitido 1 horário por registro,
              // então o botão some assim que um horário já estiver selecionado.
              if (_frequenciaTipo == 'Intervalo' || _selectedTimes.isEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 60.0,
                  child: ElevatedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.add_alarm, size: 28.0),
                    label: Text(
                      _frequenciaTipo == 'Intervalo'
                          ? 'Definir Horário da 1ª Dose'
                          : 'Adicionar Horário',
                      style: TextStyle(
                        fontSize: 20.0 * m,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: useWhiteText
                          ? Colors.white.withValues(alpha: 0.15)
                          : accentColor.withValues(alpha: 0.1),
                      foregroundColor: useWhiteText
                          ? Colors.white
                          : accentColor,
                      elevation: 0,
                    ),
                  ),
                ),

              if (_selectedTimes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _selectedTimes
                        .map(
                          (time) => Chip(
                            label: Text(
                              DateFormat('HH:mm').format(
                                DateTime(2000, 1, 1, time.hour, time.minute),
                              ),
                              style: TextStyle(
                                fontSize: 18 * m,
                                fontWeight: FontWeight.bold,
                                color: widget.currentTheme == 'Default'
                                    ? const Color(0xFF0D47A1)
                                    : textColor,
                              ),
                            ),
                            backgroundColor: widget.currentTheme == 'Default'
                                ? Colors.white
                                : (widget.currentTheme == 'Dark'
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.grey.shade200),
                            deleteIcon: Icon(
                              Icons.close,
                              color: widget.currentTheme == 'Default'
                                  ? Colors.redAccent
                                  : textColor,
                              size: 20,
                            ),
                            side: BorderSide.none,
                            onDeleted: () =>
                                setState(() => _selectedTimes.remove(time)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 32.0),

              // === DIAS DA SEMANA ===
              if (_frequenciaTipo == 'Horários Fixos') ...[
                Row(
                  children: [
                    // Título no tamanho natural (texto curto e fixo, sem
                    // risco real de overflow) — o indicador da direita é que
                    // precisa do Expanded + alinhamento à direita, para ficar
                    // sempre colado na borda direita e encolher graciosamente
                    // se a fonte crescer.
                    Text(
                      'Dias da Semana',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22.0 * m,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: _toggleTodosOsDias,
                        // 'accentColor' (ciano) podia sumir sobre o gradiente azul do tema
                        // Default; usamos branco puro nesse caso para garantir contraste.
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            'Todos os Dias',
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16 * m,
                              color: useWhiteText ? Colors.white : accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_daysOfWeek.length, (index) {
                      final isSelected = _selectedDays[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InkWell(
                          onTap: () => setState(
                            () => _selectedDays[index] = !_selectedDays[index],
                          ),
                          child: Container(
                            width: 42.0 * (m > 1.0 ? 1.0 : m),
                            height: 42.0 * (m > 1.0 ? 1.0 : m),
                            decoration: BoxDecoration(
                              // No tema Default a bolinha selecionada vira branco sólido (mesmo
                              // padrão dos demais botões), pois o ciano do accentColor tinha
                              // pouco contraste sobre o gradiente azul. Light/Dark inalterados.
                              color: isSelected
                                  ? (isDefault ? Colors.white : accentColor)
                                  : (isDefault
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : (useWhiteText
                                              ? Colors.white.withValues(
                                                  alpha: 0.18,
                                                )
                                              : Colors.grey.shade300)),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? null
                                  : Border.all(
                                      color: useWhiteText
                                          ? Colors.white.withValues(alpha: 0.5)
                                          : Colors.grey.shade400,
                                      width: 1.0,
                                    ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _daysOfWeek[index],
                              style: TextStyle(
                                fontSize: 14.0 * m,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? (isDefault
                                          ? const Color(0xFF0D47A1)
                                          : Colors.white)
                                    : (isDefault ? Colors.white : textColor),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 32.0),
              ],

              // === DURAÇÃO DO TRATAMENTO ===
              Text(
                'Duração do Tratamento',
                style: TextStyle(
                  fontSize: 22.0 * m,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8.0),
              GlassCard(
                isDark: widget.currentTheme == 'Dark',
                borderRadius: 10.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Uso Contínuo',
                      style: TextStyle(
                        fontSize: 19 * m,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    // CupertinoSwitch: trilha cinza inativa e polegar branco
                    // nativos do widget.
                    trailing: CupertinoSwitch(
                      value: _isUsoContinuo,
                      activeTrackColor: isDefault
                          ? const Color(0xFF0D47A1)
                          : accentColor,
                      onChanged: (val) => setState(() => _isUsoContinuo = val),
                    ),
                  ),
                ),
              ),
              if (!_isUsoContinuo)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.calendar_month,
                    color: accentColor,
                    size: 32,
                  ),
                  title: Text(
                    _dataFim == null
                        ? 'Selecionar Data Final'
                        : 'Término: ${DateFormat('dd/MM/yyyy').format(_dataFim!)}',
                    style: TextStyle(fontSize: 18 * m, color: textColor),
                  ),
                  onTap: _pickDataFim,
                ),

              // === CONTROLE DE ESTOQUE (só aparece com o lembrete de reabastecimento ativo) ===
              if (widget.isRestockEnabled) ...[
                const SizedBox(height: 32.0),
                Text(
                  'Controle de Estoque',
                  style: TextStyle(
                    fontSize: 22.0 * m,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Com essas informações, o SeniCare avisa você na hora certa de comprar mais remédio.',
                  style: TextStyle(fontSize: 14.0 * m, color: subTextColor),
                ),
                const SizedBox(height: 16.0),
                _buildLargeTextField(
                  controller: _quantidadeTotalController,
                  label: 'Quantos comprimidos/doses há na caixa?',
                  icon: Icons.inventory_2,
                  useWhiteText: useWhiteText,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  m: m,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16.0),
                _buildLargeTextField(
                  controller: _diasAntecedenciaController,
                  label: 'Avisar quando faltarem quantos dias?',
                  icon: Icons.notifications_active,
                  useWhiteText: useWhiteText,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  m: m,
                  keyboardType: TextInputType.number,
                ),
              ],

              const SizedBox(height: 40.0),

              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    widget.isRestockEnabled
                        ? 'Tudo certo! Quando o remédio estiver quase acabando, o SeniCare avisa você para comprar mais.'
                        : 'Deixe o SeniCare lembrar você de repor este remédio! Ative o "Lembrete de Reabastecimento" nos Ajustes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.0 * m,
                      color: subTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              // === BOTÃO SALVAR ===
              SizedBox(
                width: double.infinity,
                height: 72.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.currentTheme == 'Light'
                        ? const Color(0xFF212121)
                        : (widget.currentTheme == 'Dark'
                              ? const Color(0xFF2C2C2C)
                              : Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onPressed: _isSaving ? null : _salvarMedicamento,
                  child: _isSaving
                      ? SizedBox(
                          width: 28.0 * m,
                          height: 28.0 * m,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.0,
                            color: botaoTextColor,
                          ),
                        )
                      : Text(
                          'Salvar Medicamento',
                          style: TextStyle(
                            fontSize: 24.0 * m,
                            fontWeight: FontWeight.bold,
                            color: botaoTextColor,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool useWhiteText,
    required Color textColor,
    required Color subTextColor,
    required double m,
    TextInputType? keyboardType,
    FocusNode? focusNode,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 22.0 * m, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 18.0 * m, color: subTextColor),
        prefixIcon: Icon(
          icon,
          size: 30.0,
          color: useWhiteText ? Colors.white70 : const Color(0xFF0D47A1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: useWhiteText ? Colors.white38 : Colors.black45,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: useWhiteText ? Colors.white : const Color(0xFF0D47A1),
            width: 3.0,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 20.0,
        ),
      ),
    );
  }
}
