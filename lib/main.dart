import 'dart:io';
import 'package:flutter/material.dart';

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
    );
  }
}

class GestorPrincipal extends StatefulWidget {
  const GestorPrincipal({super.key});

  @override
  State<GestorPrincipal> createState() => _GestorPrincipalState();
}

class _GestorPrincipalState extends State<GestorPrincipal> {
  // En desarrollo, puedes usar Directory.current.path o una ruta específica
  //String directorioBase = Directory.current.path;
  String directorioBase = r"D:\Videos";
  List<CarpetaModelo> datosCarpetas = [];
  List<CarpetaModelo> carpetasFiltradas = [];
  TextEditingController searchController = TextEditingController();
  bool expandirTodo = true;

  @override
  void initState() {
    super.initState();
    _escanearDirectorio();
    searchController.addListener(_filtrarResultados);
  }

  void _escanearDirectorio() {
    final dir = Directory(directorioBase);
    if (!dir.existsSync()) return;

    List<CarpetaModelo> carpetasTemp = [];

    // Escaneo superficial de directorios para agrupar (similar al os.walk)
    List<FileSystemEntity> entidades = dir.listSync(recursive: true);

    // Agrupar archivos por su directorio padre
    Map<String, List<File>> agrupacion = {};

    for (var entidad in entidades) {
      if (entidad is File) {
        String parentPath = entidad.parent.path;
        if (!agrupacion.containsKey(parentPath)) {
          agrupacion[parentPath] = [];
        }
        agrupacion[parentPath]!.add(entidad);
      }
    }

    agrupacion.forEach((ruta, archivos) {
      int tamanoTotal = archivos.fold(
        0,
        (sum, file) => sum + file.lengthSync(),
      );
      carpetasTemp.add(
        CarpetaModelo(
          rutaCompleta: ruta,
          nombre: ruta == directorioBase
              ? "RAIZ"
              : ruta.split(Platform.pathSeparator).last,
          tamanoBytes: tamanoTotal,
          archivos: archivos,
        ),
      );
    });

    setState(() {
      datosCarpetas = carpetasTemp;
      carpetasFiltradas = List.from(datosCarpetas);
    });
  }

  void _filtrarResultados() {
    String query = searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => carpetasFiltradas = List.from(datosCarpetas));
      return;
    }

    List<CarpetaModelo> filtrado = [];
    for (var carpeta in datosCarpetas) {
      bool coincideCarpeta = carpeta.nombre.toLowerCase().contains(query);
      List<File> archivosCoincidentes = carpeta.archivos
          .where(
            (f) => f.path
                .split(Platform.pathSeparator)
                .last
                .toLowerCase()
                .contains(query),
          )
          .toList();

      if (coincideCarpeta) {
        filtrado.add(carpeta);
      } else if (archivosCoincidentes.isNotEmpty) {
        filtrado.add(
          CarpetaModelo(
            rutaCompleta: carpeta.rutaCompleta,
            nombre: carpeta.nombre,
            tamanoBytes: carpeta.tamanoBytes,
            archivos: archivosCoincidentes,
          ),
        );
      }
    }

    setState(() {
      carpetasFiltradas = filtrado;
      expandirTodo = true; // Auto-expandir al buscar
    });
  }

  String _formatearTamano(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1048576) return "${(bytes / 1024).toStringAsFixed(2)} KB";
    return "${(bytes / 1048576).toStringAsFixed(2)} MB";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestor Avanzado de Archivos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Barra de búsqueda superior
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: '🔍 Buscar archivos o carpetas',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),

          // Controles de vista
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      carpetasFiltradas.sort(
                        (a, b) => a.nombre.compareTo(b.nombre),
                      );
                    });
                  },
                  icon: const Icon(Icons.sort_by_alpha),
                  label: const Text('Ordenar A-Z'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      expandirTodo = !expandirTodo;
                    });
                  },
                  icon: Icon(
                    expandirTodo ? Icons.unfold_less : Icons.unfold_more,
                  ),
                  label: Text(expandirTodo ? 'Contraer Todo' : 'Expandir Todo'),
                ),
              ],
            ),
          ),

          const Divider(),

          // Lista de resultados
          Expanded(
            child: ListView.builder(
              itemCount: carpetasFiltradas.length,
              itemBuilder: (context, index) {
                final carpeta = carpetasFiltradas[index];
                return Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: expandirTodo,
                    leading: const Icon(Icons.folder, color: Colors.amber),
                    title: Text(
                      carpeta.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(_formatearTamano(carpeta.tamanoBytes)),
                    children: carpeta.archivos.map((archivo) {
                      String nombreArchivo = archivo.path
                          .split(Platform.pathSeparator)
                          .last;
                      int tamanoArchivo = archivo.lengthSync();
                      return ListTile(
                        contentPadding: const EdgeInsets.only(
                          left: 40,
                          right: 16,
                        ),
                        leading: const Icon(
                          Icons.insert_drive_file,
                          color: Colors.blueGrey,
                        ),
                        title: Text(nombreArchivo),
                        trailing: Text(_formatearTamano(tamanoArchivo)),
                        onTap: () {
                          // Aquí puedes integrar lógica para abrir el archivo
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CarpetaModelo {
  final String rutaCompleta;
  final String nombre;
  final int tamanoBytes;
  final List<File> archivos;

  CarpetaModelo({
    required this.rutaCompleta,
    required this.nombre,
    required this.tamanoBytes,
    required this.archivos,
  });
}
