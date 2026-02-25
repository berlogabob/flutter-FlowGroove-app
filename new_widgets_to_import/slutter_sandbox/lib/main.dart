import 'package:flutter/material.dart';
import 'song_constructor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Song Structure Constructor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SongConstructorPage(),
    );
  }
}

class SongConstructorPage extends StatefulWidget {
  const SongConstructorPage({super.key});

  @override
  State<SongConstructorPage> createState() => _SongConstructorPageState();
}

class _SongConstructorPageState extends State<SongConstructorPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Song Constructor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const SongConstructor(),
    );
  }
}
