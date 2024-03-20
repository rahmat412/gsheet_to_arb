/*
 * Copyright (c) 2024, Rahmatur Ramadhan
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:convert';
import 'dart:io';

import 'package:intl_translation/extract_messages.dart';
import 'package:intl_translation/generate_localized.dart';
import 'package:intl_translation/src/message_parser.dart';
import 'package:intl_translation/src/messages/main_message.dart';
import 'package:intl_translation/src/messages/literal_string_message.dart';
import 'package:path/path.dart' as path;

import '../../gsheet_to_arb.dart';

class IntlTranslationGenerator {
  void generateLookupTables(
    String arbDirectoryPath,
    String outputDirectoryPath,
    String localizationFileName,
  ) {
    var extraction = MessageExtraction();
    var generation = MessageGeneration();

    // generation.codegenMode = 'release';
    generation.generatedFilePrefix = "";

    var dartFiles = [
      '${outputDirectoryPath}/${localizationFileName.toLowerCase()}.dart'
    ];

    var jsonFiles = Directory(arbDirectoryPath)
        .listSync()
        .where((file) => file.path.endsWith('.arb'))
        .map<String>((file) => file.path);

    var targetDir = outputDirectoryPath + "/intl/";

    extraction.suppressWarnings = true;
    var allMessages = dartFiles.map((each) => extraction.parseFile(File(each)));

    messages = {};
    for (var eachMap in allMessages) {
      eachMap.forEach(
          (key, value) => messages.putIfAbsent(key, () => []).add(value));
    }
    for (var arg in jsonFiles) {
      var file = File(arg);
      generateLocaleFile(file, targetDir, generation);
    }

    var mainImportFile = File(path.join(
        targetDir, '${generation.generatedFilePrefix}messages_all.dart'));
    mainImportFile.writeAsStringSync(generation.generateLocalesImportFile());
  }

  /// Keeps track of all the messages we have processed so far, keyed by message
  /// name.
  Map<String, List<MainMessage>> messages = {};

  JsonCodec jsonDecoder = const JsonCodec();

  /// Create the file of generated code for a particular locale. We read the ARB
  /// data and create [BasicTranslatedMessage] instances from everything,
  /// excluding only the special _locale attribute that we use to indicate the
  /// locale. If that attribute is missing, we try to get the locale from the last
  /// section of the file name.
  void generateLocaleFile(
      File file, String targetDir, MessageGeneration generation) {
    var src = file.readAsStringSync();
    var data = jsonDecoder.decode(src);
    var locale = data['@@locale'] ?? data['_locale'];
    if (locale == null) {
      // Get the locale from the end of the file name. This assumes that the file
      // name doesn't contain any underscores except to begin the language tag
      // and to separate language from country. Otherwise we can't tell if
      // my_file_fr.arb is locale "fr" or "file_fr".
      var name = path.basenameWithoutExtension(file.path);
      locale = name.split('_').skip(1).join('_');
      Log.i('No @@locale or _locale field found in $name, '
          "assuming '$locale' based on the file name.");
    }
    generation.allLocales.add(locale);

    var translations = <TranslatedMessage>[];
    data.forEach((id, messageData) {
      TranslatedMessage? message = recreateIntlObjects(id, messageData);
      if (message != null) {
        translations.add(message);
      }
    });
    generation.generateIndividualMessageFile(locale, translations, targetDir);
  }

  /// Regenerate the original IntlMessage objects from the given [data]. For
  /// things that are messages, we expect [id] not to start with "@" and
  /// [data] to be a String. For metadata we expect [id] to start with "@"
  /// and [data] to be a Map or null. For metadata we return null.
  BasicTranslatedMessage? recreateIntlObjects(String id, data) {
    if (id.startsWith('@')) return null;
    if (data == null) return null;
    var parsed = MessageParser(data).pluralGenderSelectParse();
    if (parsed is LiteralString && parsed.string.isEmpty) {
      parsed = MessageParser(data).nonIcuMessageParse();
    }
    return BasicTranslatedMessage(id, parsed, messages);
  }
}

/// A TranslatedMessage that just uses the name as the id and knows how to look
/// up its original messages in our [messages].class

class BasicTranslatedMessage extends TranslatedMessage {
  String name;
  Map<String, List<MainMessage>> messages;

  BasicTranslatedMessage(this.name, translated, this.messages)
      : super(name, translated, messages[name]!);

  @override
  List<MainMessage> get originalMessages => (super.originalMessages.isEmpty)
      ? _findOriginals()
      : super.originalMessages;

  // We know that our [id] is the name of the message, which is used as the
  //key in [messages].
  List<MainMessage> _findOriginals() => messages[id] ?? originalMessages;
}