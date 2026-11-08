import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/carpeta_modelo.dart';
import '../models/archivo_modelo.dart';
import '../services/escaner_service.dart';
import '../services/renombrar_service.dart';
import '../services/mkv_service.dart';
import '../utils/dialogos_helper.dart';
import '../widgets/panel_acciones.dart';

class GestorPrincipal extends StatefulWidget {
  const GestorPrincipal({super.key});

  @override
  State<GestorPrincipal> createState() => _GestorPrincipalState();
}

class _GestorPrincipalState extends State<GestorPrincipal> {
  String directorioBase = r"D:\Videos";

  List<CarpetaModelo> datosCarpetas = [];
  List<CarpetaModelo> carpetasFiltradas = [];
  List<ArchivoModelo> todosLosArchivos = [];
  List<ArchivoModelo> archivosFiltrados = [];

  TextEditingController searchController = TextEditingController();
  bool expandirTodo = false, modoSeleccion = false;
  String vistaActual = "agrupada";

  List<ArchivoModelo> get archivosSeleccionados =>
      todosLosArchivos.where((a) => a.seleccionado).toList();

  @override
  void initState() {
    super.initState();
    _cargarArchivos();
    searchController.addListener(_actualizarVista);
  }

  void _cargarArchivos() {
    var resultado = EscanerService.escanear(directorioBase);
    setState(() {
      datosCarpetas = resultado.carpetas;
      todosLosArchivos = resultado.archivos;
      _actualizarVista();
    });
  }

  void _mostrarNotificacion(String mensaje, {bool esError = false}) {
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

  // --- CONTROL DE UI ---
  void _manejarSeleccion(ArchivoModelo archivo, bool valor) {
    if (valor &&
        vistaActual != "archivos" &&
        archivosSeleccionados.isNotEmpty) {
      if (File(archivosSeleccionados.first.rutaCompleta).parent.path !=
          File(archivo.rutaCompleta).parent.path) {
        for (var a in archivosSeleccionados) {
          a.seleccionado = false;
        }
        _mostrarNotificacion(
          'Se desmarcaron archivos de otra carpeta para evitar conflictos.',
          esError: true,
        );
      }
    }
    setState(() => archivo.seleccionado = valor);
  }

  void _marcarTodos(bool val) => setState(() {
    for (var a in archivosFiltrados) {
      a.seleccionado = val;
    }
  });

  void _seleccionarIntervalo() {
    if (archivosSeleccionados.length < 2) return;
    setState(() {
      List<ArchivoModelo> listaBase = vistaActual == "archivos"
          ? archivosFiltrados
          : carpetasFiltradas
                .firstWhere(
                  (c) =>
                      c.rutaCompleta ==
                      File(
                        archivosSeleccionados.first.rutaCompleta,
                      ).parent.path,
                )
                .archivos;

      List<int> indices = [];
      for (int i = 0; i < listaBase.length; i++) {
        if (listaBase[i].seleccionado) indices.add(i);
      }
      if (indices.isNotEmpty) {
        for (int i = indices.reduce(min); i <= indices.reduce(max); i++) {
          listaBase[i].seleccionado = true;
        }
      }
    });
  }

  void _actualizarVista() {
    String q = searchController.text.toLowerCase();
    setState(() {
      if (vistaActual == "archivos") {
        archivosFiltrados = List.from(todosLosArchivos)
          ..retainWhere((a) => a.nombre.toLowerCase().contains(q))
          ..sort((a, b) => b.tamanoBytes.compareTo(a.tamanoBytes));
      } else {
        List<CarpetaModelo> base = List.from(datosCarpetas)
          ..sort(
            (a, b) => vistaActual == "agrupada"
                ? a.rutaCompleta.compareTo(b.rutaCompleta)
                : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
          );
        if (q.isEmpty) {
          carpetasFiltradas = base;
        } else {
          carpetasFiltradas = [];
          for (var c in base) {
            bool cCoin = c.nombre.toLowerCase().contains(q);
            var aCoin = c.archivos
                .where((a) => a.nombre.toLowerCase().contains(q))
                .toList();
            if (cCoin) {
              carpetasFiltradas.add(c);
            } else if (aCoin.isNotEmpty) {
              carpetasFiltradas.add(
                CarpetaModelo(
                  rutaCompleta: c.rutaCompleta,
                  nombre: c.nombre,
                  tamanoBytes: c.tamanoBytes,
                  archivos: aCoin,
                  iconoPath: c.iconoPath,
                ),
              );
            }
          }
          expandirTodo = true;
        }
      }
    });
  }

  // --- LLAMADAS A SERVICIOS ---
  void _ejecutarRenombrado(int Function(List<ArchivoModelo>) accion) {
    try {
      int procesados = accion(archivosSeleccionados);
      _cargarArchivos();
      _mostrarNotificacion('Éxito: $procesados archivos renombrados.');
    } catch (e) {
      _mostrarNotificacion('Error: $e', esError: true);
    }
  }

  void _ejecutarRenombradoUI(bool secuencial) {
    DialogosHelper.mostrarDialogoRenombrar(context, secuencial, (
      nombre,
      inicio,
    ) {
      _ejecutarRenombrado(
        (lista) => secuencial
            ? RenombrarService.renombrarSecuencial(lista, nombre, inicio)
            : RenombrarService.renombrarMantieneNumero(lista, nombre),
      );
    });
  }

  void _modificarTitulo(bool limpiar) async {
    if (!MkvService.verificarHerramientas()) {
      return _mostrarNotificacion(
        'Error: Herramientas MKV no encontradas.',
        esError: true,
      );
    }
    int p = await MkvService.modificarMetadatoTitulo(
      archivosSeleccionados,
      limpiar,
    );
    if (mounted) _mostrarNotificacion('Títulos actualizados en $p archivos.');
  }

  void _limpiarSubs() {
    DialogosHelper.mostrarDialogoLimpiarSubtitulos(context, (texto) async {
      if (!MkvService.verificarHerramientas())
        return _mostrarNotificacion(
          'Error en herramientas MKV.',
          esError: true,
        );
      _mostrarNotificacion('Procesando limpieza, espera...');
      var res = await MkvService.procesarLimpiezaSubtitulos(
        archivos: archivosSeleccionados,
        textoBuscado: texto,
        onConfirmar: (n, ls) =>
            DialogosHelper.mostrarConfirmacionSubs(context, n, ls),
      );
      _cargarArchivos();
      if (mounted)
        _mostrarNotificacion(
          'Terminado: ${res['procesados']} procesados, ${res['omitidos']} omitidos. ${res['lineas']} líneas borradas.',
        );
    });
  }

  void _gestionarPistas() async {
    if (!MkvService.verificarHerramientas())
      return _mostrarNotificacion('Error en herramientas MKV.', esError: true);
    var base = archivosSeleccionados.firstWhere((a) => a.tipo == 'mkv');
    var info = await MkvService.obtenerPistas(base.rutaCompleta);
    if (info == null)
      return _mostrarNotificacion('Error analizando MKV.', esError: true);

    List<dynamic> audios = [], subs = [];
    for (var track in info['tracks']) {
      if (track['type'] == 'audio') audios.add(track);
      if (track['type'] == 'subtitles') subs.add(track);
    }

    List<int> delAudio = [], delSubs = [];
    bool? proceder = await DialogosHelper.mostrarDialogoGestionarPistas(
      context,
      audios,
      subs,
      delAudio,
      delSubs,
      archivosSeleccionados.length > 1,
    );

    if (proceder == true) {
      _mostrarNotificacion('Remuxing, tomará unos segundos...');
      int p = await MkvService.eliminarPistas(
        archivosSeleccionados,
        delAudio,
        delSubs,
      );
      _cargarArchivos();
      if (mounted) _mostrarNotificacion('Pistas eliminadas de $p videos.');
    }
  }

  String _formato(int b) => b < 1024
      ? "$b B"
      : b < 1048576
      ? "${(b / 1024).toStringAsFixed(2)} KB"
      : b < 1073741824
      ? "${(b / 1048576).toStringAsFixed(2)} MB"
      : "${(b / 1073741824).toStringAsFixed(2)} GB";
  int _prof(String r) => r.length <= directorioBase.length
      ? 0
      : r
            .substring(directorioBase.length)
            .replaceAll(RegExp('^\\\\'), '')
            .split(Platform.pathSeparator)
            .length;

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
            onPressed: () =>
                themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark,
          ),
          TextButton.icon(
            onPressed: () => setState(() {
              modoSeleccion = !modoSeleccion;
              if (!modoSeleccion) _marcarTodos(false);
            }),
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
                  onPressed: () => setState(() {
                    vistaActual = "agrupada";
                    _actualizarVista();
                  }),
                  icon: const Icon(Icons.folder_copy),
                  label: const Text('Jerarquía'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vistaActual == "ordenada"
                        ? (isDark
                              ? Colors.amber.shade900
                              : Colors.yellow.shade100)
                        : null,
                  ),
                  onPressed: () => setState(() {
                    vistaActual = "ordenada";
                    _actualizarVista();
                  }),
                  icon: const Icon(Icons.sort_by_alpha),
                  label: const Text('Nombres'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vistaActual == "archivos"
                        ? (isDark
                              ? Colors.deepOrange.shade900
                              : Colors.deepOrange.shade100)
                        : null,
                  ),
                  onPressed: () => setState(() {
                    vistaActual = "archivos";
                    _actualizarVista();
                  }),
                  icon: const Icon(Icons.balance),
                  label: const Text('Lista Plana'),
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

          if (modoSeleccion && haySeleccion)
            PanelAcciones(
              seleccionados: archivosSeleccionados.length,
              isDark: isDark,
              onDesmarcarTodo: () => _marcarTodos(false),
              onSeleccionarIntervalo: _seleccionarIntervalo,
              onGestionarPistas: _gestionarPistas,
              onLimpiarSubs: _limpiarSubs,
              onBorrarTitulo: () => _modificarTitulo(true),
              onIgualarTitulo: () => _modificarTitulo(false),
              onQuitarSufijo: () =>
                  _ejecutarRenombrado(RenombrarService.quitarSufijoCopia),
              onDialogoRenombrar: () => _ejecutarRenombradoUI(false),
              onDialogoSecuencia: () => _ejecutarRenombradoUI(true),
            ),

          const Divider(),
          Expanded(
            child: vistaActual == "archivos"
                ? _buildArchivos()
                : _buildCarpetas(),
          ),
        ],
      ),
    );
  }

  Widget _buildCarpetas() => ListView.builder(
    itemCount: carpetasFiltradas.length,
    itemBuilder: (context, index) {
      final carpeta = carpetasFiltradas[index];
      int prof = vistaActual == "agrupada" ? _prof(carpeta.rutaCompleta) : 0;
      return Container(
        margin: EdgeInsets.only(left: prof * 24.0),
        decoration: prof > 0
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
                if (prof > 0)
                  const Icon(
                    Icons.subdirectory_arrow_right,
                    color: Colors.grey,
                    size: 16,
                  ),
                if (prof > 0) const SizedBox(width: 4),
                carpeta.iconoPath != null
                    ? Image.file(
                        File(carpeta.iconoPath!),
                        width: 24,
                        height: 24,
                      )
                    : const Icon(Icons.folder, color: Colors.amber),
              ],
            ),
            title: Text(
              carpeta.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_formato(carpeta.tamanoBytes)),
            children: carpeta.archivos
                .map(
                  (archivo) => ListTile(
                    contentPadding: const EdgeInsets.only(left: 40, right: 16),
                    leading: modoSeleccion
                        ? Checkbox(
                            value: archivo.seleccionado,
                            onChanged: (v) =>
                                _manejarSeleccion(archivo, v ?? false),
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
                        Text(_formato(archivo.tamanoBytes)),
                      ],
                    ),
                    onTap: modoSeleccion
                        ? () =>
                              _manejarSeleccion(archivo, !archivo.seleccionado)
                        : null,
                  ),
                )
                .toList(),
          ),
        ),
      );
    },
  );

  Widget _buildArchivos() => ListView.builder(
    itemCount: archivosFiltrados.length,
    itemBuilder: (context, index) {
      final a = archivosFiltrados[index];
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: modoSeleccion
            ? Checkbox(
                value: a.seleccionado,
                onChanged: (v) => _manejarSeleccion(a, v ?? false),
              )
            : const Icon(Icons.insert_drive_file, color: Colors.blueGrey),
        title: Text(a.nombre),
        subtitle: Text(
          "${_formato(a.tamanoBytes)} - ${a.rutaCompleta}",
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Text(
          a.tipo.toUpperCase(),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        onTap: modoSeleccion
            ? () => _manejarSeleccion(a, !a.seleccionado)
            : null,
      );
    },
  );
}
