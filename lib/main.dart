import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'repositories/player_repository.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final repository = await PlayerRepository.open();
  runApp(GroupingApp(repository: repository));
}

class GroupingApp extends StatelessWidget {
  const GroupingApp({super.key, required this.repository});

  final PlayerRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '羽球分組管理',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: HomeScreen(repository: repository),
    );
  }
}
