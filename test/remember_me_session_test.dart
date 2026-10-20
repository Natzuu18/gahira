import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gahira/core/auth/remember_me_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('remembered session expires seven days after it is saved', () async {
    final savedAt = DateTime.now();

    final expiresAt = await RememberMeSession.rememberForSevenDays();

    expect(
      expiresAt.difference(savedAt),
      greaterThanOrEqualTo(const Duration(days: 7)),
    );
    expect(
      expiresAt.difference(savedAt),
      lessThan(const Duration(days: 7, seconds: 1)),
    );
    expect(
      (await RememberMeSession.expiresAt)?.millisecondsSinceEpoch,
      expiresAt.millisecondsSinceEpoch,
    );
  });

  test('clearing remembered session removes the saved expiry', () async {
    await RememberMeSession.rememberForSevenDays();

    await RememberMeSession.clear();

    expect(await RememberMeSession.expiresAt, isNull);
  });
}
