import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
//import 'package:intl/intl.dart';

import '../models/carpeta_modelo.dart';
import '../models/archivo_modelo.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

class GestorPrincipal extends StatefulWidget {
  const GestorPrincipal({super.key});

  @override
  State<GestorPrincipal> createState() => _GestorPrincipalState();
}

class _GestorPrincipalState extends State<GestorPrincipal> {
  // ATENCIÓN: Asegúrate de mantener la ruta a tu carpeta real
  String directorioBase = r"D:\Videos";

  String rutaMkvpropedit = r"C:\Program Files\MKVToolNix\mkvpropedit.exe";
  String rutaMkvmerge = r"C:\Program Files\MKVToolNix\mkvmerge.exe";
  String rutaMkvextract = r"C:\Program Files\MKVToolNix\mkvextract.exe";

  List<CarpetaModelo> datosCarpetas = [];
  List<CarpetaModelo> carpetasFiltradas = [];
  List<ArchivoModelo> todosLosArchivos = [];
  List<ArchivoModelo> archivosFiltrados = [];

  TextEditingController searchController = TextEditingController();

  bool expandirTodo = false;
  String vistaActual = "agrupada";
  bool modoSeleccion = false;

  List<ArchivoModelo> get archivosSeleccionados =>
      todosLosArchivos.where((a) => a.seleccionado).toList();

  @override
  void initState() {
    super.initState();
    _escanearDirectorio();
    searchController.addListener(_actualizarVista);
  }

  void _mostrarNotificacionArriba(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    final double alturaPantalla = MediaQuery.of(context).size.height;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: esError ? Colors.red.shade800 : Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.only(
          bottom: alturaPantalla - 120,
          left: 20,
          right: 20,
        ),
        dismissDirection: DismissDirection.up,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _escanearDirectorio() {
    final dir = Directory(directorioBase);
    if (!dir.existsSync()) return;

    List<CarpetaModelo> carpetasTemp = [];
    List<ArchivoModelo> archivosTemp = [];

    const List<String> extensionesValidas = ['mp4', 'mov', 'mkv', 'avi', 'ico'];
    List<FileSystemEntity> entidades = dir.listSync(recursive: true);
    Map<String, List<ArchivoModelo>> agrupacion = {};

    for (var entidad in entidades) {
      if (entidad is File) {
        String nombre = entidad.path.split(Platform.pathSeparator).last;
        String ext = nombre.contains('.')
            ? nombre.split('.').last.toLowerCase()
            : '';

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
      String? icono;
      try {
        icono = archivos.firstWhere((a) => a.tipo == 'ico').rutaCompleta;
      } catch (e) {
        icono = null;
      }

      carpetasTemp.add(
        CarpetaModelo(
          rutaCompleta: ruta,
          nombre: ruta == directorioBase
              ? "RAIZ"
              : ruta.split(Platform.pathSeparator).last,
          tamanoBytes: tamanoTotal,
          archivos: archivos,
          iconoPath: icono,
        ),
      );
    });

    datosCarpetas = carpetasTemp;
    todosLosArchivos = archivosTemp;
    _actualizarVista();
  }

  int _calcularProfundidad(String ruta) {
    if (ruta.length <= directorioBase.length) return 0;
    String relativa = ruta.substring(directorioBase.length);
    if (relativa.startsWith(Platform.pathSeparator))
      relativa = relativa.substring(1);
    return relativa.isEmpty ? 0 : relativa.split(Platform.pathSeparator).length;
  }

  void _manejarSeleccion(ArchivoModelo archivo, bool valor) {
    if (valor && vistaActual != "archivos") {
      String nuevaRutaPadre = File(archivo.rutaCompleta).parent.path;
      if (archivosSeleccionados.isNotEmpty) {
        String rutaPadreActual = File(
          archivosSeleccionados.first.rutaCompleta,
        ).parent.path;
        if (rutaPadreActual != nuevaRutaPadre) {
          for (var a in archivosSeleccionados) a.seleccionado = false;
          _mostrarNotificacionArriba(
            'Se desmarcaron los archivos de la otra carpeta para evitar conflictos.',
            esError: true,
          );
        }
      }
    }
    setState(() => archivo.seleccionado = valor);
  }

  void _seleccionarIntervalo() {
    if (archivosSeleccionados.length < 2) return;
    setState(() {
      if (vistaActual == "archivos") {
        List<int> indices = [];
        for (int i = 0; i < archivosFiltrados.length; i++) {
          if (archivosFiltrados[i].seleccionado) indices.add(i);
        }
        if (indices.isNotEmpty) {
          int minIdx = indices.reduce(min);
          int maxIdx = indices.reduce(max);
          for (int i = minIdx; i <= maxIdx; i++)
            archivosFiltrados[i].seleccionado = true;
        }
      } else {
        String rutaPadre = File(
          archivosSeleccionados.first.rutaCompleta,
        ).parent.path;
        CarpetaModelo? carpetaActiva;
        try {
          carpetaActiva = carpetasFiltradas.firstWhere(
            (c) => c.rutaCompleta == rutaPadre,
          );
        } catch (e) {
          carpetaActiva = null;
        }

        if (carpetaActiva != null) {
          List<int> indices = [];
          for (int i = 0; i < carpetaActiva.archivos.length; i++) {
            if (carpetaActiva.archivos[i].seleccionado) indices.add(i);
          }
          if (indices.isNotEmpty) {
            int minIdx = indices.reduce(min);
            int maxIdx = indices.reduce(max);
            for (int i = minIdx; i <= maxIdx; i++)
              carpetaActiva.archivos[i].seleccionado = true;
          }
        }
      }
    });
  }

  void _alternarModoSeleccion() {
    setState(() {
      modoSeleccion = !modoSeleccion;
      if (!modoSeleccion)
        for (var a in todosLosArchivos) a.seleccionado = false;
    });
  }

  void _marcarTodos(bool seleccionar) {
    setState(() {
      for (var archivo in archivosFiltrados) archivo.seleccionado = seleccionar;
    });
  }

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
      setState(() => carpetasFiltradas = List.from(base));
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
    setState(() {
      carpetasFiltradas = filtrado;
      expandirTodo = true;
    });
  }

  void _vistaAgrupadaNormal() {
    vistaActual = "agrupada";
    List<CarpetaModelo> ordenados = List.from(datosCarpetas);
    ordenados.sort((a, b) => a.rutaCompleta.compareTo(b.rutaCompleta));
    _aplicarFiltroCarpetas(ordenados);
  }

  void _vistaOrdenadaNombre() {
    vistaActual = "ordenada";
    List<CarpetaModelo> ordenados = List.from(datosCarpetas);
    ordenados.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    _aplicarFiltroCarpetas(ordenados);
  }

  void _vistaArchivosPorTamano() {
    vistaActual = "archivos";
    String query = searchController.text.toLowerCase();
    List<ArchivoModelo> filtrados = query.isEmpty
        ? List.from(todosLosArchivos)
        : todosLosArchivos
              .where((a) => a.nombre.toLowerCase().contains(query))
              .toList();
    filtrados.sort((a, b) => b.tamanoBytes.compareTo(a.tamanoBytes));
    setState(() => archivosFiltrados = filtrados);
  }

  // --- RENOMBRADO ---
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
      _mostrarNotificacionArriba(
        'Éxito: $renombrados archivos han sido renombrados.',
      );
    } catch (e) {
      _mostrarNotificacionArriba('Error al renombrar: $e', esError: true);
    }
  }

  void _quitarSufijoCopia() {
    _procesarRenombrado((archivo, nombreBase, ext) {
      return "${nombreBase.replaceAll(RegExp(r'\s\(\d+\)$'), '')}$ext";
    });
  }

  void _renombrarMantieneNumero(String nombreDeseado) {
    _procesarRenombrado((archivo, nombreBase, ext) {
      Match? match = RegExp(r'(\d+)$').firstMatch(nombreBase.trim());
      if (match != null) return "$nombreDeseado ${match.group(1)!}$ext";
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

  // --- MKVTOOLNIX: METADATOS TÍTULO ---
  Future<void> _modificarMetadatoTitulo(bool limpiar) async {
    if (!File(rutaMkvpropedit).existsSync()) {
      _mostrarNotificacionArriba(
        'Error: mkvpropedit.exe no encontrado.',
        esError: true,
      );
      return;
    }
    int procesados = 0;
    for (var archivo in archivosSeleccionados) {
      if (archivo.tipo != 'mkv') continue;
      List<String> args = [archivo.rutaCompleta];
      if (limpiar) {
        args.addAll(['--delete', 'title']);
      } else {
        String nombreBase = archivo.nombre.substring(
          0,
          archivo.nombre.lastIndexOf('.'),
        );
        args.addAll(['--edit', 'info', '--set', 'title=$nombreBase']);
      }
      var result = await Process.run(rutaMkvpropedit, args);
      if (result.exitCode == 0 || result.exitCode == 1) procesados++;
    }
    _mostrarNotificacionArriba(
      'Metadatos Título MKV actualizados en $procesados archivos.',
    );
  }

  // --- MKVTOOLNIX: GESTION DE PISTAS (ELIMINAR AUDIO/SUBS) ---
  Future<void> _dialogoGestionarPistas() async {
    if (!File(rutaMkvmerge).existsSync()) {
      _mostrarNotificacionArriba(
        'Error: mkvmerge.exe no encontrado.',
        esError: true,
      );
      return;
    }

    // Usamos el primer archivo MKV como base para leer la estructura de pistas
    ArchivoModelo? archivoBase;
    try {
      archivoBase = archivosSeleccionados.firstWhere((a) => a.tipo == 'mkv');
    } catch (e) {
      _mostrarNotificacionArriba(
        'Debes seleccionar al menos un archivo MKV.',
        esError: true,
      );
      return;
    }

    var resultJ = await Process.run(rutaMkvmerge, [
      '-J',
      archivoBase.rutaCompleta,
    ]);
    if (resultJ.exitCode != 0) {
      _mostrarNotificacionArriba(
        'No se pudo analizar el archivo MKV seleccionado.',
        esError: true,
      );
      return;
    }

    var info = jsonDecode(resultJ.stdout);
    List pistasAudio = [];
    List pistasSubs = [];

    for (var track in info['tracks']) {
      if (track['type'] == 'audio') pistasAudio.add(track);
      if (track['type'] == 'subtitles') pistasSubs.add(track);
    }

    // Mostrar Diálogo con casillas para eliminar pistas
    List<int> tracksAEliminarAudio = [];
    List<int> tracksAEliminarSubs = [];

    bool? proceder = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text('Eliminar Pistas (Audio / Subs)'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (archivosSeleccionados
                              .where((a) => a.tipo == 'mkv')
                              .length >
                          1)
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.orange.withOpacity(0.2),
                          child: const Text(
                            '⚠️ Se aplicará a múltiples videos. Se asume que todos tienen exactamente este mismo orden de pistas.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      const SizedBox(height: 10),

                      const Text(
                        'PISTAS DE AUDIO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Divider(),
                      if (pistasAudio.isEmpty)
                        const Text('No hay pistas de audio.'),
                      ...pistasAudio.map((t) {
                        bool eliminar = tracksAEliminarAudio.contains(t['id']);
                        String lang = t['properties']?['language'] ?? 'und';
                        String name =
                            t['properties']?['track_name'] ?? 'Sin título';
                        return CheckboxListTile(
                          value: eliminar,
                          activeColor: Colors.red.shade700,
                          title: Text(
                            'ID ${t['id']} [$lang] - $name',
                            style: TextStyle(
                              decoration: eliminar
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            'Eliminar pista',
                            style: TextStyle(
                              color: eliminar ? Colors.red : null,
                            ),
                          ),
                          secondary: const Icon(Icons.audiotrack),
                          onChanged: (val) {
                            setStateSB(() {
                              if (val == true)
                                tracksAEliminarAudio.add(t['id']);
                              else
                                tracksAEliminarAudio.remove(t['id']);
                            });
                          },
                        );
                      }),

                      const SizedBox(height: 20),
                      const Text(
                        'SUBTÍTULOS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Divider(),
                      if (pistasSubs.isEmpty)
                        const Text('No hay pistas de subtítulos.'),
                      ...pistasSubs.map((t) {
                        bool eliminar = tracksAEliminarSubs.contains(t['id']);
                        String lang = t['properties']?['language'] ?? 'und';
                        String name =
                            t['properties']?['track_name'] ?? 'Sin título';
                        return CheckboxListTile(
                          value: eliminar,
                          activeColor: Colors.red.shade700,
                          title: Text(
                            'ID ${t['id']} [$lang] - $name',
                            style: TextStyle(
                              decoration: eliminar
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            'Eliminar pista',
                            style: TextStyle(
                              color: eliminar ? Colors.red : null,
                            ),
                          ),
                          secondary: const Icon(Icons.subtitles),
                          onChanged: (val) {
                            setStateSB(() {
                              if (val == true)
                                tracksAEliminarSubs.add(t['id']);
                              else
                                tracksAEliminarSubs.remove(t['id']);
                            });
                          },
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
                      (tracksAEliminarAudio.isEmpty &&
                          tracksAEliminarSubs.isEmpty)
                      ? null
                      : () => Navigator.pop(context, true),
                  child: const Text('Eliminar Pistas Seleccionadas'),
                ),
              ],
            );
          },
        );
      },
    );

    if (proceder != true) return;

    _mostrarNotificacionArriba(
      'Remuxing archivos, esto tomará unos segundos...',
    );
    int procesados = 0;

    for (var archivo in archivosSeleccionados.where((a) => a.tipo == 'mkv')) {
      String rutaNueva = archivo.rutaCompleta.replaceAll('.mkv', '_TEMP.mkv');
      List<String> argsMerge = ['-o', rutaNueva];

      if (tracksAEliminarAudio.isNotEmpty) {
        argsMerge.addAll([
          '--audio-tracks',
          '!${tracksAEliminarAudio.join(',')}',
        ]);
      }
      if (tracksAEliminarSubs.isNotEmpty) {
        argsMerge.addAll([
          '--subtitle-tracks',
          '!${tracksAEliminarSubs.join(',')}',
        ]);
      }
      argsMerge.add(archivo.rutaCompleta);

      var mergeResult = await Process.run(rutaMkvmerge, argsMerge);
      if (mergeResult.exitCode == 0 || mergeResult.exitCode == 1) {
        File(archivo.rutaCompleta).deleteSync();
        File(rutaNueva).renameSync(archivo.rutaCompleta);
        procesados++;
      } else {
        if (File(rutaNueva).existsSync()) File(rutaNueva).deleteSync();
      }
    }
    _escanearDirectorio();
    _mostrarNotificacionArriba(
      'Se eliminaron pistas de $procesados videos correctamente.',
    );
  }

  // --- MKVTOOLNIX: LIMPIEZA DE SUBTÍTULOS (.ASS) ---
  Future<String?> _mostrarDialogoConfirmacionSubs(
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
                'Se encontraron ${lineas.length} líneas basura:',
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
              'Cancelar Proceso',
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'omitir'),
            child: const Text('Omitir este video'),
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
            child: const Text('Eliminar y Aplicar a Todos'),
          ),
        ],
      ),
    );
  }

  Future<void> _procesarLimpiezaSubtitulos(String textoBuscado) async {
    if (!File(rutaMkvmerge).existsSync() ||
        !File(rutaMkvextract).existsSync()) {
      _mostrarNotificacionArriba(
        'Error: mkvmerge o mkvextract no encontrados.',
        esError: true,
      );
      return;
    }

    _mostrarNotificacionArriba(
      'Extrayendo y analizando subtítulos, por favor espera...',
    );

    int procesados = 0;
    int omitidos = 0;
    int lineasBorradasTotales = 0;
    bool aplicarATodos = false;
    bool cancelarProceso = false;

    for (var archivo in archivosSeleccionados) {
      if (cancelarProceso) break;
      if (archivo.tipo != 'mkv') continue;

      var resultJ = await Process.run(rutaMkvmerge, [
        '-J',
        archivo.rutaCompleta,
      ]);
      if (resultJ.exitCode != 0) continue;

      var info = jsonDecode(resultJ.stdout);
      List<int> tracksAss = [];
      for (var track in info['tracks']) {
        if (track['type'] == 'subtitles' &&
            (track['codec'].toString().contains('SubStationAlpha') ||
                track['codec'].toString().contains('ASS'))) {
          tracksAss.add(track['id']);
        }
      }

      if (tracksAss.isEmpty) continue;

      String tempDir = Directory.systemTemp.path;
      List<String> nuevosAss = [];
      List<String> argsExtract = ['tracks', archivo.rutaCompleta];

      for (int id in tracksAss) {
        String pathAss =
            '$tempDir\\sub_${id}_${DateTime.now().millisecondsSinceEpoch}.ass';
        argsExtract.add('$id:$pathAss');
        nuevosAss.add(pathAss);
      }
      await Process.run(rutaMkvextract, argsExtract);

      List<String> todasLasLineasBorradas = [];
      bool tieneCambios = false;

      for (String pathAss in nuevosAss) {
        File fileAss = File(pathAss);
        if (await fileAss.exists()) {
          List<String> lineas = await fileAss.readAsLines();
          List<String> limpias = [];
          for (var linea in lineas) {
            if (linea.toLowerCase().contains(textoBuscado.toLowerCase())) {
              todasLasLineasBorradas.add(linea);
              tieneCambios = true;
            } else {
              limpias.add(linea);
            }
          }
          await fileAss.writeAsString(limpias.join('\n'));
        }
      }

      // Si no hubo lineas encontradas, omite este video y no hace re-empaquetado.
      if (!tieneCambios) {
        for (String pathAss in nuevosAss)
          if (File(pathAss).existsSync()) File(pathAss).deleteSync();
        omitidos++;
        continue;
      }

      // DIÁLOGO DE CONFIRMACIÓN
      if (!aplicarATodos) {
        String? accion = await _mostrarDialogoConfirmacionSubs(
          archivo.nombre,
          todasLasLineasBorradas,
        );
        if (accion == 'cancelar') {
          cancelarProceso = true;
          for (String pathAss in nuevosAss)
            if (File(pathAss).existsSync()) File(pathAss).deleteSync();
          break;
        }
        if (accion == 'omitir') {
          omitidos++;
          for (String pathAss in nuevosAss)
            if (File(pathAss).existsSync()) File(pathAss).deleteSync();
          continue;
        }
        if (accion == 'todos') {
          aplicarATodos = true;
        }
        // Si es 'eliminar', continua el flujo normal.
      }

      // RE-EMPAQUETADO
      lineasBorradasTotales += todasLasLineasBorradas.length;
      String rutaNueva = archivo.rutaCompleta.replaceAll('.mkv', '_TEMP.mkv');
      List<String> argsMerge = ['-o', rutaNueva];
      argsMerge.addAll(['--subtitle-tracks', '!${tracksAss.join(',')}']);
      argsMerge.add(archivo.rutaCompleta);
      argsMerge.addAll(nuevosAss);

      var mergeResult = await Process.run(rutaMkvmerge, argsMerge);

      if (mergeResult.exitCode == 0 || mergeResult.exitCode == 1) {
        File(archivo.rutaCompleta).deleteSync();
        File(rutaNueva).renameSync(archivo.rutaCompleta);
        procesados++;
      }

      for (String pathAss in nuevosAss)
        if (File(pathAss).existsSync()) File(pathAss).deleteSync();
    }

    _escanearDirectorio();
    if (mounted) {
      _mostrarNotificacionArriba(
        'Proceso terminado: $procesados editados, $omitidos sin cambios/omitidos. Se borraron $lineasBorradasTotales líneas basura.',
      );
    }
  }

  void _dialogoLimpiarSubtitulosUI() {
    TextEditingController textoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Subtítulos (.ASS)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Se buscará el siguiente texto en los subtítulos de los MKV:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textoCtrl,
              decoration: const InputDecoration(
                labelText: 'Texto o Link a borrar',
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
              if (textoCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              _procesarLimpiezaSubtitulos(textoCtrl.text.trim());
            },
            child: const Text('Comenzar Búsqueda'),
          ),
        ],
      ),
    );
  }

  // --- INTERFAZ ---
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
                  labelText: 'Número de inicio (ej. 1, 01)',
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
              if (secuencial)
                _renombrarSecuencial(
                  nombreCtrl.text.trim(),
                  numCtrl.text.trim(),
                );
              else
                _renombrarMantieneNumero(nombreCtrl.text.trim());
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  String _formatearTamano(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1048576) return "${(bytes / 1024).toStringAsFixed(2)} KB";
    if (bytes < 1073741824) return "${(bytes / 1048576).toStringAsFixed(2)} MB";
    return "${(bytes / 1073741824).toStringAsFixed(2)} GB";
  }

  @override
  Widget build(BuildContext context) {
    bool haySeleccion = archivosSeleccionados.isNotEmpty;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color iconTextColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestor Avanzado de Archivos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: iconTextColor,
            ),
            tooltip: 'Alternar Tema',
            onPressed: () =>
                themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark,
          ),
          TextButton.icon(
            onPressed: _alternarModoSeleccion,
            icon: Icon(
              modoSeleccion ? Icons.cancel : Icons.checklist,
              color: iconTextColor,
            ),
            label: Text(
              modoSeleccion ? "Salir de Selección" : "Activar Selección",
              style: TextStyle(
                color: iconTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 12.0, right: 12.0),
            child: Text(
              "Directorio Actual: $directorioBase",
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: vistaActual == "archivos"
                      ? null
                      : () => setState(() => expandirTodo = !expandirTodo),
                  icon: Icon(
                    expandirTodo ? Icons.unfold_less : Icons.unfold_more,
                  ),
                  label: Text(expandirTodo ? 'Contraer Todo' : 'Expandir Todo'),
                ),
                SizedBox(
                  width: 350,
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: '🔍 Buscar archivos o carpetas',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ],
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
                        ? (isDark ? Colors.blue.shade900 : Colors.blue.shade100)
                        : null,
                  ),
                  onPressed: () => setState(() => _vistaAgrupadaNormal()),
                  icon: const Icon(Icons.folder_copy),
                  label: const Text('Agrupar por Jerarquía'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vistaActual == "ordenada"
                        ? (isDark
                              ? Colors.amber.shade900
                              : Colors.yellow.shade100)
                        : null,
                  ),
                  onPressed: () => setState(() => _vistaOrdenadaNombre()),
                  icon: const Icon(Icons.sort_by_alpha),
                  label: const Text('Carpetas por Nombre'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vistaActual == "archivos"
                        ? (isDark
                              ? Colors.deepOrange.shade900
                              : Colors.deepOrange.shade100)
                        : null,
                  ),
                  onPressed: () => setState(() => _vistaArchivosPorTamano()),
                  icon: const Icon(Icons.balance),
                  label: const Text('Lista Plana por Tamaño'),
                ),
                if (modoSeleccion && vistaActual == "archivos")
                  ElevatedButton.icon(
                    onPressed: () => _marcarTodos(!haySeleccion),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade300,
                    ),
                    icon: Icon(
                      haySeleccion ? Icons.deselect : Icons.select_all,
                    ),
                    label: Text(
                      haySeleccion ? "Desmarcar Todos" : "Marcar Todos",
                    ),
                  ),
              ],
            ),
          ),

          // PANEL SUPERIOR DE HERRAMIENTAS
          if (modoSeleccion && haySeleccion)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.blueGrey.shade900
                    : Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: isDark
                      ? Colors.blueGrey.shade700
                      : Colors.blueGrey.shade300,
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
                        '${archivosSeleccionados.length} Seleccionados',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _marcarTodos(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.red.shade900
                              : Colors.red.shade100,
                          foregroundColor: isDark
                              ? Colors.white
                              : Colors.red.shade900,
                        ),
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Desmarcar Todo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (archivosSeleccionados.length >= 2) ...[
                          ElevatedButton.icon(
                            onPressed: _seleccionarIntervalo,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.purple.shade900
                                  : Colors.purple.shade100,
                            ),
                            icon: const Icon(
                              Icons.format_line_spacing,
                              size: 18,
                            ),
                            label: const Text('Seleccionar Intervalo'),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // BOTONES MKVTOOLNIX
                        ElevatedButton.icon(
                          onPressed: _dialogoGestionarPistas,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.pink.shade900
                                : Colors.pink.shade100,
                          ),
                          icon: const Icon(Icons.layers_clear, size: 18),
                          label: const Text('Eliminar Pistas (Audio/Subs)'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _dialogoLimpiarSubtitulosUI,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.deepPurple.shade900
                                : Colors.deepPurple.shade100,
                          ),
                          icon: const Icon(Icons.subtitles_off, size: 18),
                          label: const Text('Limpiar Subs (.ASS)'),
                        ),
                        const SizedBox(width: 8),
                        // --- BOTÓN RECUPERADO ---
                        ElevatedButton.icon(
                          onPressed: () => _modificarMetadatoTitulo(true),
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
                          onPressed: () => _modificarMetadatoTitulo(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.teal.shade900
                                : Colors.teal.shade100,
                          ),
                          icon: const Icon(Icons.sync, size: 18),
                          label: const Text('Título = Nombre'),
                        ),
                        const SizedBox(width: 8),

                        // BOTONES RENOMBRADO
                        ElevatedButton(
                          onPressed: _quitarSufijoCopia,
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
                          onPressed: () => _dialogoRenombrar(false),
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
                          onPressed: () => _dialogoRenombrar(true),
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
        int profundidad = vistaActual == "agrupada"
            ? _calcularProfundidad(carpeta.rutaCompleta)
            : 0;
        return Container(
          margin: EdgeInsets.only(left: profundidad * 24.0),
          decoration: profundidad > 0
              ? BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Colors.blueGrey.withOpacity(0.3),
                      width: 2.0,
                    ),
                  ),
                )
              : null,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: Key('${carpeta.rutaCompleta}_$expandirTodo'),
              initiallyExpanded: expandirTodo,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (profundidad > 0)
                    const Icon(
                      Icons.subdirectory_arrow_right,
                      color: Colors.grey,
                      size: 16,
                    ),
                  if (profundidad > 0) const SizedBox(width: 4),
                  carpeta.iconoPath != null
                      ? Image.file(
                          File(carpeta.iconoPath!),
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        )
                      : const Icon(Icons.folder, color: Colors.amber),
                ],
              ),
              title: Text(
                carpeta.nombre,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(_formatearTamano(carpeta.tamanoBytes)),
              children: carpeta.archivos.map((archivo) {
                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 40, right: 16),
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
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(_formatearTamano(archivo.tamanoBytes)),
                    ],
                  ),
                  onTap: modoSeleccion
                      ? () => _manejarSeleccion(archivo, !archivo.seleccionado)
                      : null,
                );
              }).toList(),
            ),
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
