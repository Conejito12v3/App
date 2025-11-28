import 'dart:io';

import 'package:flutter/material.dart';
import 'package:app_g/models/alerta_model.dart';
import 'package:app_g/services/socketio_service.dart';
import 'package:app_g/services/hive_service.dart';
import 'package:app_g/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

class DetalleEventoScreen extends StatefulWidget {
  final AlertaModel alerta;

  const DetalleEventoScreen({super.key, required this.alerta});

  @override
  State<DetalleEventoScreen> createState() => _DetalleEventoScreenState();
}

class _DetalleEventoScreenState extends State<DetalleEventoScreen> {
  bool _accionTomada = false;
  bool _loading = false;
  bool _alertaAsignada = true;
  bool _finalizado = true;

  Future<void> _enviarAck(String estado) async {
    setState(() => _loading = true);

    final resultado = await SocketioService.sendAck(
      idAlerta: widget.alerta.idAlerta,
      idAlertaAct: widget.alerta.idAlerta,
      idCamara: widget.alerta.idCamara,
      timestamp: widget.alerta.timestamp,
      estado: estado,
    );

    if (resultado != null) {
      logger.i('ACK enviado exitosamente: $resultado');
      if (resultado == 'alerta asignada') {
        setState(() {
          _accionTomada = true;
          _finalizado = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alerta asignada')),
        );
      } else if (resultado == 'alerta atendida') {
        setState(() {
          _accionTomada = true;
          _alertaAsignada = false;
          _finalizado = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alerta atendida')),
        );
        await HiveService.deleteEvento(widget.alerta.idAlerta, HiveService.eventoBox);
      } else {
        logger.e('Respuesta inesperada: $resultado');
      }
    } else {
      logger.e('Error al enviar ACK');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar ACK')),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _finalizarTarea() async {
    setState(() => _loading = true);

    final success = await SocketioService.sendDone(idAlerta: widget.alerta.idAlerta);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarea finalizada correctamente')),
      );

      setState(() {
        _finalizado = true;
        _accionTomada = true;
        _alertaAsignada = false;
      });

      await HiveService.deleteEvento(widget.alerta.idAlerta, HiveService.eventoBox);
      await HiveService.deleteFirstEvento();
      await HiveService.addHistorial(widget.alerta);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo finalizar la alerta')),
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> abrirMapa(double lat, double lng) async {
    final Uri url;

    if (Platform.isIOS) {
      // Apple Maps: abre en modo conducción
      url = Uri.parse('maps://?daddr=$lat,$lng&dirflg=d');
    } else {
      // Android: Google Maps navegación
      url = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    }

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // fallback web
      final Uri fallback = Platform.isIOS
          ? Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d')
          : Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

      if (!await launchUrl(fallback, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir la ubicación en Maps ni navegador');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerta = widget.alerta;

    return WillPopScope(
      onWillPop: () async => _finalizado,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.grey[900],
          title: const Text('Detalle del Evento', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_alarms, color: Colors.redAccent, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Alerta ID: ${alerta.idAlerta}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cámara: ${alerta.idCamara}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fecha: ${alerta.timestamp.toLocal()}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      abrirMapa(widget.alerta.latitud, widget.alerta.longitud);
                    },
                    child: Text(
                      'Ubicación: (${widget.alerta.latitud}, ${widget.alerta.longitud})',
                      style: const TextStyle(color: Colors.blue, fontSize: 14),
                    ),
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
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: 100,
                    backgroundColor: Colors.grey[700],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Score: ${alerta.score.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _accionTomada
                          ? _alertaAsignada
                              ? Center(
                                  child: ElevatedButton.icon(
                                    onPressed: _finalizarTarea,
                                    icon: const Icon(Icons.check),
                                    label: const Text("Finalizar tarea"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 24),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink()
                          : _alertaAsignada
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _enviarAck('atendida'),
                                        icon: const Icon(Icons.check_circle),
                                        label: const Text("Tomar acción"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _enviarAck('falso_positivo'),
                                        icon: const Icon(Icons.cancel),
                                        label: const Text("Falso Positivo"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
