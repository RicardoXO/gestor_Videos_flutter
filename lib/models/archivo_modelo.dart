class ArchivoModelo {
  final String nombre;
  final String rutaCompleta;
  final int tamanoBytes;
  final String tipo;
  bool seleccionado;

  ArchivoModelo({
    required this.nombre,
    required this.rutaCompleta,
    required this.tamanoBytes,
    required this.tipo,
    this.seleccionado = false,
  });
}
