// "Indicar o SeniCare": envia o próprio aplicativo (o arquivo .apk instalado)
// para outra pessoa pelo WhatsApp, Bluetooth, Drive... — ou só uma mensagem
// com o link de download, quando houver um publicado.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Link público de download (loja ou página de releases). Vazio enquanto o
/// app não estiver publicado: aí só o envio do arquivo é oferecido.
const String linkDeDownload = '';

const String _convite =
    'Conheça o SeniCare: lembretes de remédio simples, com alarme na hora '
    'certa e histórico das doses.';

class IndicarApp {
  static const MethodChannel _nativo = MethodChannel('senicare/overlay_alarm');

  static bool get temLink => linkDeDownload.isNotEmpty;

  /// Mensagem com o link de download.
  static Future<void> enviarLink() => SharePlus.instance.share(
    ShareParams(text: '$_convite\nBaixe aqui: $linkDeDownload'),
  );

  /// Copia o APK instalado para a pasta temporária com um nome amigável
  /// ("SeniCare.apk") e abre o menu de compartilhar do Android.
  /// Devolve false se o aparelho não permitir (ex.: instalado pela loja em
  /// partes).
  static Future<bool> enviarArquivo() async {
    try {
      final String? origem = await _nativo.invokeMethod<String>('apkPath');
      if (origem == null) return false;
      final Directory tmp = await getTemporaryDirectory();
      final File copia = await File(origem).copy('${tmp.path}/SeniCare.apk');
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              copia.path,
              mimeType: 'application/vnd.android.package-archive',
            ),
          ],
          text:
              '$_convite\nPara instalar, abra o arquivo SeniCare.apk no '
              'celular Android (permita "instalar apps desconhecidos" se '
              'ele pedir).',
        ),
      );
      return true;
    } on Object {
      return false;
    }
  }
}
