import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:plotwise/farm_state.dart';
import 'package:plotwise/main.dart';

void main() {
  testWidgets('home screen shows the add-plot prompt', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(create: (_) => FarmState(), child: const PlotWiseApp()));
    expect(find.text('Add your first plot'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });
}
