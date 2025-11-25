import 'package:dart_style/dart_style.dart' show DartFormatter;

import 'log.dart';

String formatDartContent(String content, String fileName) {
  try {
    var formatter = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);
    return formatter.format(content);
  } catch (e) {
    Log.i('Failed to format \'$fileName\' file.');
    return content;
  }
}
