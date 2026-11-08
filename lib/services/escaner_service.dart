import 'dart:io';
import '../models/archivo_modelo.dart';
import '../models/carpeta_modelo.dart';

// Clase auxiliar para devolver ambos resultados juntos y evitar errores de sintaxis
class ResultadoEscaner {
  final List<CarpetaModelo> carpetas;
  final List<ArchivoModelo> archivos;
  ResultadoEscaner(this.carpetas, this.archivos);
}

class EscanerService {
  static const List<String> extensionesValidas = [
    'mp4',
    'mov',
    'mkv',
    'avi',
    'ico',
  ];

  static ResultadoEscaner escanear(String directorioBase) {
    final dir = Directory(directorioBase);
    if (!dir.existsSync()) return ResultadoEscaner([], []);

    List<CarpetaModelo> carpetasTemp = [];
    List<ArchivoModelo> archivosTemp = [];
    Map<String, List<ArchivoModelo>> agrupacion = {};

    List<FileSystemEntity> entidades = dir.listSync(recursive: true);

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
        if (!agrupacion.containsKey(parentPath)) agrupacion[parentPath] = [];
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

    return ResultadoEscaner(carpetasTemp, archivosTemp);
  }
}
