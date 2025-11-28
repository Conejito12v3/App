import 'package:logger/logger.dart';

class _TimestampPrinter extends LogPrinter {
  final PrettyPrinter _inner;
  _TimestampPrinter()
      : _inner = PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 5,
          lineLength: 50,
          colors: true,
          printEmojis: true,
          printTime: false,
        );

  @override
  List<String> log(LogEvent event) {
    final ts = _formatTime(DateTime.now());
    final lines = _inner.log(event);
    return lines.map((l) => '[$ts] $l').toList();
  }

  String _formatTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}.${three(dt.millisecond)}';
  }
}

final Logger logger = Logger(printer: _TimestampPrinter());