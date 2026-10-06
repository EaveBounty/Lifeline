import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lifeline/app.dart';
import 'package:lifeline/data/config/app_config.dart';
import 'package:lifeline/data/providers.dart';

void main() {
  testWidgets('首启且无同步根时显示「选择同步文件夹」', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final config = await AppConfig.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: const LifelineApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('选择同步文件夹'), findsWidgets);
    expect(find.text('同步方式指南'), findsWidgets);
  });
}
