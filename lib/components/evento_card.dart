import 'dart:async';
import 'package:app_g/screens/evento_detalle_screen.dart';
import 'package:app_g/services/socketio_service.dart';
import 'package:app_g/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:app_g/models/evento_model.dart';

class EventoCard extends StatefulWidget {
  final EventoModel evento;
  final VoidCallback onExpired;
  final DateTime fin;

  const EventoCard({
    super.key,
    required this.evento,
    required this.onExpired,
    required this.fin,
  });

  @override
  _EventoCardState createState() => _EventoCardState();
}

class _EventoCardState extends State<EventoCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _checkTimer;
  int segundosRestantes = 0;

  @override
  void initState() {
    super.initState();

    _iniciarAnimacion();
    _iniciarContador();

    logger.i('EventoCard creado para alerta ${widget.evento.alerta.idAlerta}');
  }

  void _iniciarAnimacion() {
    final remainingMs = widget.fin.difference(DateTime.now()).inMilliseconds;
    final durationMs = remainingMs > 0 ? remainingMs : 1;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..forward();
  }

  void _iniciarContador() {
    _actualizarTiempoRestante();

    _checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      _actualizarTiempoRestante();

      if (DateTime.now().isAfter(widget.fin)) {
        timer.cancel();
        _controller.stop();
        widget.onExpired();
      }
    });
  }

  void _actualizarTiempoRestante() {
    final diff = widget.fin.difference(DateTime.now());
    setState(() {
      segundosRestantes = diff.inSeconds > 0 ? diff.inSeconds : 0;
    });
  }

  @override
  void didUpdateWidget(covariant EventoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la fin cambió (rara vez), reiniciamos animación sin resetear por rebuilds normales
    if (oldWidget.fin != widget.fin) {
      _controller.dispose();
      _checkTimer?.cancel();
      _iniciarAnimacion();
      _iniciarContador();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        logger.i('Hola');
        try {
          final id = int.tryParse(widget.evento.alerta.idAlerta);
          if (id != null) {
            final res = await SocketioService.verifyAlertWithConnect(id);

            if (res != null) {
              // Llegó una alerta válida
              logger.i('El servidor respondió con alerta: ${res.idAlerta}');

              // Navegar a la pantalla de detalle
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetalleEventoScreen(
                      key: Key(widget.evento.alerta.idAlerta),
                      alerta: res
                    ),
                  ),
                );
              }
            } else {
              logger.i('No se recibió alerta válida');
            }
          }
        } catch (e, st) {
          logger.e('Error al verificar alerta: $e');
          logger.e('StackTrace: $st');
        }
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
                  const Icon(Icons.warning, color: Colors.red, size: 32),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Text(
                      'Evento ${widget.evento.alerta.idAlerta}: ${widget.evento.distancia.toStringAsFixed(2)} m',
                      style: const TextStyle(color: Colors.white, fontSize: 16.0),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18.0),
                ],
              ),
              const SizedBox(height: 12.0),
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _controller.value,
                      backgroundColor: Colors.grey[700],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                      minHeight: 6.0,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                segundosRestantes > 0 ? 'Expira en $segundosRestantes segundos' : 'Expirado',
                style: TextStyle(
                  color: segundosRestantes > 0 ? Colors.white70 : Colors.redAccent,
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
