import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:speedreeder/services/text_import_encoding.dart';

void main() {
  group('decodeImportTextBytes', () {
    test('UTF-8 plain', () {
      final b = Uint8List.fromList(utf8.encode('Привет, мир.'));
      expect(decodeImportTextBytes(b), 'Привет, мир.');
    });

    test('UTF-8 with BOM', () {
      final inner = utf8.encode('Заголовок');
      final b = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...inner]);
      expect(decodeImportTextBytes(b), 'Заголовок');
    });

    test('Windows-1251 when not valid UTF-8', () {
      // «Привет» in CP1251
      final b = Uint8List.fromList([0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2]);
      expect(decodeImportTextBytes(b), 'Привет');
    });

    test('looksLikePdfBytes', () {
      expect(
        looksLikePdfBytes(Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D])),
        true,
      );
      expect(looksLikePdfBytes(Uint8List.fromList(utf8.encode('hello'))), false);
    });
  });
}
