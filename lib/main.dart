import 'package:flutter/widgets.dart';
import 'bootstrap/app_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final app = await bootstrapApp();
  runApp(app);
}
