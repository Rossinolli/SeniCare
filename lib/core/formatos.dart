// Formatação de datas e horas em português, num só lugar.

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

String hhmm(DateTime t) => DateFormat('HH:mm').format(t);

/// 'Terça-feira, 7 de outubro'.
String dataPorExtenso(DateTime d) =>
    capitalizar(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(d));

/// '07/10/2026'.
String dataCurta(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

/// 'ter., 07/10'.
String diaCurto(DateTime d) => DateFormat('EEE, dd/MM', 'pt_BR').format(d);

String capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

Future<String> rootBundleLoad(String caminho) => rootBundle.loadString(caminho);
