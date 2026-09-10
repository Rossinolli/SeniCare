// Tela de Ajustes do aplicativo: escolher o tema, o tamanho da letra, ver o
// relatório, configurar notificações e alarme, e compartilhar o app ou a
// lista de remédios.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import 'database_helper.dart';
import 'glass_card.dart';
import 'notification_service.dart';
import 'report_screen.dart';

// TELA DE CONFIGURAÇÕES
class SettingsScreen extends StatelessWidget {
  final String currentTheme;
  final double fontSizeMultiplier;
  final bool isRestockEnabled;
  final String alertMode;
  final bool isAlarmSoundEnabled;
  final bool isAlarmVibrationEnabled;
  final Function(String) onThemeChanged;
  final Function(double) onFontSizeChanged;
  final Function(bool) onRestockChanged;
  final Function(String) onAlertModeChanged;
  final Function(bool) onAlarmSoundChanged;
  final Function(bool) onAlarmVibrationChanged;

  const SettingsScreen({
    super.key,
    required this.currentTheme,
    required this.fontSizeMultiplier,
    required this.isRestockEnabled,
    required this.alertMode,
    required this.isAlarmSoundEnabled,
    required this.isAlarmVibrationEnabled,
    required this.onThemeChanged,
    required this.onFontSizeChanged,
    required this.onRestockChanged,
    required this.onAlertModeChanged,
    required this.onAlarmSoundChanged,
    required this.onAlarmVibrationChanged,
  });

  Future<void> _compartilharApp() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Baixe o SeniCare e comece a cuidar da sua saúde! Não se preocupe '
            'mais com o esquecimento dos seus remédios.',
      ),
    );
  }

  /// Formata cada medicamento numa linha amigável ('Paracetamol 1x ao dia
  /// por 7 dias' / 'Amoxicilina de 8 em 8 horas') e abre o diálogo de
  /// compartilhamento nativo com a lista compilada.
  Future<void> _compartilharMedicamentos(BuildContext context) async {
    final List<Map<String, dynamic>> medicamentos = await DatabaseHelper()
        .getMedicamentos();

    if (medicamentos.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum medicamento cadastrado ainda.')),
        );
      }
      return;
    }

    final String texto = medicamentos.map(_formatarMedicamento).join('\n');

    if (context.mounted) {
      await SharePlus.instance.share(
        ShareParams(text: 'Meus medicamentos no SeniCare:\n\n$texto'),
      );
    }
  }

  String _formatarMedicamento(Map<String, dynamic> med) {
    final String nome = (med['nome'] as String?) ?? 'Medicamento';
    final bool isHorarioFixo =
        (med['frequencia_tipo'] as String?) == 'Horários Fixos' ||
        med['frequencia_tipo'] == null;

    String frequencia;
    if (isHorarioFixo) {
      final String horario = (med['horario'] as String?) ?? '';
      final int dosesPorDia = horario.isEmpty ? 1 : horario.split(',').length;
      frequencia = '${dosesPorDia}x ao dia';
    } else {
      final int? intervalo = med['intervalo_horas'] as int?;
      frequencia = intervalo == null
          ? 'em intervalos regulares'
          : 'de $intervalo em $intervalo horas';
    }

    String duracao = '';
    final String? dataInicio = med['data_inicio'] as String?;
    final String? dataFim = med['data_fim'] as String?;
    if (dataInicio != null && dataFim != null) {
      try {
        final int dias =
            DateTime.parse(
              dataFim,
            ).difference(DateTime.parse(dataInicio)).inDays +
            1;
        if (dias > 0) duracao = ' por $dias dia${dias == 1 ? '' : 's'}';
      } catch (_) {
        // Datas em formato inesperado: só omite a duração, não quebra o resto.
      }
    }

    return '$nome $frequencia$duracao';
  }

  @override
  Widget build(BuildContext context) {
    final useWhiteText = currentTheme == 'Dark' || currentTheme == 'Default';
    final textColor = useWhiteText ? Colors.white : Colors.black87;
    final subTextColor = useWhiteText ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(24.0 * fontSizeMultiplier),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurações',
              // Mesma família tipográfica do 'Olá' da Home (GoogleFonts
              // greatVibes), para os títulos das telas terem identidade
              // visual coesa. textScaler.noScaling: fontes de caligrafia têm
              // laços/curvas que quebram feio se a escala do sistema esticar
              // demais o texto.
              textScaler: TextScaler.noScaling,
              style: GoogleFonts.greatVibes(
                fontSize: 36.0 * fontSizeMultiplier,
                color: textColor,
              ),
            ),
            SizedBox(height: 24.0 * fontSizeMultiplier),
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                children: [
                  // Tema Visual
                  _buildSettingsCard(
                    title: 'Tema Visual',
                    icon: Icons.palette,
                    textColor: textColor,
                    fontSizeMultiplier: fontSizeMultiplier,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildThemeOption(
                          'Padrão',
                          'Default',
                          const Color(0xFF0D47A1),
                          textColor,
                          currentTheme,
                          fontSizeMultiplier,
                        ),
                        _buildThemeOption(
                          'Claro',
                          'Light',
                          Colors.white,
                          textColor,
                          currentTheme,
                          fontSizeMultiplier,
                        ),
                        _buildThemeOption(
                          'Escuro',
                          'Dark',
                          const Color(0xFF121212),
                          textColor,
                          currentTheme,
                          fontSizeMultiplier,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.0 * fontSizeMultiplier),

                  // Tamanho da Fonte
                  _buildSettingsCard(
                    title: 'Tamanho da Fonte',
                    icon: Icons.format_size,
                    textColor: textColor,
                    fontSizeMultiplier: fontSizeMultiplier,
                    child: Column(
                      children: [
                        // SliderTheme com valueIndicatorColor/TextStyle fixos:
                        // sem isso, o balão que mostra a porcentagem herdava
                        // cores que ficavam ilegíveis (texto claro sobre
                        // fundo claro) no tema Padrão.
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            valueIndicatorColor: Colors.white,
                            valueIndicatorTextStyle: TextStyle(
                              color: const Color(0xFF0D47A1),
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0 * fontSizeMultiplier,
                            ),
                          ),
                          child: Slider(
                            // Clamp defensivo: protege contra um valor salvo antes
                            // do limite máximo mudar de 1.3 para 1.1 (o Slider
                            // trava com erro se value > max).
                            value: fontSizeMultiplier.clamp(0.8, 1.1),
                            min: 0.8,
                            max: 1.1,
                            divisions: 3,
                            label: '${(fontSizeMultiplier * 100).round()}%',
                            activeColor: currentTheme == 'Default'
                                ? Colors.white
                                : const Color(0xFF0D47A1),
                            inactiveColor: useWhiteText
                                ? Colors.white38
                                : Colors.grey.shade300,
                            onChanged: onFontSizeChanged,
                          ),
                        ),
                        Text(
                          'Exemplo de Tamanho de Texto',
                          style: TextStyle(
                            fontSize: 16.0 * fontSizeMultiplier,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.0 * fontSizeMultiplier),

                  // Relatório de Adesão: tela dedicada com o resumo dos
                  // últimos 7 dias de tratamento.
                  _buildSettingsCard(
                    title: 'Relatório de Adesão',
                    icon: Icons.bar_chart,
                    textColor: textColor,
                    fontSizeMultiplier: fontSizeMultiplier,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.insights,
                        color: textColor,
                        size: 26.0 * fontSizeMultiplier,
                      ),
                      title: Text(
                        'Ver relatório detalhado',
                        style: TextStyle(
                          fontSize: 16.0 * fontSizeMultiplier,
                          color: textColor,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: subTextColor),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReportScreen(
                            currentTheme: currentTheme,
                            fontSizeMultiplier: fontSizeMultiplier,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.0 * fontSizeMultiplier),

                  // Notificações: agrupa tudo relacionado a como/quando o
                  // usuário é avisado — Reabastecimento, Modo de Aviso e Som
                  // e Vibração do Alarme —, cada bloco separado por um
                  // Divider em vez de 3 cards soltos.
                  _buildSettingsCard(
                    title: 'Notificações',
                    icon: Icons.notifications_active,
                    textColor: textColor,
                    fontSizeMultiplier: fontSizeMultiplier,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Lembrete de Reabastecimento',
                            style: TextStyle(
                              fontSize: 18.0 * fontSizeMultiplier,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          subtitle: Text(
                            'Avisar quando o remédio estiver acabando',
                            style: TextStyle(
                              fontSize: 14.0 * fontSizeMultiplier,
                              color: subTextColor,
                            ),
                          ),
                          // CupertinoSwitch: trilha cinza inativa e polegar
                          // branco nativos do widget — não precisam ser
                          // definidos à mão.
                          trailing: CupertinoSwitch(
                            value: isRestockEnabled,
                            activeTrackColor: const Color(0xFF0D47A1),
                            onChanged: onRestockChanged,
                          ),
                        ),
                        Divider(
                          height: 32.0 * fontSizeMultiplier,
                          color: subTextColor.withValues(alpha: 0.2),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Modo de Aviso',
                            style: TextStyle(
                              fontSize: 16.0 * fontSizeMultiplier,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.0 * fontSizeMultiplier),
                        Text(
                          'Como o SeniCare deve avisar na hora do remédio?',
                          style: TextStyle(
                            fontSize: 14.0 * fontSizeMultiplier,
                            color: subTextColor,
                          ),
                        ),
                        _buildAlertModeOption(
                          label: 'Notificações e Alarmes',
                          value: 'both',
                          textColor: textColor,
                          fontSizeMultiplier: fontSizeMultiplier,
                        ),
                        _buildAlertModeOption(
                          label: 'Apenas Notificações',
                          value: 'notifications_only',
                          textColor: textColor,
                          fontSizeMultiplier: fontSizeMultiplier,
                        ),
                        _buildAlertModeOption(
                          label: 'Apenas Alarmes',
                          value: 'alarms_only',
                          textColor: textColor,
                          fontSizeMultiplier: fontSizeMultiplier,
                        ),
                        Divider(
                          height: 32.0 * fontSizeMultiplier,
                          color: subTextColor.withValues(alpha: 0.2),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Som e Vibração do Alarme',
                            style: TextStyle(
                              fontSize: 16.0 * fontSizeMultiplier,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Som do Alarme',
                            style: TextStyle(
                              fontSize: 18.0 * fontSizeMultiplier,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          trailing: CupertinoSwitch(
                            value: isAlarmSoundEnabled,
                            activeTrackColor: const Color(0xFF0D47A1),
                            onChanged: onAlarmSoundChanged,
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Vibração',
                            style: TextStyle(
                              fontSize: 18.0 * fontSizeMultiplier,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          trailing: CupertinoSwitch(
                            value: isAlarmVibrationEnabled,
                            activeTrackColor: const Color(0xFF0D47A1),
                            onChanged: onAlarmVibrationChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.0 * fontSizeMultiplier),

                  // Alarme em Primeiro Plano: permissão especial que deixa o
                  // Alarme Principal abrir por cima de qualquer app (não só
                  // quando o celular está bloqueado) — sem ela, o app usa a
                  // notificação de tela cheia normal, que precisa ser tocada.
                  _buildSettingsCard(
                    title: 'Alarme em Primeiro Plano',
                    icon: Icons.notifications_active_outlined,
                    textColor: textColor,
                    fontSizeMultiplier: fontSizeMultiplier,
                    child: _OverlayPermissionCard(
                      textColor: textColor,
                      subTextColor: subTextColor,
                      fontSizeMultiplier: fontSizeMultiplier,
                    ),
                  ),
                  SizedBox(height: 16.0 * fontSizeMultiplier),

                  // Compartilhar: divulgar o app, ou a própria lista de
                  // medicamentos (útil pra mostrar pra um cuidador/familiar).
                  _buildSettingsCard(
                    title: 'Compartilhar',
                    icon: Icons.share,
                    textColor: textColor,
                    fontSizeMultiplier: fontSizeMultiplier,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.favorite_border,
                            color: textColor,
                            size: 26.0 * fontSizeMultiplier,
                          ),
                          title: Text(
                            'Compartilhar Aplicativo',
                            style: TextStyle(
                              fontSize: 16.0 * fontSizeMultiplier,
                              color: textColor,
                            ),
                          ),
                          onTap: _compartilharApp,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.medication_outlined,
                            color: textColor,
                            size: 26.0 * fontSizeMultiplier,
                          ),
                          title: Text(
                            'Compartilhar Medicamentos',
                            style: TextStyle(
                              fontSize: 16.0 * fontSizeMultiplier,
                              color: textColor,
                            ),
                          ),
                          onTap: () => _compartilharMedicamentos(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertModeOption({
    required String label,
    required String value,
    required Color textColor,
    required double fontSizeMultiplier,
  }) {
    final bool isSelected = alertMode == value;
    return RadioListTile<String>(
      value: value,
      groupValue: alertMode,
      onChanged: (novoValor) {
        if (novoValor != null) onAlertModeChanged(novoValor);
      },
      activeColor: currentTheme == 'Default'
          ? Colors.white
          : const Color(0xFF0D47A1),
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16.0 * fontSizeMultiplier,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    String label,
    String themeValue,
    Color color,
    Color textColor,
    String currentTheme,
    double m,
  ) {
    final isSelected = currentTheme == themeValue;
    return GestureDetector(
      onTap: () => onThemeChanged(themeValue),
      child: Column(
        children: [
          Container(
            width: 60.0 * m,
            height: 60.0 * m,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? textColor
                    : Colors.grey.withValues(alpha: 0.5),
                width: isSelected ? 4.0 : 1.0,
              ),
            ),
          ),
          SizedBox(height: 8.0 * m),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16.0 * m,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Color textColor,
    required double fontSizeMultiplier,
    required Widget child,
  }) {
    return GlassCard(
      isDark: currentTheme == 'Dark',
      borderRadius: 12.0,
      child: Padding(
        padding: EdgeInsets.all(24.0 * fontSizeMultiplier),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: textColor, size: 28.0 * fontSizeMultiplier),
                SizedBox(width: 12.0 * fontSizeMultiplier),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 22.0 * fontSizeMultiplier,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.0 * fontSizeMultiplier),
            child,
          ],
        ),
      ),
    );
  }
}

/// Status + botão da permissão "Exibir sobre outros apps". A concessão
/// acontece numa tela do próprio Android, fora do app — por isso reconfere
/// o status sempre que o usuário volta ao SeniCare (didChangeAppLifecycleState),
/// o mesmo padrão já usado em HomeScreen para recarregar dados ao retomar.
class _OverlayPermissionCard extends StatefulWidget {
  final Color textColor;
  final Color subTextColor;
  final double fontSizeMultiplier;

  const _OverlayPermissionCard({
    required this.textColor,
    required this.subTextColor,
    required this.fontSizeMultiplier,
  });

  @override
  State<_OverlayPermissionCard> createState() => _OverlayPermissionCardState();
}

class _OverlayPermissionCardState extends State<_OverlayPermissionCard>
    with WidgetsBindingObserver {
  bool? _concedida;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificar();
    }
  }

  Future<void> _verificar() async {
    final bool concedida = await NotificationService().hasOverlayPermission();
    if (mounted) setState(() => _concedida = concedida);
  }

  @override
  Widget build(BuildContext context) {
    final double m = widget.fontSizeMultiplier;
    final bool concedida = _concedida ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permite que o Alarme Principal abra por cima de qualquer tela, mesmo com o celular desbloqueado e em uso — sem precisar tocar numa notificação.',
          style: TextStyle(fontSize: 14.0 * m, color: widget.subTextColor),
        ),
        SizedBox(height: 12.0 * m),
        Row(
          children: [
            Icon(
              concedida ? Icons.check_circle : Icons.error_outline,
              color: concedida ? Colors.green : Colors.orange,
              size: 22.0 * m,
            ),
            SizedBox(width: 8.0 * m),
            Expanded(
              child: Text(
                concedida ? 'Permissão concedida' : 'Permissão não concedida',
                style: TextStyle(fontSize: 16.0 * m, color: widget.textColor),
              ),
            ),
          ],
        ),
        if (!concedida) ...[
          SizedBox(height: 12.0 * m),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => NotificationService().requestOverlayPermission(),
              child: Text('Permitir', style: TextStyle(fontSize: 16.0 * m)),
            ),
          ),
        ],
      ],
    );
  }
}
