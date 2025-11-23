import 'package:flutter/material.dart';

dynamic getValueFromPath(Map<dynamic, dynamic> json, String path) {
  final regex = RegExp(r'([^/\[\]]+)|\[(\d+)\]');
  dynamic current = json;

  for (final match in regex.allMatches(path)) {
    final key = match.group(1);
    final index = match.group(2);

    if (key != null) {
      if (current is Map) {
        current = current[key];
      } else {
        return null;
      }
    } else if (index != null) {
      final i = int.parse(index);
      if (current is List) {
        current = current[i];
      } else {
        throw Exception('Index [$i] utilisé sur un objet non-liste');
      }
    }
  }

  return current;
}

/// Recherche récursive d'une clé dans une arborescence de Map.
/// Retourne la valeur si trouvée, sinon null.
dynamic findValueByKey(
  Map<String, dynamic> map,
  String key, {
  dynamic valueToSet,
}) {
  if (map.containsKey(key)) {
    if (valueToSet != null) {
      map[key] = valueToSet;
    }
    return map[key];
  }
  for (final entry in map.entries) {
    final value = entry.value;
    if (value is Map<String, dynamic>) {
      final result = findValueByKey(value, key, valueToSet: valueToSet);
      if (result != null) return result;
    } else if (value is List) {
      for (final item in value) {
        if (item is Map<String, dynamic>) {
          final result = findValueByKey(item, key, valueToSet: valueToSet);
          if (result != null) return result;
        }
      }
    }
  }
  return null;
}

class UtilDart {
  String? shift(List l) {
    if (l.isNotEmpty) {
      var first = l.first;
      l.removeAt(0);
      return first;
    }
    return null;
  }

  bool isURL(
    String? str, {
    List<String?> protocols = const ['http', 'https', 'ftp'],
    bool requireTld = true,
    bool requireProtocol = false,
    bool allowUnderscore = false,
    List<String> hostWhitelist = const [],
    List<String> hostBlacklist = const [],
  }) {
    if (str == null ||
        str.isEmpty ||
        str.length > 2083 ||
        str.startsWith('mailto:')) {
      return false;
    }

    String protocol, user, auth, hostname, portStr, path;

    String? query, hash, host;
    int port;

    List<String> split;

    // check protocol
    split = str.split('://');
    if (split.length > 1) {
      protocol = shift(split)!;
      if (!protocols.contains(protocol)) {
        return false;
      }
    } else if (requireProtocol == true) {
      return false;
    }
    str = split.join('://');

    // check hash
    split = str.split('#');
    str = shift(split);
    hash = split.join('#');
    if (hash != '' && RegExp(r'\s').hasMatch(hash)) {
      return false;
    }

    // check query params
    split = str!.split('?');
    str = shift(split);
    query = split.join('?');
    if (query != '' && RegExp(r'\s').hasMatch(query)) {
      return false;
    }

    // check path
    split = str!.split('/');
    str = shift(split);
    path = split.join('/');
    if (path != '' && RegExp(r'\s').hasMatch(path)) {
      return false;
    }

    // check auth type urls
    split = str!.split('@');
    if (split.length > 1) {
      auth = shift(split)!;
      if (auth.contains(':')) {
        var auth2 = auth.split(':');
        user = shift(auth2)!;
        if (!RegExp(r'^\S+$').hasMatch(user)) {
          return false;
        }
        if (!RegExp(r'^\S*$').hasMatch(user)) {
          return false;
        }
      }
    }

    // check hostname
    hostname = split.join('@');
    split = hostname.split(':');
    host = shift(split);
    if (split.isNotEmpty) {
      portStr = split.join(':');
      try {
        port = int.parse(portStr, radix: 10);
      } catch (e) {
        return false;
      }
      if (!RegExp(r'^[0-9]+$').hasMatch(portStr) || port <= 0 || port > 65535) {
        return false;
      }
    }

    if (!isIP(host) &&
        !isFQDN(
          host!,
          requireTld: requireTld,
          allowUnderscores: allowUnderscore,
        ) &&
        host != 'localhost') {
      return false;
    }

    if (hostWhitelist.isNotEmpty && !hostWhitelist.contains(host)) {
      return false;
    }

    if (hostBlacklist.isNotEmpty && hostBlacklist.contains(host)) {
      return false;
    }

    return true;
  }

  final RegExp _ipv4Maybe = RegExp(
    r'^(\d?\d?\d)\.(\d?\d?\d)\.(\d?\d?\d)\.(\d?\d?\d)$',
  );
  final RegExp _ipv6 = RegExp(
    r'^::|^::1|^([a-fA-F0-9]{1,4}::?){1,7}([a-fA-F0-9]{1,4})$',
  );

  bool isIP(String? str, [/*<String | int>*/ version]) {
    version = version.toString();
    if (version == 'null') {
      return isIP(str, 4) || isIP(str, 6);
    } else if (version == '4') {
      if (!_ipv4Maybe.hasMatch(str!)) {
        return false;
      }
      var parts = str.split('.');
      parts.sort((a, b) => int.parse(a) - int.parse(b));
      return int.parse(parts[3]) <= 255;
    }
    return version == '6' && _ipv6.hasMatch(str!);
  }

  /// check if the string [str] is a fully qualified domain name (e.g. domain.com).
  ///
  /// * [requireTld] sets if TLD is required
  /// * [allowUnderscore] sets if underscores are allowed
  bool isFQDN(
    String str, {
    bool requireTld = true,
    bool allowUnderscores = false,
  }) {
    var parts = str.split('.');
    if (requireTld) {
      var tld = parts.removeLast();
      if (parts.isEmpty || !RegExp(r'^[a-z]{2,}$').hasMatch(tld)) {
        return false;
      }
    }

    for (var part in parts) {
      if (allowUnderscores) {
        if (part.contains('__')) {
          return false;
        }
      }
      if (!RegExp(r'^[a-z\\u00a1-\\uffff0-9-]+$').hasMatch(part)) {
        return false;
      }
      if (part[0] == '-' ||
          part[part.length - 1] == '-' ||
          part.contains('---')) {
        return false;
      }
    }
    return true;
  }
}

class TextSize {
  double getTextWidth(String text, double fontSize) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    return textPainter.size.width;
  }
}

class LruCache<K, V> {
  final int capacity;
  final _map = <K, _Node<K, V>>{};
  _Node<K, V>? _head;
  _Node<K, V>? _tail;

  LruCache(this.capacity);

  void clear() {
    _map.clear();
    _head = null;
    _tail = null;
  }

  V? get(K key) {
    final node = _map[key];
    if (node == null) return null;
    _moveToHead(node);
    return node.value;
  }

  void put(K key, V value) {
    var node = _map[key];
    if (node != null) {
      node.value = value;
      _moveToHead(node);
    } else {
      node = _Node(key, value);
      _map[key] = node;
      _addNode(node);

      if (_map.length > capacity) {
        _map.remove(_tail!.key);
        _removeNode(_tail!);
      }
    }
  }

  void _addNode(_Node<K, V> node) {
    node.next = _head;
    node.prev = null;
    if (_head != null) _head!.prev = node;
    _head = node;
    _tail ??= node;
  }

  void _removeNode(_Node<K, V> node) {
    if (node.prev != null) {
      node.prev!.next = node.next;
    } else {
      _head = node.next;
    }
    if (node.next != null) {
      node.next!.prev = node.prev;
    } else {
      _tail = node.prev;
    }
  }

  void _moveToHead(_Node<K, V> node) {
    _removeNode(node);
    _addNode(node);
  }
}

class _Node<K, V> {
  K key;
  V value;
  _Node<K, V>? prev;
  _Node<K, V>? next;
  _Node(this.key, this.value);
}
