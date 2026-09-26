import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'farm_state.dart';
import 'screens/home.dart';
import 'theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      // Swap in your real backend: FarmState(repository: YourRepository())
      create: (_) => FarmState(),
      child: const PlotWiseApp(),
    ),
  );
}

class PlotWiseApp extends StatelessWidget {
  const PlotWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlotWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
