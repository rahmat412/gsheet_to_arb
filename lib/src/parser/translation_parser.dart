/*
 * Copyright (c) 2024, Rahmatur Ramadhan
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

import 'dart:async';

import 'package:quiver/iterables.dart' as iterables;
import 'package:recase/recase.dart';

import '_plurals_parser.dart';
import '../arb/arb.dart';
import '../translation_document.dart';
import '../utils/log.dart';

class TranslationParser {
  final bool addContextPrefix;

  TranslationParser({required this.addContextPrefix});

  Future<ArbBundle> parseDocument(TranslationsDocument document) async {
    final builders = <ArbDocumentBuilder>[];
    final parsers = <PluralsParser>[];

    for (var langauge in document.languages) {
      final builder = ArbDocumentBuilder(langauge, document.lastModified);
      final parser = PluralsParser(addContextPrefix);
      builders.add(builder);
      parsers.add(parser);
    }

    // for each row
    for (var item in document.items) {
      // for each language
      for (var index in iterables.range(0, document.languages.length)) {
        String itemValue;
        //incase value does not exist
        if (index < item.values.length) {
          itemValue = item.values[index as int];
        } else {
          itemValue = '';
        }

        if (itemValue == '') {
          Log.i(
              'WARNING: empty string in lang: ${document.languages[index as int]}, key: ${item.key}');
        }

        final itemPlaceholders = _findPlaceholders(itemValue);

        final builder = builders[index as int];
        final parser = parsers[index];

        // plural consume
        final status = parser.consume(ArbResource(item.key, itemValue,
            placeholders: itemPlaceholders,
            context: item.category,
            description: item.description));

        if (status is Consumed) {
          continue;
        }

        if (status is Completed) {
          builder.add(status.resource);

          // next plural
          if (status.consumed) {
            continue;
          }
        }

        final key = addContextPrefix && item.category.isNotEmpty
            ? ReCase('${item.category}_${item.key}').camelCase
            : ReCase(item.key).camelCase;

        // add resource
        builder.add(ArbResource(key, itemValue,
            context: item.category,
            description: item.description,
            placeholders: itemPlaceholders));
      }
    }

    // finalizer
    for (var index in iterables.range(0, document.languages.length - 1)) {
      final builder = builders[index as int];
      final parser = parsers[index];
      final status = parser.complete();
      if (status is Completed) {
        builder.add(status.resource);
      }
    }

    // build all documents
    var documents = <ArbDocument>[];
    for (var builder in builders) {
      documents.add(builder.build());
    }

    return ArbBundle(documents);
  }

  final _placeholderRegex = RegExp('\\{(.+?)\\}');

  List<ArbResourcePlaceholder> _findPlaceholders(String text) {
    if (text.isEmpty) {
      return <ArbResourcePlaceholder>[];
    }

    var matches = _placeholderRegex.allMatches(text);
    var placeholders = <String, ArbResourcePlaceholder>{};
    for (var match in matches) {
      var group = match.group(0);
      var placeholderName = group!.substring(1, group.length - 1);

      if (placeholders.containsKey(placeholderName)) {
        throw Exception('Placeholder $placeholderName already declared');
      }
      placeholders[placeholderName] =
          (ArbResourcePlaceholder(name: placeholderName, type: 'text'));
    }
    return placeholders.values.toList();
  }
}
