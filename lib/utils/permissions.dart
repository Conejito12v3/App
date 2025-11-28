import 'package:permission_handler/permission_handler.dart';

Future<void> requestLocationPermissions() async {
  var status = await Permission.location.status;
  if (!status.isGranted) {
    status = await Permission.location.request();
    if (!status.isGranted) throw Exception('Permiso de ubicación denegado');
  }

  var bgStatus = await Permission.locationAlways.status;
  if (!bgStatus.isGranted) {
    bgStatus = await Permission.locationAlways.request();
    if (!bgStatus.isGranted) throw Exception('Permiso de ubicación en segundo plano denegado');
  }
}
