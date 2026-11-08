import 'package:flutter/material.dart';
import 'screens/gestor_principal.dart';

// Variable global para el Modo Oscuro
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() {
  runApp(const GestorArchivosApp());
}

class GestorArchivosApp extends StatelessWidget {
  const GestorArchivosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Gestor Avanzado',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueGrey,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueGrey,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: currentMode,
          home: const GestorPrincipal(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
