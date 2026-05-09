import 'package:flutter/material.dart';
import 'app/bootstrap.dart';
import 'app/jeepni_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapApp();
  runApp(const JeepNiApp());
}
