import 'package:app_g/components/historial_card.dart';
import 'package:app_g/models/alerta_model.dart';
import 'package:flutter/material.dart';

class HistorialScreen extends StatelessWidget {
  final List<AlertaModel> historial;

  const HistorialScreen({super.key, required this.historial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // fondo negro
      appBar: AppBar(
        title: const Text('Historial de Alertas'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: historial.isEmpty
        ? const Center(
            child: Text(
              'No hay historial',
              style: TextStyle(color: Colors.white),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: historial.length,
            itemBuilder: (_, i) {
              final alerta = historial[i];
              return HistorialCard(alerta: alerta);
            },
          ),
    );
  }
}
