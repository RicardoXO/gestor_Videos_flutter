import 'package:flutter/material.dart';
import 'screens/gestor_principal.dart';

void main() {
  runApp(const GestorArchivosApp());
}

class GestorArchivosApp extends StatelessWidget {
  const GestorArchivosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor Avanzado',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const GestorPrincipal(),
      debugShowCheckedModeBanner: false,
    );
  }
}
