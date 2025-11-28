import 'package:app_g/models/alerta_model.dart';
import 'package:app_g/screens/historial_detalle_screen.dart';
import 'package:flutter/material.dart';

class HistorialCard extends StatelessWidget {
  final AlertaModel alerta;

  const HistorialCard({super.key, required this.alerta});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetalleHistorialScreen(alerta: alerta),
          ),
        );
      },
      child: Card(
        color: Colors.grey[850],
        elevation: 4.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: Colors.blue, size: 32),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Text(
                      'ID Alerta: ${alerta.idAlerta}',
                      style: const TextStyle(color: Colors.white, fontSize: 16.0),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18.0),
                ],
              ),
              const SizedBox(height: 12.0),
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: const LinearProgressIndicator(
                  value: 1.0,
                  backgroundColor: Colors.grey,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 6.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fecha: ${alerta.timestamp.toLocal()}',
                style: const TextStyle(color: Colors.white70, fontSize: 14.0),
              ),
              Text(
                'Ubicación: (${alerta.latitud}, ${alerta.longitud})',
                style: const TextStyle(color: Colors.white70, fontSize: 14.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
