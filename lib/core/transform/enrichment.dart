import 'package:jsonschema/core/transform/engine.dart';

class SimpleCache<V> {
  final _store = <String, Map<String, dynamic>>{};
  void put(String key, V value, int ttlSeconds) {
    final expiry = DateTime.now().toUtc().add(Duration(seconds: ttlSeconds));
    _store[key] = {'value': value, 'expiry': expiry.toIso8601String()};
  }

  V? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    final expiry = DateTime.parse(entry['expiry'] as String);
    if (DateTime.now().toUtc().isAfter(expiry)) {
      _store.remove(key);
      return null;
    }
    return entry['value'] as V;
  }

  void invalidate(String key) => _store.remove(key);
}

typedef EnrichmentResult = Map<String, dynamic>;

abstract class EnrichmentProvider {
  Future<EnrichmentResult?> fetch(String key);
}

class EnrichmentRegistry {
  final Map<String, EnrichmentProvider> _providers = {};
  void register(String name, EnrichmentProvider provider) =>
      _providers[name] = provider;
  EnrichmentProvider? getProvider(String name) => _providers[name];
}

class TableLookupProvider implements EnrichmentProvider {
  final Map<String, EnrichmentResult> table;
  TableLookupProvider(this.table);
  @override
  Future<EnrichmentResult?> fetch(String key) async {
    // simulate quick lookup
    return table[key];
  }
}

class HttpEnrichmentProvider implements EnrichmentProvider {
  final Uri endpoint;
  final Duration timeout;
  HttpEnrichmentProvider(String url, {int timeoutMs = 300})
    : endpoint = Uri.parse(url),
      timeout = Duration(milliseconds: timeoutMs);

  @override
  Future<EnrichmentResult?> fetch(String key) async {
    // NOTE: use your HTTP client; here pseudo-code to show intent
    // final resp = await httpClient.get(endpoint.replace(queryParameters: {'q': key})).timeout(timeout);
    // if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
    // return null;
    throw UnimplementedError('Replace with real HTTP client call');
  }
}

class EnrichmentEngine {
  final EnrichmentRegistry registry;
  final SimpleCache<EnrichmentResult> cache = SimpleCache();
  EnrichmentEngine(this.registry);

  /// Apply a single enrichment definition (from mapping YAML) to the record `out`.
  /// Returns true if enrichment applied or fallback used; false if DLQ required.
  Future<bool> applyEnrichment(
    Map<String, dynamic> out,
    Map<String, dynamic> enrichDef,
  ) async {
    final id = enrichDef['id'] as String? ?? 'unknown';
    final inputPath = enrichDef['input'] as String;
    final providerName = enrichDef['provider'] as String;
    final outputs =
        (enrichDef['outputs'] as List<dynamic>?)?.cast<String>() ?? [];

    final inputLookup =
        (enrichDef['input_lookup'] as List<dynamic>?)?.cast<String>() ?? [];

    if (inputLookup.isEmpty) {
      // if no input_lookup, assume outputs are top-level fields to set
      inputLookup.addAll(outputs);
    }

    final cacheCfg = enrichDef['cache'] as Map<String, dynamic>?;
    final ttl = cacheCfg != null ? (cacheCfg['ttl_seconds'] as int? ?? 0) : 0;
    final fallback = enrichDef['fallback'] as Map<String, dynamic>?;
    final onError = enrichDef['on_error'] as String? ?? 'dlq';

    final key = TransformEngine.getPath(out, inputPath)?.toString();
    if (key == null) {
      // nothing to enrich; treat as success (or optionally fallback)
      return true;
    }

    final cacheKey = '$id::$key';
    final cached = cache.get(cacheKey);
    if (cached != null) {
      for (int i = 0; i < inputLookup.length; i++) {
        final outField = inputLookup[i];
        if (cached.containsKey(outField)) {
          TransformEngine.setPath(out, outputs[i], cached[outField]);
        }
      }
      return true;
    }

    final provider = registry.getProvider(providerName);
    if (provider == null) {
      // provider missing -> fallback or dlq
      if (fallback != null && fallback['type'] == 'default') {
        for (int i = 0; i < inputLookup.length; i++) {
          final outField = inputLookup[i];
          TransformEngine.setPath(out, outputs[i], fallback['values']?[outField]);
        }
        return true;
      }
      if (onError == 'dlq') {
        out['_dlq'] = out['_dlq'] ?? [];
        (out['_dlq'] as List).add({
          'enrichment': id,
          'error': 'provider_not_found',
        });
        return false;
      }
      return true;
    }

    try {
      final result = await provider.fetch(key);
      if (result != null) {
        // map outputs
        for (int i = 0; i < inputLookup.length; i++) {
          final outField = inputLookup[i];
          if (result.containsKey(outField)) {
            TransformEngine.setPath(out, outputs[i], result[outField]);
          }
        }
        if (ttl > 0) cache.put(cacheKey, result, ttl);
        return true;
      } else {
        // no result -> fallback or dlq
        if (fallback != null) {
          if (fallback['type'] == 'default') {
            for (int i = 0; i < inputLookup.length; i++) {
              final outField = inputLookup[i];
              TransformEngine.setPath(
                out,
                outputs[i],
                fallback['values']?[outField],
              );
            }
            return true;
          } else if (fallback['type'] == 'null') {
            for (int i = 0; i < outputs.length; i++) {
              TransformEngine.setPath(out, outputs[i], null);
            }
            return true;
          }
        }
        if (onError == 'dlq') {
          out['_dlq'] = out['_dlq'] ?? [];
          (out['_dlq'] as List).add({'enrichment': id, 'error': 'no_result'});
          return false;
        }
        return true;
      }
    } catch (e) {
      // error -> fallback or dlq
      if (fallback != null && fallback['type'] == 'default') {
        for (int i = 0; i < outputs.length; i++) {
          final outField = inputLookup[i];
          TransformEngine.setPath(out, outputs[i], fallback['values']?[outField]);
        }
        return true;
      }
      if (onError == 'dlq') {
        out['_dlq'] = out['_dlq'] ?? [];
        (out['_dlq'] as List).add({'enrichment': id, 'error': e.toString()});
        return false;
      }
      return true;
    }
  }

  /// Apply all enrichments defined in mapping to the record `out`.
  Future<void> applyAll(
    Map<String, dynamic> out,
    Map<String, dynamic> mapping,
  ) async {
    final enrichments = (mapping['enrichments'] as List<dynamic>?) ?? [];
    for (final e in enrichments) {
      await applyEnrichment(out, e as Map<String, dynamic>);
    }
  }
}
