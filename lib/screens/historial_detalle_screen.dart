import 'package:flutter/material.dart';
import 'package:app_g/models/alerta_model.dart';

class DetalleHistorialScreen extends StatelessWidget {
  final AlertaModel alerta;

  const DetalleHistorialScreen({super.key, required this.alerta});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Detalle de Alerta'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ID Alerta: ${alerta.idAlerta}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Cámara: ${alerta.idCamara}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Fecha: ${alerta.timestamp.toLocal()}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Ubicación: (${alerta.latitud}, ${alerta.longitud})',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Score: ${alerta.score.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (alerta.img.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  alerta.img,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      height: 200,
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: const LinearProgressIndicator(
                value: 1.0,
                backgroundColor: Colors.grey,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 6.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
