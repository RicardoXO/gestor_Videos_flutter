import 'dart:io';
import '../models/archivo_modelo.dart';

class RenombrarService {
  static int quitarSufijoCopia(List<ArchivoModelo> seleccionados) {
    return _procesarRenombrado(seleccionados, (nombreBase, ext) {
      return "${nombreBase.replaceAll(RegExp(r'\s\(\d+\)$'), '')}$ext";
    });
  }

  static int renombrarMantieneNumero(
    List<ArchivoModelo> seleccionados,
    String nuevoNombre,
  ) {
    return _procesarRenombrado(seleccionados, (nombreBase, ext) {
      Match? match = RegExp(r'(\d+)$').firstMatch(nombreBase.trim());
      if (match != null) return "$nuevoNombre ${match.group(1)!}$ext";
      return "";
    });
  }

  static int renombrarSecuencial(
    List<ArchivoModelo> seleccionados,
    String nuevoNombre,
    String inicioStr,
  ) {
    int length = inicioStr.length;
    int contador = int.tryParse(inicioStr) ?? 1;
    return _procesarRenombrado(seleccionados, (nombreBase, ext) {
      String numeroStr = contador.toString().padLeft(length, '0');
      contador++;
      return "$nuevoNombre $numeroStr$ext";
    });
  }

  static int _procesarRenombrado(
    List<ArchivoModelo> archivos,
    String Function(String, String) logica,
  ) {
    int renombrados = 0;
    for (var archivo in archivos) {
      int lastDot = archivo.nombre.lastIndexOf('.');
      String nombreBase = lastDot != -1
          ? archivo.nombre.substring(0, lastDot)
          : archivo.nombre;
      String ext = lastDot != -1 ? archivo.nombre.substring(lastDot) : '';

      String nuevoNombre = logica(nombreBase, ext);

      if (nuevoNombre != archivo.nombre && nuevoNombre.isNotEmpty) {
        String nuevaRuta =
            "${File(archivo.rutaCompleta).parent.path}${Platform.pathSeparator}$nuevoNombre";
        File(archivo.rutaCompleta).renameSync(nuevaRuta);
        renombrados++;
      }
    }
    return renombrados;
  }
}
