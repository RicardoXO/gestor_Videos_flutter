import 'archivo_modelo.dart';

class CarpetaModelo {
  final String rutaCompleta;
  final String nombre;
  final int tamanoBytes;
  final List<ArchivoModelo> archivos;

  CarpetaModelo({
    required this.rutaCompleta,
    required this.nombre,
    required this.tamanoBytes,
    required this.archivos,
  });
}
