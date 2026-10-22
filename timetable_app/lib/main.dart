import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final state = AppState();
        state.bootstrap();
        return state;
      },
      child: const TimetableApp(),
    ),
  );
}
