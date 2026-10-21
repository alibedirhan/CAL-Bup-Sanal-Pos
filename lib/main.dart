import 'package:flutter/material.dart';
import 'app.dart';
import 'canli_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const deneme = bool.fromEnvironment('BUP_DENEME', defaultValue: true);
  runApp(deneme ? const BupPosApp() : const CanliApp());
}
