import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/carpeta_modelo.dart';
import '../models/archivo_modelo.dart';

class GestorPrincipal extends StatefulWidget {
  const GestorPrincipal({super.key});

  @override
  State<GestorPrincipal> createState() => _GestorPrincipalState();
}

class _GestorPrincipalState extends State<GestorPrincipal> {
  // ATENCIÓN: Asegúrate de mantener la ruta a tu carpeta real
  String directorioBase = r"D:\Videos";

  List<CarpetaModelo> datosCarpetas = [];
  List<CarpetaModelo> carpetasFiltradas = [];
  List<ArchivoModelo> todosLosArchivos = [];
  List<ArchivoModelo> archivosFiltrados = [];

  TextEditingController searchController = TextEditingController();

  // 1. Carpetas contraídas por defecto
  bool expandirTodo = false;
  String vistaActual = "agrupada";

  // 2. Control del modo de selección
  bool modoSeleccion = false;

  List<ArchivoModelo> get archivosSeleccionados =>
      todosLosArchivos.where((a) => a.seleccionado).toList();

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

    // 3. Filtro de extensiones permitidas
    const List<String> extensionesValidas = ['mp4', 'mov', 'mkv', 'avi', 'ico'];

    List<FileSystemEntity> entidades = dir.listSync(recursive: true);
    Map<String, List<ArchivoModelo>> agrupacion = {};

    for (var entidad in entidades) {
      if (entidad is File) {
        String nombre = entidad.path.split(Platform.pathSeparator).last;
        String ext = nombre.contains('.')
            ? nombre.split('.').last.toLowerCase()
            : '';

        // Ignorar el archivo si no tiene una extensión de la lista
        if (!extensionesValidas.contains(ext)) continue;

        String parentPath = entidad.parent.path;
        int tamano = entidad.lengthSync();

        ArchivoModelo archivo = ArchivoModelo(
          nombre: nombre,
          rutaCompleta: entidad.path,
          tamanoBytes: tamano,
          tipo: ext,
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

  // --- LÓGICA DE RESTRICCIÓN DE SELECCIÓN ---

  void _manejarSeleccion(ArchivoModelo archivo, bool valor) {
    if (valor && vistaActual != "archivos") {
      String nuevaRutaPadre = File(archivo.rutaCompleta).parent.path;

      if (archivosSeleccionados.isNotEmpty) {
        String rutaPadreActual = File(
          archivosSeleccionados.first.rutaCompleta,
        ).parent.path;

        // Si el archivo pertenece a otra carpeta, desmarcamos los anteriores
        if (rutaPadreActual != nuevaRutaPadre) {
          for (var a in archivosSeleccionados) {
            a.seleccionado = false;
          }
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se desmarcaron los archivos de la otra carpeta.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
    setState(() {
      archivo.seleccionado = valor;
    });
  }

  void _alternarModoSeleccion() {
    setState(() {
      modoSeleccion = !modoSeleccion;
      if (!modoSeleccion) {
        // Al apagar el modo de selección, desmarcar todo automáticamente
        for (var a in todosLosArchivos) {
          a.seleccionado = false;
        }
      }
    });
  }

  void _marcarTodos(bool seleccionar) {
    setState(() {
      for (var archivo in archivosFiltrados) {
        archivo.seleccionado = seleccionar;
      }
    });
  }

  // --- VISTAS Y FILTROS ---

  void _actualizarVista() {
    if (vistaActual == "agrupada")
      _vistaAgrupadaNormal();
    else if (vistaActual == "ordenada")
      _vistaOrdenadaNombre();
    else if (vistaActual == "archivos")
      _vistaArchivosPorTamano();
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

  // --- LÓGICAS DE RENOMBRADO ---
  void _procesarRenombrado(Function(ArchivoModelo, String, String) logica) {
    try {
      int renombrados = 0;
      for (var archivo in archivosSeleccionados) {
        int lastDot = archivo.nombre.lastIndexOf('.');
        String nombreBase = lastDot != -1
            ? archivo.nombre.substring(0, lastDot)
            : archivo.nombre;
        String ext = lastDot != -1 ? archivo.nombre.substring(lastDot) : '';

        String nuevoNombre = logica(archivo, nombreBase, ext);

        if (nuevoNombre != archivo.nombre && nuevoNombre.isNotEmpty) {
          String nuevaRuta =
              "${File(archivo.rutaCompleta).parent.path}${Platform.pathSeparator}$nuevoNombre";
          File(archivo.rutaCompleta).renameSync(nuevaRuta);
          renombrados++;
        }
      }
      _escanearDirectorio();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$renombrados archivos renombrados con éxito')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al renombrar: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
  }

  void _quitarSufijoCopia() {
    _procesarRenombrado((archivo, nombreBase, ext) {
      String nuevoBase = nombreBase.replaceAll(RegExp(r'\s\(\d+\)$'), '');
      return "$nuevoBase$ext";
    });
  }

  void _renombrarMantieneNumero(String nombreDeseado) {
    _procesarRenombrado((archivo, nombreBase, ext) {
      Match? match = RegExp(r'(\d+)$').firstMatch(nombreBase.trim());
      if (match != null) {
        String numero = match.group(1)!;
        return "$nombreDeseado $numero$ext";
      }
      return "";
    });
  }

  void _renombrarSecuencial(String nombreDeseado, String inicioStr) {
    int length = inicioStr.length;
    int contador = int.tryParse(inicioStr) ?? 1;

    _procesarRenombrado((archivo, nombreBase, ext) {
      String numeroStr = contador.toString().padLeft(length, '0');
      contador++;
      return "$nombreDeseado $numeroStr$ext";
    });
  }

  void _dialogoRenombrar(bool secuencial) {
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
                  labelText: 'Número de inicio (ej. 1, 01, 001)',
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
              if (nombreCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              if (secuencial) {
                _renombrarSecuencial(
                  nombreCtrl.text.trim(),
                  numCtrl.text.trim(),
                );
              } else {
                _renombrarMantieneNumero(nombreCtrl.text.trim());
              }
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  // --- INTERFAZ UI ---
  String _formatearTamano(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1048576) return "${(bytes / 1024).toStringAsFixed(2)} KB";
    if (bytes < 1073741824) return "${(bytes / 1048576).toStringAsFixed(2)} MB";
    return "${(bytes / 1073741824).toStringAsFixed(2)} GB";
  }

  @override
  Widget build(BuildContext context) {
    bool haySeleccion = archivosSeleccionados.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestor Avanzado de Archivos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Botón principal para Activar/Desactivar selección
          TextButton.icon(
            onPressed: _alternarModoSeleccion,
            icon: Icon(
              modoSeleccion ? Icons.cancel : Icons.checklist,
              color: Colors.black87,
            ),
            label: Text(
              modoSeleccion ? "Cancelar Selección" : "Seleccionar",
              style: const TextStyle(color: Colors.black87),
            ),
          ),
          // Botón "Marcar todo" (Solo disponible en la vista de lista plana y modo selección activo)
          if (modoSeleccion && vistaActual == "archivos")
            TextButton.icon(
              onPressed: () => _marcarTodos(!haySeleccion),
              icon: Icon(
                haySeleccion ? Icons.deselect : Icons.select_all,
                color: Colors.black87,
              ),
              label: Text(
                haySeleccion ? "Desmarcar" : "Marcar Todo",
                style: const TextStyle(color: Colors.black87),
              ),
            ),
        ],
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
                  label: const Text('Carpetas por Nombre'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vistaActual == "archivos"
                        ? Colors.deepOrange.shade100
                        : null,
                  ),
                  onPressed: _vistaArchivosPorTamano,
                  icon: const Icon(Icons.balance),
                  label: const Text('Lista Plana por Tamaño'),
                ),
              ],
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
      bottomNavigationBar: (modoSeleccion && haySeleccion)
          ? BottomAppBar(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      '${archivosSeleccionados.length} selecc.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton(
                      onPressed: _quitarSufijoCopia,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                      ),
                      child: const Text('Quitar " (1)"'),
                    ),
                    ElevatedButton(
                      onPressed: () => _dialogoRenombrar(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade100,
                      ),
                      child: const Text('Renombrar (Conserva N°)'),
                    ),
                    ElevatedButton(
                      onPressed: () => _dialogoRenombrar(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                      ),
                      child: const Text('Renombrar Secuencia'),
                    ),
                  ],
                ),
              ),
            )
          : null,
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
                // Solo renderiza el checkbox si el modo selección está activo
                leading: modoSeleccion
                    ? Checkbox(
                        value: archivo.seleccionado,
                        onChanged: (val) =>
                            _manejarSeleccion(archivo, val ?? false),
                      )
                    : const Icon(
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
                // Permite tocar toda la fila para marcar si estamos en modo selección
                onTap: modoSeleccion
                    ? () => _manejarSeleccion(archivo, !archivo.seleccionado)
                    : null,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: modoSeleccion
              ? Checkbox(
                  value: archivo.seleccionado,
                  onChanged: (val) => _manejarSeleccion(archivo, val ?? false),
                )
              : const Icon(Icons.insert_drive_file, color: Colors.blueGrey),
          title: Text(archivo.nombre),
          subtitle: Text(
            "${_formatearTamano(archivo.tamanoBytes)} - ${archivo.rutaCompleta}",
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Text(
            archivo.tipo.toUpperCase(),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          onTap: modoSeleccion
              ? () => _manejarSeleccion(archivo, !archivo.seleccionado)
              : null,
        );
      },
    );
  }
}
