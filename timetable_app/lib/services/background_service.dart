import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

const _taskName = 'course_schedule_refresh';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    // Background refresh is intentionally disabled. The app only refreshes
    // after an explicit user action.
    return true;
  });
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(backgroundCallbackDispatcher);
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(_taskName);
  }
}
