import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/router_config.dart';
// import 'package:fleather/fleather.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tz;

late SharedPreferences prefs;
// List<String> logs = [];
// List<String> errors = [];

enum DebugEntryType { log, error }

class DebugEntry {
  DebugEntry({
    required this.timestamp,
    required this.type,
    required this.message,
    this.stackTrace,
  });

  final DateTime timestamp;
  final DebugEntryType type;
  final String message;
  final String? stackTrace;
}

final List<DebugEntry> debugEntries = [];

void main() async {
  prefs = await SharedPreferences.getInstance();

  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintPointersEnabled = false;

  // Capture les erreurs Flutter (UI, widgets, rendering…)
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = "[FLUTTER ERROR] ${details.exceptionAsString()}";
    saveError(message, details.stack);
    debugPrintSynchronously(message);
  };

  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      tz.initializeTimeZones();
      runApp(const MyApp());
    },
    (error, stack) {
      final message = "[DART ERROR] $error\n$stack";
      saveError(message, stack);
      debugPrintSynchronously(message);
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        // Capture la stack ici, dans le contexte de l'appelant du print
        saveLog(line, null);

        // Et tu continues d'afficher normalement
        parent.print(zone, line);
      },
    ),
  );
}

void saveLog(String line, [String? stack]) {
  final now = DateTime.now();
  debugEntries.add(
    DebugEntry(
      timestamp: now,
      type: DebugEntryType.log,
      message: line,
      stackTrace: stack,
    ),
  );
  if (debugEntries.length > 1000) debugEntries.removeAt(0);
}

void saveError(String message, dynamic stack) {
  final now = DateTime.now();
  debugEntries.add(
    DebugEntry(
      timestamp: now,
      type: DebugEntryType.error,
      message: message,
      stackTrace: stack?.toString(),
    ),
  );
  if (debugEntries.length > 1000) debugEntries.removeAt(0);
}

String formatTimestamp(DateTime dateTime) {
  final h = dateTime.hour.toString().padLeft(2, '0');
  final m = dateTime.minute.toString().padLeft(2, '0');
  final s = dateTime.second.toString().padLeft(2, '0');
  final ms = dateTime.millisecond.toString().padLeft(3, '0');
  return '$h:$m:$s.$ms';
}

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  bool _newestFirst = true;
  bool _errorsOnly = false;

  @override
  Widget build(BuildContext context) {
    final orderedEntries =
        _newestFirst
            ? debugEntries.reversed.toList(growable: false)
            : debugEntries;
    final displayedEntries =
        _errorsOnly
            ? orderedEntries
                .where((entry) => entry.type == DebugEntryType.error)
                .toList(growable: false)
            : orderedEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Debug Timeline"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: _errorsOnly ? 'Show logs and errors' : 'Show errors only',
            onPressed: () {
              setState(() {
                _errorsOnly = !_errorsOnly;
              });
            },
            icon: Icon(
              _errorsOnly ? Icons.filter_alt_off : Icons.filter_alt,
              color: _errorsOnly ? Colors.red : null,
            ),
          ),
          IconButton(
            tooltip: _newestFirst ? 'Show oldest first' : 'Show newest first',
            onPressed: () {
              setState(() {
                _newestFirst = !_newestFirst;
              });
            },
            icon: Icon(
              _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: displayedEntries.length,
        itemBuilder: (context, index) {
          final entry = displayedEntries[index];
          final isError = entry.type == DebugEntryType.error;
          final isFirst = index == 0;
          final isLast = index == displayedEntries.length - 1;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              formatTimestamp(entry.timestamp),
                              style: Theme.of(context).textTheme.labelMedium,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TimelineMarker(
                          isFirst: isFirst,
                          isLast: isLast,
                          isError: isError,
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.message,
                              style: TextStyle(
                                color: isError ? Colors.red : null,
                              ),
                            ),
                            if (entry.stackTrace != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.stackTrace!,
                                  style: Theme.of(context).textTheme.labelSmall,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimelineMarker extends StatelessWidget {
  const _TimelineMarker({
    required this.isFirst,
    required this.isLast,
    required this.isError,
  });

  final bool isFirst;
  final bool isLast;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final lineColor = Theme.of(context).dividerColor.withValues(alpha: 0.45);
    final dotColor =
        isError ? Colors.red : Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 26,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 2,
              color: isFirst ? Colors.transparent : lineColor,
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: 2,
              color: isLast ? Colors.transparent : lineColor,
            ),
          ),
        ],
      ),
    );
  }
}

class ThemeHolder {
  static late ThemeData theme;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.blueGrey,
    );
    ThemeHolder.theme = theme;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      excludeSemantics: true,
      child: MaterialApp.router(
        title: 'API Architect',
        localizationsDelegates: [
          //FleatherLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          // GlobalCupertinoLocalizations.delegate,
          // GlobalWidgetsLocalizations.delegate,
          //FlutterQuillLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color.fromRGBO(86, 80, 14, 171),
        ),
        darkTheme: theme,
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    );
  }
}
