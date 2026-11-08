import 'dart:io';
import 'dart:convert';
import '../models/archivo_modelo.dart';

class MkvService {
  // Ajusta las rutas aquí si es necesario
  static const String mkvpropedit =
      r"C:\Program Files\MKVToolNix\mkvpropedit.exe";
  static const String mkvmerge = r"C:\Program Files\MKVToolNix\mkvmerge.exe";
  static const String mkvextract =
      r"C:\Program Files\MKVToolNix\mkvextract.exe";

  static bool verificarHerramientas() {
    return File(mkvmerge).existsSync() &&
        File(mkvextract).existsSync() &&
        File(mkvpropedit).existsSync();
  }

  static Future<int> modificarMetadatoTitulo(
    List<ArchivoModelo> archivos,
    bool limpiar,
  ) async {
    int procesados = 0;
    for (var archivo in archivos.where((a) => a.tipo == 'mkv')) {
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
      var result = await Process.run(mkvpropedit, args);
      if (result.exitCode == 0 || result.exitCode == 1) procesados++;
    }
    return procesados;
  }

  static Future<Map<String, dynamic>?> obtenerPistas(String rutaArchivo) async {
    var result = await Process.run(mkvmerge, ['-J', rutaArchivo]);
    if (result.exitCode == 0) return jsonDecode(result.stdout);
    return null;
  }

  static Future<int> eliminarPistas(
    List<ArchivoModelo> archivos,
    List<int> audioIdx,
    List<int> subsIdx,
  ) async {
    int procesados = 0;
    for (var archivo in archivos.where((a) => a.tipo == 'mkv')) {
      String rutaNueva = archivo.rutaCompleta.replaceAll('.mkv', '_TEMP.mkv');
      List<String> args = ['-o', rutaNueva];
      if (audioIdx.isNotEmpty) {
        args.addAll(['--audio-tracks', '!${audioIdx.join(',')}']);
      }
      if (subsIdx.isNotEmpty) {
        args.addAll(['--subtitle-tracks', '!${subsIdx.join(',')}']);
      }
      args.add(archivo.rutaCompleta);

      var mergeResult = await Process.run(mkvmerge, args);
      if (mergeResult.exitCode == 0 || mergeResult.exitCode == 1) {
        File(archivo.rutaCompleta).deleteSync();
        File(rutaNueva).renameSync(archivo.rutaCompleta);
        procesados++;
      } else {
        if (File(rutaNueva).existsSync()) File(rutaNueva).deleteSync();
      }
    }
    return procesados;
  }

  // Desacoplado de la UI, delega la confirmación visual usando onConfirmar
  static Future<Map<String, int>> procesarLimpiezaSubtitulos({
    required List<ArchivoModelo> archivos,
    required String textoBuscado,
    required Future<String?> Function(String, List<String>) onConfirmar,
  }) async {
    int procesados = 0, omitidos = 0, lineasBorradasTotales = 0;
    bool aplicarATodos = false, cancelarProceso = false;

    for (var archivo in archivos.where((a) => a.tipo == 'mkv')) {
      if (cancelarProceso) break;

      var info = await obtenerPistas(archivo.rutaCompleta);
      if (info == null) continue;

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
      List<String> nuevosAss = [],
          argsExtract = ['tracks', archivo.rutaCompleta];
      for (int id in tracksAss) {
        String pathAss =
            '$tempDir\\sub_${id}_${DateTime.now().millisecondsSinceEpoch}.ass';
        argsExtract.add('$id:$pathAss');
        nuevosAss.add(pathAss);
      }
      await Process.run(mkvextract, argsExtract);

      List<String> lineasBorradas = [];
      bool tieneCambios = false;

      for (String pathAss in nuevosAss) {
        File fileAss = File(pathAss);
        if (await fileAss.exists()) {
          List<String> lineas = await fileAss.readAsLines();
          List<String> limpias = [];
          for (var linea in lineas) {
            if (linea.toLowerCase().contains(textoBuscado.toLowerCase())) {
              lineasBorradas.add(linea);
              tieneCambios = true;
            } else {
              limpias.add(linea);
            }
          }
          await fileAss.writeAsString(limpias.join('\n'));
        }
      }

      if (!tieneCambios) {
        for (String p in nuevosAss) {
          if (File(p).existsSync()) File(p).deleteSync();
        }
        omitidos++;
        continue;
      }

      if (!aplicarATodos) {
        String? accion = await onConfirmar(archivo.nombre, lineasBorradas);
        if (accion == 'cancelar') {
          cancelarProceso = true;
          for (String p in nuevosAss) {
            if (File(p).existsSync()) File(p).deleteSync();
          }
          break;
        }
        if (accion == 'omitir') {
          omitidos++;
          for (String p in nuevosAss) {
            if (File(p).existsSync()) File(p).deleteSync();
          }
          continue;
        }
        if (accion == 'todos') aplicarATodos = true;
      }

      lineasBorradasTotales += lineasBorradas.length;
      String rutaNueva = archivo.rutaCompleta.replaceAll('.mkv', '_TEMP.mkv');
      List<String> argsMerge = [
        '-o',
        rutaNueva,
        '--subtitle-tracks',
        '!${tracksAss.join(',')}',
      ];
      argsMerge.addAll([archivo.rutaCompleta, ...nuevosAss]);

      var mergeResult = await Process.run(mkvmerge, argsMerge);
      if (mergeResult.exitCode == 0 || mergeResult.exitCode == 1) {
        File(archivo.rutaCompleta).deleteSync();
        File(rutaNueva).renameSync(archivo.rutaCompleta);
        procesados++;
      }
      for (String p in nuevosAss) {
        if (File(p).existsSync()) File(p).deleteSync();
      }
    }
    return {
      'procesados': procesados,
      'omitidos': omitidos,
      'lineas': lineasBorradasTotales,
    };
  }
}
