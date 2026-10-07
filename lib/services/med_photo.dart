// Fotos dos remédios: captura (câmera ou galeria) já reduzida, guardada na
// pasta permanente do app.
//
// Antes, o app salvava o caminho devolvido pelo image_picker — um arquivo no
// diretório de CACHE, em resolução total da câmera (vários MB). O Android
// pode limpar esse cache a qualquer momento (a foto sumia), e decodificar
// fotos de 12 MP em cada card deixava a lista lenta em aparelhos simples.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MedPhotoStorage {
  MedPhotoStorage._();

  /// Lado maior da foto salva: nítida até ~3x a densidade de tela no
  /// avatar, dezenas de vezes menor que o original.
  static const double ladoMaximo = 720;
  static const int qualidadeJpeg = 80;

  static Future<Directory> _pasta() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory pasta = Directory(p.join(docs.path, 'fotos_remedios'));
    if (!await pasta.exists()) await pasta.create(recursive: true);
    return pasta;
  }

  /// Abre a câmera ou a galeria e devolve o caminho PERMANENTE da foto já
  /// reduzida, ou null se o usuário desistiu.
  static Future<String?> capturar(ImageSource origem) async {
    final XFile? foto = await ImagePicker().pickImage(
      source: origem,
      maxWidth: ladoMaximo,
      maxHeight: ladoMaximo,
      imageQuality: qualidadeJpeg,
    );
    if (foto == null) return null;
    final Directory pasta = await _pasta();
    final String extensao = p.extension(foto.path).isEmpty
        ? '.jpg'
        : p.extension(foto.path);
    final String destino = p.join(
      pasta.path,
      'med_${DateTime.now().millisecondsSinceEpoch}$extensao',
    );
    await foto.saveTo(destino);
    return destino;
  }

  /// Apaga uma foto salva por [capturar]. Ignora caminhos fora da pasta do
  /// app — nunca apaga arquivo de terceiros.
  static Future<void> apagar(String? caminho) async {
    if (caminho == null) return;
    try {
      final Directory pasta = await _pasta();
      if (!p.isWithin(pasta.path, caminho)) return;
      final File arquivo = File(caminho);
      if (await arquivo.exists()) await arquivo.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[Fotos] Falha ao apagar: $e');
    }
  }
}
