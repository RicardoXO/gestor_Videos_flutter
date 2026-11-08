import 'package:flutter/material.dart';

class PanelAcciones extends StatelessWidget {
  final int seleccionados;
  final bool isDark;
  final VoidCallback onDesmarcarTodo;
  final VoidCallback onSeleccionarIntervalo;
  final VoidCallback onQuitarSufijo;
  final VoidCallback onDialogoRenombrar;
  final VoidCallback onDialogoSecuencia;
  final VoidCallback onLimpiarSubs;
  final VoidCallback onBorrarTitulo;
  final VoidCallback onIgualarTitulo;
  final VoidCallback onGestionarPistas;

  const PanelAcciones({
    super.key,
    required this.seleccionados,
    required this.isDark,
    required this.onDesmarcarTodo,
    required this.onSeleccionarIntervalo,
    required this.onQuitarSufijo,
    required this.onDialogoRenombrar,
    required this.onDialogoSecuencia,
    required this.onLimpiarSubs,
    required this.onBorrarTitulo,
    required this.onIgualarTitulo,
    required this.onGestionarPistas,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Indicador de cantidad y botón rojo para limpiar
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: isDark ? Colors.tealAccent : Colors.teal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$seleccionados seleccionados',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onDesmarcarTodo,
          icon: const Icon(Icons.clear_all, size: 20),
          label: const Text('Limpiar Selección'),
          style: ElevatedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: isDark ? Colors.red.shade900 : Colors.red.shade100,
            foregroundColor: isDark ? Colors.white : Colors.red.shade900,
          ),
        ),

        const SizedBox(height: 16),
        const Text(
          'Operaciones Especiales',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const Divider(),

        if (seleccionados >= 2) ...[
          ElevatedButton.icon(
            onPressed: onSeleccionarIntervalo,
            style: ElevatedButton.styleFrom(
              alignment: Alignment.centerLeft,
              backgroundColor: isDark
                  ? Colors.purple.shade900
                  : Colors.purple.shade100,
            ),
            icon: const Icon(Icons.format_line_spacing, size: 18),
            label: const Text('Rellenar Intervalo'),
          ),
          const SizedBox(height: 8),
        ],

        // MKVToolNix
        ElevatedButton.icon(
          onPressed: onGestionarPistas,
          style: ElevatedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: isDark
                ? Colors.pink.shade900
                : Colors.pink.shade100,
          ),
          icon: const Icon(Icons.layers_clear, size: 18),
          label: const Text('Quitar Pistas (Audio/Subs)'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onLimpiarSubs,
          style: ElevatedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: isDark
                ? Colors.deepPurple.shade900
                : Colors.deepPurple.shade100,
          ),
          icon: const Icon(Icons.subtitles_off, size: 18),
          label: const Text('Limpiar Subs (.ASS)'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onBorrarTitulo,
          style: ElevatedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: isDark
                ? Colors.blue.shade900
                : Colors.blue.shade100,
          ),
          icon: const Icon(Icons.title, size: 18),
          label: const Text('Borrar Título MKV'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onIgualarTitulo,
          style: ElevatedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: isDark
                ? Colors.teal.shade900
                : Colors.teal.shade100,
          ),
          icon: const Icon(Icons.sync, size: 18),
          label: const Text('Título = Nombre MKV'),
        ),

        const SizedBox(height: 16),
        const Text(
          'Renombrado Masivo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const Divider(),

        ElevatedButton(
          onPressed: onQuitarSufijo,
          style: ElevatedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: isDark ? Colors.red.shade800 : Colors.red.shade200,
            foregroundColor: Colors.white,
          ),
          child: const Text('Quitar " (1)" del final'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onDialogoRenombrar,
          style: ElevatedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: isDark
                ? Colors.orange.shade800
                : Colors.orange.shade200,
            foregroundColor: Colors.white,
          ),
          child: const Text('Renombrar (Conserva N°)'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onDialogoSecuencia,
          style: ElevatedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: isDark
                ? Colors.green.shade800
                : Colors.green.shade200,
            foregroundColor: Colors.white,
          ),
          child: const Text('Renombrar en Secuencia'),
        ),
      ],
    );
  }
}
