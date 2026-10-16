import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/network/api_session.dart';

void main() {
  test(
    'late rejection reuses the token renewed for the same session',
    () async {
      final session = APISession();
      session.set('new', previousToken: 'old', onInvalidSession: () async {});
      expect(await session.refresh('old'), 'new');
      session.set('another-account', onInvalidSession: () async {});
      expect(await session.refresh('old'), isNull);
      session.clear();
      expect(await session.refresh('new'), isNull);
    },
  );
}
