import 'package:flutter/widgets.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart' show MyApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  enableFlutterDriverExtension();

  await Supabase.initialize(
    url: 'https://ldbpoumunzbwufbuphvq.supabase.co',
    anonKey: 'sb_publishable_DkMsPnW_klEETmpvGOT50g_dINsFpxw',
  );

  runApp(const MyApp());
}
