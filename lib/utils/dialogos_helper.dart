import 'package:flutter/material.dart';

class DialogosHelper {
  static void mostrarDialogoRenombrar(
    BuildContext context,
    bool secuencial,
    Function(String, String) onAplicar,
  ) {
    TextEditingController nombreCtrl = TextEditingController();
    TextEditingController numCtrl = TextEditingController(text: "01");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          secuencial ? 'Renombrar en Secuencia' : 'Renombrar (Mantiene Número)',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nuevo nombre base'),
            ),
            if (secuencial) ...[
              const SizedBox(height: 10),
              TextField(
                controller: numCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número de inicio',
                  hintText: '01',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isNotEmpty) {
                Navigator.pop(context);
                onAplicar(nombreCtrl.text.trim(), numCtrl.text.trim());
              }
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  static void mostrarDialogoLimpiarSubtitulos(
    BuildContext context,
    Function(String) onEmpezar,
  ) {
    TextEditingController textoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Subtítulos (.ASS)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Texto a buscar en los diálogos:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textoCtrl,
              decoration: const InputDecoration(
                labelText: 'Texto o Link',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (textoCtrl.text.trim().isNotEmpty) {
                Navigator.pop(context);
                onEmpezar(textoCtrl.text.trim());
              }
            },
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> mostrarDialogoGestionarPistas(
    BuildContext context,
    List<dynamic> pistasAudio,
    List<dynamic> pistasSubs,
    List<int> tracksAEliminarAudio,
    List<int> tracksAEliminarSubs,
    bool esMulti,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          title: const Text('Eliminar Pistas'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (esMulti)
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.orange.withValues(alpha: 0.2),
                      child: const Text(
                        '⚠️ Se aplicará a todos los videos asumiendo el mismo orden.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Text(
                    'AUDIO',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ...pistasAudio.map((t) {
                    bool eliminar = tracksAEliminarAudio.contains(t['id']);
                    return CheckboxListTile(
                      value: eliminar,
                      activeColor: Colors.red.shade700,
                      title: Text(
                        'ID ${t['id']} [${t['properties']?['language'] ?? 'und'}] - ${t['properties']?['track_name'] ?? 'N/A'}',
                        style: TextStyle(
                          decoration: eliminar
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      onChanged: (val) => setStateSB(
                        () => val == true
                            ? tracksAEliminarAudio.add(t['id'])
                            : tracksAEliminarAudio.remove(t['id']),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  const Text(
                    'SUBTÍTULOS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ...pistasSubs.map((t) {
                    bool eliminar = tracksAEliminarSubs.contains(t['id']);
                    return CheckboxListTile(
                      value: eliminar,
                      activeColor: Colors.red.shade700,
                      title: Text(
                        'ID ${t['id']} [${t['properties']?['language'] ?? 'und'}] - ${t['properties']?['track_name'] ?? 'N/A'}',
                        style: TextStyle(
                          decoration: eliminar
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      onChanged: (val) => setStateSB(
                        () => val == true
                            ? tracksAEliminarSubs.add(t['id'])
                            : tracksAEliminarSubs.remove(t['id']),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed:
                  (tracksAEliminarAudio.isEmpty && tracksAEliminarSubs.isEmpty)
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Eliminar Pistas'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<String?> mostrarConfirmacionSubs(
    BuildContext context,
    String nombreArchivo,
    List<String> lineas,
  ) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Limpieza en: $nombreArchivo',
          style: const TextStyle(fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${lineas.length} líneas basura:',
                style: const TextStyle(color: Colors.orange),
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                padding: const EdgeInsets.all(8),
                color: Colors.black12,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lineas.length,
                  itemBuilder: (c, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      lineas[i],
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '¿Qué deseas hacer?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancelar'),
            child: const Text(
              'Cancelar Todo',
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'omitir'),
            child: const Text('Omitir video'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'eliminar'),
            child: const Text('Eliminar líneas'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, 'todos'),
            child: const Text('Aplicar a Todos'),
          ),
        ],
      ),
    );
  }
}
