import 'options.dart';
import 'types.dart';
import 'utils.dart';

/// Encodes a Dart value to TOON (Token-Oriented Object Notation) format.
///
/// TOON is a compact, human-readable format designed for LLM inputs that uses
/// 30-60% fewer tokens than JSON while maintaining readability.
///
/// **Parameters:**
/// - [value]: Any JSON-serializable Dart value (Map, List, or primitives)
/// - [options]: Optional [EncodeOptions] to customize encoding behavior
///
/// **Features:**
/// - Tabular format for arrays of uniform objects
/// - Minimal quoting (only when necessary)
/// - Configurable delimiters (`,`, `\t`, `|`)
/// - Optional length markers for arrays
/// - Flat map support for nested structures
///
/// See also:
/// - [decode] for converting TOON back to Dart values
/// - [EncodeOptions] for all available encoding options
String encode(
  JsonValue value, {
  EncodeOptions options = const EncodeOptions(),
}) {
  final encoder = _ToonEncoder(options);

  if (options.enforceFlatMap && value is Map<String, dynamic>) {
    value = flattenMap(value, options.flatMapSeparator);
  }

  return encoder.encode(value);
}

class _ToonEncoder {
  final EncodeOptions options;
  final StringBuffer _buffer = StringBuffer();
  int _indentLevel = 0;

  // Pre-computed indent strings for common depth levels (avoids ' ' * n allocations)
  late final List<String> _indentCache = List.generate(
    16, // Max cached depth
    (level) => ' ' * (options.indent * level),
  );

  _ToonEncoder(this.options);

  String encode(JsonValue value) {
    if (value is Map) {
      _encodeObject(value);
    } else if (value is List) {
      _encodeRootArray(value);
    } else {
      _encodePrimitive(value);
    }

    return _buffer.toString();
  }

  void _encodeObject(Map<dynamic, dynamic> obj, {bool inline = false}) {
    if (obj.isEmpty) return;

    var isFirst = true;
    for (final entry in obj.entries) {
      final key = _encodeKey(entry.key.toString());
      final value = normalizeValue(entry.value);

      if (!inline && !isFirst) _buffer.write('\n');
      isFirst = false;
      if (!inline) _writeIndent();

      _buffer.write(key);

      if (value == null || value is num || value is bool) {
        _buffer.write(': ');
        _encodePrimitive(value);
      } else if (value is String) {
        _buffer.write(': ');
        _encodeString(value);
      } else if (value is List) {
        if (value.isEmpty) {
          _buffer.write('[0]:');
        } else if (_canUseInline(value)) {
          _encodePrimitiveArrayInline(value);
        } else if (_canUseTabular(value)) {
          _encodeTabularArrayInline(value);
        } else {
          _encodeListArrayInline(value);
        }
      } else if (value is Map) {
        _buffer.write(':');
        if (value.isEmpty) {
          // Empty object
        } else {
          _buffer.write('\n');
          _indentLevel++;
          _encodeObject(value);
          _indentLevel--;
        }
      }
    }
  }

  void _encodeRootArray(List list) {
    final length = list.length;
    final marker = options.lengthMarker ?? '';
    final delimMarker = options.delimiterMarker;

    _buffer.write('[$marker$length$delimMarker]:');

    if (list.isEmpty) return;

    if (_canUseInline(list)) {
      _buffer.write(' ');
      _encodePrimitiveArray(list);
    } else if (_canUseTabular(list)) {
      final fields = (list[0] as Map).keys.toList();
      final fieldStr = fields
          .map((f) => _encodeKey(f.toString()))
          .join(options.delimiter);
      _buffer.write('{$fieldStr}:');

      for (final item in list) {
        _buffer.write('\n');
        _writeIndent();
        _encodeTabularRow(item as Map, fields);
      }
    } else {
      for (final item in list) {
        _buffer.write('\n');
        _writeIndent();
        _buffer.write('- ');
        _encodeListItem(item);
      }
    }
  }

  void _encodePrimitiveArrayInline(List list) {
    final length = list.length;
    final marker = options.lengthMarker ?? '';
    final delimMarker = options.delimiterMarker;

    _buffer.write('[$marker$length$delimMarker]: ');
    _encodePrimitiveArray(list);
  }

  void _encodeTabularArrayInline(List list) {
    final length = list.length;
    final marker = options.lengthMarker ?? '';
    final delimMarker = options.delimiterMarker;
    final fields = (list[0] as Map).keys.toList();
    final fieldStr = fields
        .map((f) => _encodeKey(f.toString()))
        .join(options.delimiter);

    _buffer.write('[$marker$length$delimMarker]{$fieldStr}:');

    for (final item in list) {
      _buffer.write('\n');
      _indentLevel++;
      _writeIndent();
      _encodeTabularRow(item as Map, fields);
      _indentLevel--;
    }
  }

  void _encodeListArrayInline(List list) {
    final length = list.length;
    final marker = options.lengthMarker ?? '';
    final delimMarker = options.delimiterMarker;

    _buffer.write('[$marker$length$delimMarker]:');

    for (final item in list) {
      _buffer.write('\n');
      _indentLevel++;
      _writeIndent();
      _buffer.write('- ');
      _encodeListItem(item);
      _indentLevel--;
    }
  }

  void _encodePrimitiveArray(List list) {
    final values = list
        .map((v) {
          final normalized = normalizeValue(v);
          if (normalized is String) {
            return quoteString(normalized, options.delimiter);
          }
          return _primitiveToString(normalized);
        })
        .join(options.delimiter);

    _buffer.write(values);
  }

  void _encodeTabularRow(Map<dynamic, dynamic> obj, List<dynamic> fields) {
    final values = fields
        .map((field) {
          final value = normalizeValue(obj[field]);
          if (value is String) {
            return quoteString(value, options.delimiter);
          }
          return _primitiveToString(value);
        })
        .join(options.delimiter);

    _buffer.write(values);
  }

  void _encodeListItem(dynamic value) {
    final normalized = normalizeValue(value);

    if (normalized is Map) {
      if (normalized.isEmpty) return;

      final entries = normalized.entries.toList();
      final firstEntry = entries[0];
      final key = _encodeKey(firstEntry.key.toString());
      final firstValue = firstEntry.value;

      _buffer.write('$key:');

      if (firstValue == null || firstValue is num || firstValue is bool) {
        _buffer.write(' ');
        _encodePrimitive(firstValue);
      } else if (firstValue is String) {
        _buffer.write(' ');
        _encodeString(firstValue);
      } else if (firstValue is List) {
        if (firstValue.isEmpty) {
          _buffer.write(' [0]:');
        } else if (_canUseInline(firstValue)) {
          _buffer.write(' ');
          _encodePrimitiveArrayInline(firstValue);
        } else if (_canUseTabular(firstValue)) {
          _buffer.write(' ');
          _encodeTabularArrayInline(firstValue);
        } else {
          _buffer.write(' ');
          _encodeListArrayInline(firstValue);
        }
      } else if (firstValue is Map) {
        _buffer.write('\n');
        _indentLevel++;
        _encodeObject(firstValue);
        _indentLevel--;
      }

      if (entries.length > 1) {
        for (var i = 1; i < entries.length; i++) {
          _buffer.write('\n');
          _writeIndent();
          final entry = entries[i];
          final k = _encodeKey(entry.key.toString());
          final v = entry.value;

          _buffer.write('$k:');

          if (v == null || v is num || v is bool) {
            _buffer.write(' ');
            _encodePrimitive(v);
          } else if (v is String) {
            _buffer.write(' ');
            _encodeString(v);
          } else if (v is List) {
            if (v.isEmpty) {
              _buffer.write(' [0]:');
            } else if (_canUseInline(v)) {
              _buffer.write(' ');
              _encodePrimitiveArrayInline(v);
            } else if (_canUseTabular(v)) {
              _buffer.write(' ');
              _encodeTabularArrayInline(v);
            } else {
              _buffer.write(' ');
              _encodeListArrayInline(v);
            }
          } else if (v is Map) {
            _buffer.write('\n');
            _indentLevel++;
            _encodeObject(v);
            _indentLevel--;
          }
        }
      }
    } else if (normalized is List) {
      // Inline array in list
      if (normalized.isEmpty) {
        _buffer.write('[0]:');
      } else if (_canUseInline(normalized)) {
        _encodePrimitiveArrayInline(normalized);
      } else {
        _encodeRootArray(normalized);
      }
    } else {
      _encodePrimitive(normalized);
    }
  }

  void _encodePrimitive(dynamic value) {
    _buffer.write(_primitiveToString(value));
  }

  void _encodeString(String value) {
    _buffer.write(quoteString(value, options.delimiter));
  }

  String _primitiveToString(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value.toString();
    if (value is num) {
      if (value.isNaN || value.isInfinite) return 'null';
      return value.toString();
    }
    return value.toString();
  }

  String _encodeKey(String key) {
    if (isValidIdentifier(key)) return key;
    return '"${escapeString(key)}"';
  }

  bool _canUseInline(List list) {
    if (list.isEmpty) return false;
    return list.every((item) {
      final normalized = normalizeValue(item);
      return normalized == null ||
          normalized is num ||
          normalized is bool ||
          normalized is String;
    });
  }

  bool _canUseTabular(List list) {
    if (list.isEmpty) return false;
    if (list.first is! Map) return false;

    final firstMap = list.first as Map;
    if (firstMap.isEmpty) return false;

    final keyCount = firstMap.keys.length;
    final referenceKeys = firstMap.keys.toList(); // Single list allocation

    for (final item in list) {
      if (item is! Map) return false;
      if (item.keys.length != keyCount) return false; // Fast length check

      for (final key in referenceKeys) {
        if (!item.containsKey(key)) return false; // O(1) lookup
      }

      for (final value in item.values) {
        final normalized = normalizeValue(value);
        if (normalized is Map || normalized is List) return false;
      }
    }

    return true;
  }

  void _writeIndent() {
    if (_indentLevel < _indentCache.length) {
      _buffer.write(_indentCache[_indentLevel]);
    } else {
      _buffer.write(' ' * (options.indent * _indentLevel));
    }
  }
}
