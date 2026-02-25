import 'package:flutter_test/flutter_test.dart';
import 'package:trackaccess/main.dart';

void main() {
  testWidgets('TrackAccess loads Student Module',
      (WidgetTester tester) async {

    await tester.pumpWidget(TrackAccessApp());

    expect(find.text('Student Module'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('Admin Module'), findsOneWidget);
  });
}