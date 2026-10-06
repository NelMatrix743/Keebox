import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('both font families are bundled with usable TrueType assets', () async {
    final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json'))
        as List<dynamic>;
    for (final familyName in ['Poppins', 'Inter']) {
      final family = manifest.cast<Map<String, dynamic>>().singleWhere(
        (entry) => entry['family'] == familyName,
      );
      final fonts = (family['fonts'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(fonts.map((font) => font['weight']), containsAll([400, 500, 600, 700]));
      for (final asset in fonts.map((font) => font['asset'] as String).toSet()) {
        final bytes = await rootBundle.load(asset);
        expect(bytes.lengthInBytes, greaterThan(0));
        expect(bytes.getUint32(0), 0x00010000);
      }
    }
  });
}
