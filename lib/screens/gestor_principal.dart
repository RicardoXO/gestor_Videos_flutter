import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Importamos nuestros modelos de datos
import '../models/carpeta_modelo.dart';
import '../models/archivo_modelo.dart';

class GestorPrincipal extends StatefulWidget {
  const GestorPrincipal({super.key});

  @override
  State<GestorPrincipal> createState() => _GestorPrincipalState();
}

class _GestorPrincipalState extends State<GestorPrincipal> {
  // ATENCIÓN: Cambia esta ruta por la de tu carpeta de videos.
  String directorioBase = r"D:\Videos";

  List<CarpetaModelo> datosCarpetas = [];
  List<CarpetaModelo> carpetasFiltradas = [];
  List<ArchivoModelo> todosLosArchivos = [];
  List<ArchivoModelo> archivosFiltrados = [];

  TextEditingController searchController = TextEditingController();
  bool expandirTodo = true;
  String vistaActual = "agrupada";

  @override
  void initState() {
    super.initState();
    _escanearDirectorio();
    searchController.addListener(_actualizarVista);
  }

  void _escanearDirectorio() {
    final dir = Directory(directorioBase);
    if (!dir.existsSync()) return;

    List<CarpetaModelo> carpetasTemp = [];
    List<ArchivoModelo> archivosTemp = [];

    List<FileSystemEntity> entidades = dir.listSync(recursive: true);
    Map<String, List<ArchivoModelo>> agrupacion = {};

    for (var entidad in entidades) {
      if (entidad is File) {
        String parentPath = entidad.parent.path;
        String nombre = entidad.path.split(Platform.pathSeparator).last;
        int tamano = entidad.lengthSync();
        String tipo = nombre.contains('.') ? nombre.split('.').last : 'Archivo';

        ArchivoModelo archivo = ArchivoModelo(
          nombre: nombre,
          rutaCompleta: entidad.path,
          tamanoBytes: tamano,
          tipo: tipo,
        );

        archivosTemp.add(archivo);

        if (!agrupacion.containsKey(parentPath)) {
          agrupacion[parentPath] = [];
        }
        agrupacion[parentPath]!.add(archivo);
      }
    }

    agrupacion.forEach((ruta, archivos) {
      int tamanoTotal = archivos.fold(0, (sum, a) => sum + a.tamanoBytes);
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
      todosLosArchivos = archivosTemp;
      _vistaAgrupadaNormal();
    });
  }

  void _actualizarVista() {
    if (vistaActual == "agrupada") {
      _vistaAgrupadaNormal();
    } else if (vistaActual == "ordenada") {
      _vistaOrdenadaNombre();
    } else if (vistaActual == "archivos") {
      _vistaArchivosPorTamano();
    }
  }

  void _aplicarFiltroCarpetas(List<CarpetaModelo> base) {
    String query = searchController.text.toLowerCase();
    if (query.isEmpty) {
      carpetasFiltradas = List.from(base);
      return;
    }

    List<CarpetaModelo> filtrado = [];
    for (var carpeta in base) {
      bool coincideCarpeta = carpeta.nombre.toLowerCase().contains(query);
      List<ArchivoModelo> archivosCoincidentes = carpeta.archivos
          .where((a) => a.nombre.toLowerCase().contains(query))
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
    carpetasFiltradas = filtrado;
    expandirTodo = true;
  }

  void _vistaAgrupadaNormal() {
    setState(() {
      vistaActual = "agrupada";
      List<CarpetaModelo> ordenados = List.from(datosCarpetas);
      ordenados.sort((a, b) => a.rutaCompleta.compareTo(b.rutaCompleta));
      _aplicarFiltroCarpetas(ordenados);
    });
  }

  void _vistaOrdenadaNombre() {
    setState(() {
      vistaActual = "ordenada";
      List<CarpetaModelo> ordenados = List.from(datosCarpetas);
      ordenados.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
      _aplicarFiltroCarpetas(ordenados);
    });
  }

  void _vistaArchivosPorTamano() {
    setState(() {
      vistaActual = "archivos";
      String query = searchController.text.toLowerCase();

      archivosFiltrados = query.isEmpty
          ? List.from(todosLosArchivos)
          : todosLosArchivos
                .where((a) => a.nombre.toLowerCase().contains(query))
                .toList();

      archivosFiltrados.sort((a, b) => b.tamanoBytes.compareTo(a.tamanoBytes));
    });
  }

  void _exportarTxt() async {
    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    String nombreArchivo = 'reporte_archivos_$timestamp.txt';
    File archivoExport = File(
      '$directorioBase${Platform.pathSeparator}$nombreArchivo',
    );

    StringBuffer buffer = StringBuffer();
    buffer.writeln("REPORTE: $directorioBase");
    if (searchController.text.isNotEmpty) {
      buffer.writeln("Filtro aplicado: '${searchController.text}'");
    }
    buffer.writeln("=" * 80 + "\n");

    if (vistaActual == "archivos") {
      for (var archivo in archivosFiltrados) {
        buffer.writeln(
          "${archivo.nombre.padRight(50)} | ${_formatearTamano(archivo.tamanoBytes).padLeft(10)} | Ruta: ${archivo.rutaCompleta}",
        );
      }
    } else {
      for (var carpeta in carpetasFiltradas) {
        buffer.writeln(
          "📁${carpeta.nombre} [Peso Total: ${_formatearTamano(carpeta.tamanoBytes)}] [Ruta: ${carpeta.rutaCompleta}]",
        );
        for (var archivo in carpeta.archivos) {
          buffer.writeln(
            "    📄${archivo.nombre.padRight(50)} | ${_formatearTamano(archivo.tamanoBytes).padLeft(10)}",
          );
        }
        buffer.writeln("-" * 80);
      }
    }

    await archivoExport.writeAsString(buffer.toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reporte guardado en: ${archivoExport.path}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  String _formatearTamano(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1048576) return "${(bytes / 1024).toStringAsFixed(2)} KB";
    if (bytes < 1073741824) return "${(bytes / 1048576).toStringAsFixed(2)} MB";
    return "${(bytes / 1073741824).toStringAsFixed(2)} GB";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestor Avanzado de Archivos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: '🔍 Buscar archivos o carpetas',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 4.0,
            ),
            child: Wrap(
              spacing: 8.0,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vistaActual == "agrupada"
                        ? Colors.blue.shade100
                        : null,
                  ),
                  onPressed: _vistaAgrupadaNormal,
                  icon: const Icon(Icons.folder),
                  label: const Text('Agrupar por Carpetas'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vistaActual == "ordenada"
                        ? Colors.yellow.shade100
                        : null,
                  ),
                  onPressed: _vistaOrdenadaNombre,
                  icon: const Icon(Icons.sort_by_alpha),
                  label: const Text('Carpetas por Nombre (A-Z)'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vistaActual == "archivos"
                        ? Colors.deepOrange.shade100
                        : null,
                  ),
                  onPressed: _vistaArchivosPorTamano,
                  icon: const Icon(Icons.balance),
                  label: const Text('Solo Archivos (Por Tamaño)'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 4.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: vistaActual == "archivos"
                      ? null
                      : () {
                          setState(() {
                            expandirTodo = !expandirTodo;
                          });
                        },
                  icon: Icon(
                    expandirTodo ? Icons.unfold_less : Icons.unfold_more,
                  ),
                  label: Text(expandirTodo ? 'Contraer Todo' : 'Expandir Todo'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                  ),
                  onPressed: _exportarTxt,
                  icon: const Icon(Icons.save),
                  label: const Text('Exportar a TXT'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Text(
              "Directorio Base: $directorioBase",
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const Divider(),
          Expanded(
            child: vistaActual == "archivos"
                ? _construirListaArchivos()
                : _construirListaCarpetas(),
          ),
        ],
      ),
    );
  }

  Widget _construirListaCarpetas() {
    return ListView.builder(
      itemCount: carpetasFiltradas.length,
      itemBuilder: (context, index) {
        final carpeta = carpetasFiltradas[index];
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: Key('${carpeta.rutaCompleta}_$expandirTodo'),
            initiallyExpanded: expandirTodo,
            leading: const Icon(Icons.folder, color: Colors.amber),
            title: Text(
              carpeta.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_formatearTamano(carpeta.tamanoBytes)),
            children: carpeta.archivos.map((archivo) {
              return ListTile(
                contentPadding: const EdgeInsets.only(left: 40, right: 16),
                leading: const Icon(
                  Icons.insert_drive_file,
                  color: Colors.blueGrey,
                ),
                title: Text(archivo.nombre),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      archivo.tipo.toUpperCase(),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    Text(_formatearTamano(archivo.tamanoBytes)),
                  ],
                ),
                onTap: () {},
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _construirListaArchivos() {
    return ListView.builder(
      itemCount: archivosFiltrados.length,
      itemBuilder: (context, index) {
        final archivo = archivosFiltrados[index];
        return ListTile(
          leading: const Icon(Icons.insert_drive_file, color: Colors.blueGrey),
          title: Text(archivo.nombre),
          subtitle: Text(
            archivo.rutaCompleta,
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                archivo.tipo.toUpperCase(),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 16),
              Text(
                _formatearTamano(archivo.tamanoBytes),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}
