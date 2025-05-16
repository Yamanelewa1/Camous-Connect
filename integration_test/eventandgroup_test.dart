import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:campusconnect/main.dart' as app;
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Create and publish event from Home > Events', (WidgetTester tester) async {
    await app.main(testMode: true);
    await tester.pumpAndSettle();

    // Login
    await tester.enterText(find.byKey(Key('email_field')), 'omarelewa@gmail.com');
    await tester.enterText(find.byKey(Key('password_field')), 'Omar5000');
    await tester.tap(find.byKey(Key('login_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byKey(Key('home_screen')), findsOneWidget);

    // Navigate to "Campus Events"
    await tester.tap(find.text('Campus Events'));
    await tester.pumpAndSettle();

    // Tap New Event button (FAB)
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Enter event title and description
    await tester.enterText(find.byType(TextField).at(0), 'Testing Events');
    await tester.enterText(find.byType(TextField).at(1), 'iam testing create Events');

    // Pick date
    await tester.tap(find.textContaining('Pick Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // confirm current date
    await tester.pumpAndSettle();

    // Pick time
    await tester.tap(find.textContaining('Pick Time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // confirm current time
    await tester.pumpAndSettle();

    // Save Locally
    await tester.tap(find.text('Save Locally'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(const Duration(seconds: 6));
    // Tap 'Publish' on the event card
    expect(find.byKey(Key('publish_button')), findsOneWidget);
    await tester.tap(find.byKey(Key('publish_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Confirm success snackbar
    expect(find.textContaining('published'), findsOneWidget);
    print(' Event created and published!');

    await tester.tap(find.byKey(Key('back_to_home_button')));
    await tester.pumpAndSettle();

// 📚 Tap Study Groups button
    await tester.tap(find.text('Study Groups'));
    await tester.pumpAndSettle();


    // Choose session time
    await tester.tap(find.textContaining('Choose Session Time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Enter custom topic if needed
    final customTopicField = find.byType(TextField).first;
    if (customTopicField.evaluate().isNotEmpty) {
      await tester.enterText(customTopicField, 'Test Study Group');
      await tester.pumpAndSettle();
    }

    // Press Create Study Group (Save locally)
    await tester.tap(find.text('Create Study Group'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(const Duration(seconds: 6));

    // Publish Study Group
    await tester.tap(find.byKey(Key('publish_button')));
    await tester.pumpAndSettle();

    await tester.pumpAndSettle(const Duration(seconds: 3));



    print(' Study group created and published!');



  });
}
