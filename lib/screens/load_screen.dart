import 'package:app_g/screens/evento_screen.dart';
import 'package:flutter/material.dart';
import 'package:app_g/services/app_state_service.dart';

class LoadingGate extends StatefulWidget {
  const LoadingGate({super.key});

  @override
  State<LoadingGate> createState() => _LoadingGateState();
}

class _LoadingGateState extends State<LoadingGate> {
  @override
  void initState() {
    super.initState();
    AppStateService.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStatus>(
      stream: AppStateService.instance.stream,
      builder: (context, snapshot) {
        final status = snapshot.data ?? AppStatus.loading;

        switch (status) {
          case AppStatus.loading:
            return _LoadingScreen("Verificando requisitos...");
          
          case AppStatus.noInternet:
            return _ErrorScreen(
              "Sin conexión a internet",
              "Por favor activa tus datos o WiFi."
            );

          case AppStatus.noLocation:
            return _ErrorScreen(
              "Ubicación desactivada",
              "Activa el GPS para continuar."
            );

          case AppStatus.apiDown:
            return _ErrorScreen(
              "No se puede conectar al servidor",
              "El backend no responde."
            );

          case AppStatus.noTopic:
            return _ErrorScreen(
              "No se asignaron los topics",
              "Reinicia la app o vuelve a intentar."
            );

          case AppStatus.ok:
            return EventoScreen(); // tu pantalla principal
        }
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  final String text;
  const _LoadingScreen(this.text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(height: 20),
            Text(text, style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ErrorScreen(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 72, color: Colors.red),
              SizedBox(height: 20),
              Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 10),
              Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => AppStateService.instance.initialize(force: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text("Reintentar"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
