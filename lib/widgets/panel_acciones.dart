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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.blueGrey.shade900 : Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: isDark ? Colors.blueGrey.shade700 : Colors.blueGrey.shade300,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: isDark ? Colors.tealAccent : Colors.teal,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                '$seleccionados Seleccionados',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onDesmarcarTodo,
                icon: const Icon(Icons.clear_all),
                label: const Text('Desmarcar Todo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.red.shade900
                      : Colors.red.shade100,
                  foregroundColor: isDark ? Colors.white : Colors.red.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (seleccionados >= 2) ...[
                  ElevatedButton.icon(
                    onPressed: onSeleccionarIntervalo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.purple.shade900
                          : Colors.purple.shade100,
                    ),
                    icon: const Icon(Icons.format_line_spacing, size: 18),
                    label: const Text('Intervalo'),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  onPressed: onGestionarPistas,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.pink.shade900
                        : Colors.pink.shade100,
                  ),
                  icon: const Icon(Icons.layers_clear, size: 18),
                  label: const Text('Pistas (Audio/Subs)'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onLimpiarSubs,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.deepPurple.shade900
                        : Colors.deepPurple.shade100,
                  ),
                  icon: const Icon(Icons.subtitles_off, size: 18),
                  label: const Text('Limpiar Subs (.ASS)'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onBorrarTitulo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.blue.shade900
                        : Colors.blue.shade100,
                  ),
                  icon: const Icon(Icons.title, size: 18),
                  label: const Text('Borrar Título MKV'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onIgualarTitulo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.teal.shade900
                        : Colors.teal.shade100,
                  ),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Título = Nombre MKV'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onQuitarSufijo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.red.shade800
                        : Colors.red.shade200,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Quitar " (1)"'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onDialogoRenombrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.orange.shade800
                        : Colors.orange.shade200,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Renombrar (Conserva N°)'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onDialogoSecuencia,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.green.shade800
                        : Colors.green.shade200,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Renombrar Secuencia'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
