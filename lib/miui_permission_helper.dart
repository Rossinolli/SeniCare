// Identifica se o celular é Xiaomi/Redmi/POCO e mostra um aviso explicando
// como ativar, manualmente, as permissões que esses aparelhos bloqueiam por
// padrão e que são necessárias para o alarme funcionar direito.

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';

class MiuiPermissionHelper {
  MiuiPermissionHelper._();

  static Future<bool> _isXiaomiDevice() async {
    if (!Platform.isAndroid) return false;
    try {
      final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
      final String fabricante = info.manufacturer.toLowerCase();
      final String marca = info.brand.toLowerCase();
      return fabricante.contains('xiaomi') ||
          marca.contains('xiaomi') ||
          marca.contains('redmi') ||
          marca.contains('poco');
    } catch (e) {
      debugPrint('[MiuiPermissionHelper] Falha ao detectar fabricante: $e');
      return false;
    }
  }

  /// Mostra o aviso educativo uma única vez (controlado por SharedPreferences)
  /// e só em aparelhos Xiaomi/Redmi/POCO. Seguro para chamar sempre no início
  /// do app — sai cedo em qualquer outro caso.
  static Future<void> mostrarAvisoSeNecessario(BuildContext context) async {
    if (!await _isXiaomiDevice()) return;

    final prefs = await SharedPreferences.getInstance();
    final bool jaMostrado =
        prefs.getBool(AppPreferenceKeys.miuiAvisoMostrado) ??
        AppPreferenceDefaults.miuiAvisoMostrado;
    if (jaMostrado) return;

    await prefs.setBool(AppPreferenceKeys.miuiAvisoMostrado, true);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Atenção, usuário Xiaomi/MIUI'),
        content: const Text(
          'Para os alarmes de remédio tocarem mesmo com a tela bloqueada, '
          'vá em:\n\n'
          'Configurações > Apps > SeniCare > Permissões\n\n'
          'E ative:\n'
          '• "Mostrar na tela de bloqueio"\n'
          '• "Janelas pop-up enquanto em segundo plano"\n'
          '• "Iniciar automaticamente" (Autostart)\n\n'
          'A MIUI bloqueia isso por padrão, mesmo com as permissões do '
          'Android já concedidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}
