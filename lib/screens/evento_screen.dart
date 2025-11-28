import 'dart:async';
import 'package:app_g/screens/historial_screen.dart';
import 'package:flutter/material.dart';
import 'package:app_g/services/hive_service.dart';
import 'package:app_g/components/evento_card.dart';
import 'package:app_g/models/evento_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class EventoScreen extends StatefulWidget {
  const EventoScreen({super.key});

  @override
  State<EventoScreen> createState() => _EventoScreenState();
}

class _EventoScreenState extends State<EventoScreen>
    with WidgetsBindingObserver {
  List<EventoModel> _eventos = [];
  late Box<EventoModel> _box;
  bool _loading = true;
  bool _isReloading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reloadEventos();
  }

  Future<void> _init() async {
    try {
      _box = await Hive.openBox<EventoModel>('eventoBox');
      await _reloadEventos();

      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        await _reloadEventos();
      });

      _box.listenable().addListener(() {
        if (!_isReloading) _reloadEventos();
      });
    } catch (e, st) {
      debugPrint('❌ Error al inicializar EventoScreen: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _calcularTiempoFin(double distancia) {
    if (distancia == -1) return DateTime.now().add(const Duration(minutes: 2));
    if (distancia < 500) return DateTime.now().add(const Duration(seconds: 30));
    if (distancia < 1500) return DateTime.now().add(const Duration(minutes: 1));
    return DateTime.now().add(const Duration(minutes: 5));
  }

  Future<void> _eliminarEvento(String id) async {
    await HiveService.deleteEvento(id, 'eventoBox');
    await _reloadEventos();
  }

  Future<void> _reloadEventos() async {
    if (_isReloading) return;
    _isReloading = true;

    try {
      final now = DateTime.now();
      final valores = _box.values.toList();

      final seenIds = <String>{};
      final activos = <EventoModel>[];

      for (var e in valores) {
        if (!seenIds.add(e.alerta.idAlerta)) continue;
        if (e.fin != null && now.isAfter(e.fin!)) {
          await HiveService.deleteEvento(e.alerta.idAlerta, 'eventoBox');
          continue;
        }
        activos.add(e);
      }

      activos.sort((a, b) {
        if (a.distancia == -1) return 1;
        if (b.distancia == -1) return -1;
        return a.distancia.compareTo(b.distancia);
      });

      final top5 = activos.take(5).toList();

      for (var evento in top5) {
        if (evento.fin == null) {
          final nuevoFin = _calcularTiempoFin(evento.distancia);
          final actualizado = EventoModel(
            alerta: evento.alerta,
            distancia: evento.distancia,
            timestamp: evento.timestamp,
            fin: nuevoFin,
          );
          await _box.put(evento.alerta.idAlerta, actualizado);
        }
      }

      final actuales = _box.values
          .where((e) => e.fin == null || !now.isAfter(e.fin!))
          .toList();

      actuales.sort((a, b) {
        if (a.distancia == -1) return 1;
        if (b.distancia == -1) return -1;
        return a.distancia.compareTo(b.distancia);
      });

      final visibles = actuales.take(5).toList();

      if (mounted) {
        setState(() {
          _eventos = visibles;
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('❌ Error en _reloadEventos: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      _isReloading = false;
    }
  }

  void _abrirHistorial() async {
    final historial = await HiveService.getHistorial();
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistorialScreen(historial: historial),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Eventos"),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _abrirHistorial,
            icon: const Icon(Icons.history),
            tooltip: 'Ver historial',
          )
        ],
      ),
      body: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16),
        child: _eventos.isEmpty
            ? const Center(
                child: Text(
                  "No hay eventos",
                  style: TextStyle(color: Colors.white),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _eventos.length,
                itemBuilder: (_, i) {
                  final ev = _eventos[i];
                  if (ev.fin == null) return const SizedBox.shrink();

                  return EventoCard(
                    key: ValueKey(ev.alerta.idAlerta),
                    evento: ev,
                    fin: ev.fin!,
                    onExpired: () => _eliminarEvento(ev.alerta.idAlerta),
                  );
                },
              ),
      ),
    );
  }
}