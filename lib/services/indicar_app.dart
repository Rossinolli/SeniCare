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

/// Descrição enviada junto com o aplicativo.
const String _convite =
    'Este é o SeniCare, um aplicativo que ajuda a tomar os remédios na hora '
    'certa: ele avisa com alarme no horário de cada dose, guarda o '
    'histórico do que foi tomado e gera um relatório para levar ao médico. '
    'Feito para ser simples, com letras grandes e poucos toques. Gratuito e '
    'sem anúncios; os dados ficam só no celular.';

const String _comoInstalar =
    'Como instalar: abra o arquivo SeniCare.apk no celular Android e toque '
    'em Instalar (se o celular pedir, permita "instalar apps '
    'desconhecidos").';

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
          // O WhatsApp, o e-mail e o Drive mostram a descrição junto com o
          // arquivo; o assunto vale para o e-mail.
          subject: 'SeniCare — aplicativo de lembrete de remédios',
          text: '$_convite\n\n$_comoInstalar',
        ),
      );
      return true;
    } on Object {
      return false;
    }
  }
}
