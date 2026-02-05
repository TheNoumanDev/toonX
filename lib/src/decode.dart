import 'options.dart';
import 'types.dart';
import 'utils.dart';

// Cached RegExp patterns to avoid repeated compilation in hot loops
final _arrayKeyPattern = RegExp(r'^(.+?)(\[#?\d+[\t|]?\](?:\{[^}]+\})?)$');
final _arrayHeaderPattern = RegExp(r'^\[#?(\d+)([\t|])?\](?:\{([^}]+)\})?:(.*)$');

/// Decodes a TOON-formatted string back to a Dart value.
///
/// Parses TOON (Token-Oriented Object Notation) format and converts it to
/// standard Dart objects (Maps, Lists, and primitives).
///
/// **Parameters:**
/// - [input]: A TOON-formatted string to parse
/// - [options]: Optional [DecodeOptions] to customize decoding behavior
///
/// **Features:**
/// - Automatic delimiter detection (`,`, `\t`, `|`)
/// - Strict mode for validation (default)
/// - Lenient mode for error tolerance
/// - Flat map reconstruction support
/// - Escape sequence handling
///
/// **Throws:**
/// - [ToonException] in strict mode when validation fails
///
/// See also:
/// - [encode] for converting Dart values to TOON format
/// - [DecodeOptions] for all available decoding options
JsonValue decode(
  String input, {
  DecodeOptions options = const DecodeOptions(),
}) {
  final decoder = _ToonDecoder(input, options);
  final result = decoder.decode();

  if (options.enforceFlatMap && result is Map<String, dynamic>) {
    return unflattenMap(result, options.flatMapSeparator);
  }

  return result;
}

class _ToonDecoder {
  final String input;
  final DecodeOptions options;
  final List<String> _lines;
  int _currentLine = 0;

  _ToonDecoder(this.input, this.options) : _lines = input.split('\n');

  JsonValue decode() {
    if (input.trim().isEmpty) return {};

    // Check if root is an array
    if (_lines.isNotEmpty && _lines[0].startsWith('[')) {
      return _parseRootArray();
    }

    return _parseObject(0);
  }

  JsonValue _parseRootArray() {
    final line = _lines[_currentLine];
    final arrayInfo = _parseArrayHeader(line);

    if (arrayInfo == null) {
      if (options.strict) {
        throw ToonException('Invalid array header at line $_currentLine');
      }
      return [];
    }

    _currentLine++;

    if (arrayInfo['length'] == 0) return [];

    if (arrayInfo['afterColon'].isNotEmpty) {
      // Inline primitive array
      final values = splitByDelimiter(
        arrayInfo['afterColon'],
        arrayInfo['delimiter'],
      );
      return values.map(parseValue).toList();
    } else if (arrayInfo['fields'] != null) {
      return _parseTabularArray(
        arrayInfo['length'],
        arrayInfo['fields'],
        arrayInfo['delimiter'],
        0,
      );
    } else {
      return _parseListArray(arrayInfo['length'], 0);
    }
  }

  Map<String, dynamic> _parseObject(int indentLevel) {
    final result = <String, dynamic>{};

    while (_currentLine < _lines.length) {
      final line = _lines[_currentLine];
      final lineIndent = _getIndent(line);

      if (lineIndent < indentLevel) break;
      if (lineIndent > indentLevel) {
        _currentLine++;
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        _currentLine++;
        continue;
      }

      final colonIndex = _findKeyValueSeparator(trimmed);
      if (colonIndex == -1) {
        _currentLine++;
        continue;
      }

      var keyPart = trimmed.substring(0, colonIndex).trim();
      final afterColon = trimmed.substring(colonIndex + 1).trim();

      // Check if key has array header (e.g., "tags[3]" or "items[2]{id,name}")
      final arrayMatch = _arrayKeyPattern.firstMatch(keyPart);

      if (arrayMatch != null) {
        // Key with inline array header
        final actualKey = unquoteString(arrayMatch.group(1)!.trim());
        final arrayHeader = arrayMatch.group(2)!;
        final fullArrayHeader = '$arrayHeader:$afterColon';
        final arrayInfo = _parseArrayHeader(fullArrayHeader);

        if (arrayInfo != null) {
          _currentLine++;

          if (arrayInfo['length'] == 0) {
            result[actualKey] = [];
          } else if (arrayInfo['afterColon'].isNotEmpty) {
            // Inline primitive array
            final values = splitByDelimiter(
              arrayInfo['afterColon'],
              arrayInfo['delimiter'],
            );
            result[actualKey] = values.map(parseValue).toList();
          } else if (arrayInfo['fields'] != null) {
            // Tabular array on next lines
            result[actualKey] = _parseTabularArray(
              arrayInfo['length'],
              arrayInfo['fields'],
              arrayInfo['delimiter'],
              indentLevel,
            );
          } else {
            // List array on next lines
            result[actualKey] = _parseListArray(
              arrayInfo['length'],
              indentLevel,
            );
          }
        } else {
          result[actualKey] = parseValue(afterColon);
          _currentLine++;
        }
        continue;
      }

      final key = unquoteString(keyPart);

      if (afterColon.isEmpty) {
        _currentLine++;

        // Check if next line is array or nested object
        if (_currentLine < _lines.length) {
          final nextLine = _lines[_currentLine];
          final nextIndent = _getIndent(nextLine);

          if (nextIndent > indentLevel) {
            result[key] = _parseObject(nextIndent);
          } else {
            result[key] = {};
          }
        } else {
          result[key] = {};
        }
      } else if (afterColon.startsWith('[')) {
        // Inline array
        final arrayInfo = _parseArrayHeader(afterColon);
        if (arrayInfo != null) {
          _currentLine++;

          if (arrayInfo['length'] == 0) {
            result[key] = [];
          } else if (arrayInfo['afterColon'].isNotEmpty) {
            // Inline primitive array
            final values = splitByDelimiter(
              arrayInfo['afterColon'],
              arrayInfo['delimiter'],
            );
            result[key] = values.map(parseValue).toList();
          } else if (arrayInfo['fields'] != null) {
            // Tabular array on next lines
            result[key] = _parseTabularArray(
              arrayInfo['length'],
              arrayInfo['fields'],
              arrayInfo['delimiter'],
              indentLevel,
            );
          } else {
            // List array on next lines
            result[key] = _parseListArray(arrayInfo['length'], indentLevel);
          }
        } else {
          result[key] = parseValue(afterColon);
          _currentLine++;
        }
      } else {
        result[key] = parseValue(afterColon);
        _currentLine++;
      }
    }

    return result;
  }

  List<dynamic> _parseTabularArray(
    int length,
    List<String> fields,
    String delimiter,
    int baseIndent,
  ) {
    // Pre-allocate with known capacity
    final result = List<Map<String, dynamic>>.generate(length, (_) => <String, dynamic>{}, growable: false);
    final fieldCount = fields.length;

    for (var i = 0; i < length; i++) {
      if (_currentLine >= _lines.length) {
        if (options.strict) {
          throw ToonException(
            'Array length mismatch: expected $length, got $i',
          );
        }
        return result.sublist(0, i);
      }

      final line = _lines[_currentLine];
      final lineIndent = _getIndent(line);

      if (lineIndent <= baseIndent) {
        if (options.strict) {
          throw ToonException(
            'Array length mismatch: expected $length, got $i',
          );
        }
        return result.sublist(0, i);
      }

      final trimmed = line.trim();
      final values = splitByDelimiter(trimmed, delimiter);

      if (options.strict && values.length != fieldCount) {
        throw ToonException('Field count mismatch at line $_currentLine');
      }

      final row = result[i];
      final valLen = values.length;
      for (var j = 0; j < fieldCount && j < valLen; j++) {
        row[fields[j]] = parseValue(values[j]);
      }

      _currentLine++;
    }

    return result;
  }

  List<dynamic> _parseListArray(int length, int baseIndent) {
    final result = <dynamic>[];

    for (var i = 0; i < length; i++) {
      if (_currentLine >= _lines.length) {
        if (options.strict) {
          throw ToonException(
            'Array length mismatch: expected $length, got $i',
          );
        }
        break;
      }

      final line = _lines[_currentLine];
      final lineIndent = _getIndent(line);

      if (lineIndent <= baseIndent) {
        if (options.strict) {
          throw ToonException(
            'Array length mismatch: expected $length, got $i',
          );
        }
        break;
      }

      final trimmed = line.trim();
      if (!trimmed.startsWith('- ')) {
        if (options.strict) {
          throw ToonException('Expected list item at line $_currentLine');
        }
        _currentLine++;
        continue;
      }

      final afterDash = trimmed.substring(2);

      // Check if it's an inline array
      if (afterDash.startsWith('[')) {
        final arrayInfo = _parseArrayHeader(afterDash);
        if (arrayInfo != null) {
          _currentLine++;
          if (arrayInfo['length'] == 0) {
            result.add([]);
          } else {
            final colonIndex = afterDash.indexOf(':');
            if (colonIndex != -1) {
              final afterColon = afterDash.substring(colonIndex + 1).trim();
              if (afterColon.isNotEmpty) {
                final values = splitByDelimiter(
                  afterColon,
                  arrayInfo['delimiter'],
                );
                result.add(values.map(parseValue).toList());
              } else {
                result.add([]);
              }
            }
          }
          continue;
        }
      }

      // Check if it's an object
      final colonIndex = _findKeyValueSeparator(afterDash);
      if (colonIndex != -1) {
        final obj = <String, dynamic>{};
        final key = unquoteString(afterDash.substring(0, colonIndex).trim());
        final afterColon = afterDash.substring(colonIndex + 1).trim();

        if (afterColon.isEmpty) {
          _currentLine++;

          if (_currentLine < _lines.length) {
            final nextLine = _lines[_currentLine];
            final nextIndent = _getIndent(nextLine);

            if (nextIndent > lineIndent) {
              obj[key] = _parseNestedValue(nextIndent);
            } else {
              obj[key] = {};
            }
          } else {
            obj[key] = {};
          }
        } else if (afterColon.startsWith('[')) {
          // Inline array
          final arrayInfo = _parseArrayHeader(afterColon);
          if (arrayInfo != null) {
            _currentLine++;

            if (arrayInfo['length'] == 0) {
              obj[key] = [];
            } else if (arrayInfo['afterColon'].isNotEmpty) {
              // Inline primitive array
              final values = splitByDelimiter(
                arrayInfo['afterColon'],
                arrayInfo['delimiter'],
              );
              obj[key] = values.map(parseValue).toList();
            } else if (arrayInfo['fields'] != null) {
              // Tabular array on next lines
              obj[key] = _parseTabularArray(
                arrayInfo['length'],
                arrayInfo['fields'],
                arrayInfo['delimiter'],
                lineIndent,
              );
            } else {
              // List array on next lines
              obj[key] = _parseListArray(arrayInfo['length'], lineIndent);
            }
          } else {
            obj[key] = parseValue(afterColon);
            _currentLine++;
          }
        } else {
          obj[key] = parseValue(afterColon);
          _currentLine++;
        }

        // Parse remaining fields at same indent
        while (_currentLine < _lines.length) {
          final nextLine = _lines[_currentLine];
          final nextIndent = _getIndent(nextLine);

          if (nextIndent != lineIndent) break;

          final nextTrimmed = nextLine.trim();
          final nextColonIndex = _findKeyValueSeparator(nextTrimmed);

          if (nextColonIndex == -1) break;

          final nextKey = unquoteString(
            nextTrimmed.substring(0, nextColonIndex).trim(),
          );
          final nextAfterColon = nextTrimmed
              .substring(nextColonIndex + 1)
              .trim();

          if (nextAfterColon.isEmpty) {
            _currentLine++;

            if (_currentLine < _lines.length) {
              final nestedIndent = _getIndent(_lines[_currentLine]);
              if (nestedIndent > lineIndent) {
                obj[nextKey] = _parseNestedValue(nestedIndent);
              } else {
                obj[nextKey] = {};
              }
            } else {
              obj[nextKey] = {};
            }
          } else if (nextAfterColon.startsWith('[')) {
            // Inline array
            final arrayInfo = _parseArrayHeader(nextAfterColon);
            if (arrayInfo != null) {
              _currentLine++;

              if (arrayInfo['length'] == 0) {
                obj[nextKey] = [];
              } else if (arrayInfo['afterColon'].isNotEmpty) {
                // Inline primitive array
                final values = splitByDelimiter(
                  arrayInfo['afterColon'],
                  arrayInfo['delimiter'],
                );
                obj[nextKey] = values.map(parseValue).toList();
              } else if (arrayInfo['fields'] != null) {
                // Tabular array on next lines
                obj[nextKey] = _parseTabularArray(
                  arrayInfo['length'],
                  arrayInfo['fields'],
                  arrayInfo['delimiter'],
                  lineIndent,
                );
              } else {
                // List array on next lines
                obj[nextKey] = _parseListArray(arrayInfo['length'], lineIndent);
              }
            } else {
              obj[nextKey] = parseValue(nextAfterColon);
              _currentLine++;
            }
          } else {
            obj[nextKey] = parseValue(nextAfterColon);
            _currentLine++;
          }
        }

        result.add(obj);
      } else {
        result.add(parseValue(afterDash));
        _currentLine++;
      }
    }

    return result;
  }

  dynamic _parseNestedValue(int indentLevel) {
    if (_currentLine >= _lines.length) return null;

    final line = _lines[_currentLine];
    final trimmed = line.trim();

    if (trimmed.startsWith('[')) {
      final arrayInfo = _parseArrayHeader(trimmed);
      if (arrayInfo != null) {
        _currentLine++;
        if (arrayInfo['length'] == 0) {
          return [];
        } else if (arrayInfo['fields'] != null) {
          return _parseTabularArray(
            arrayInfo['length'],
            arrayInfo['fields'],
            arrayInfo['delimiter'],
            indentLevel,
          );
        } else {
          return _parseListArray(arrayInfo['length'], indentLevel);
        }
      }
    }

    return _parseObject(indentLevel);
  }

  Map<String, dynamic>? _parseArrayHeader(String line) {
    final match = _arrayHeaderPattern.firstMatch(line);

    if (match == null) return null;

    final length = int.parse(match.group(1)!);
    final delimMarker = match.group(2) ?? ',';
    final fieldsStr = match.group(3);
    final afterColon = match.group(4)?.trim() ?? '';

    String delimiter = ',';
    if (delimMarker == '\t') {
      delimiter = '\t';
    } else if (delimMarker == '|') {
      delimiter = '|';
    }

    List<String>? fields;
    if (fieldsStr != null) {
      fields = splitByDelimiter(
        fieldsStr,
        delimiter,
      ).map((f) => unquoteString(f.trim())).toList();
    }

    return {
      'length': length,
      'delimiter': delimiter,
      'fields': fields,
      'afterColon': afterColon,
    };
  }

  int _findKeyValueSeparator(String line) {
    var inQuotes = false;
    var escapeNext = false;
    final len = line.length;

    for (var i = 0; i < len; i++) {
      final c = line.codeUnitAt(i);

      if (escapeNext) {
        escapeNext = false;
        continue;
      }

      if (c == 0x5C) {
        // backslash
        escapeNext = true;
        continue;
      }

      if (c == 0x22) {
        // quote
        inQuotes = !inQuotes;
        continue;
      }

      if (!inQuotes && c == 0x3A) {
        // colon
        return i;
      }
    }

    return -1;
  }

  int _getIndent(String line) {
    var count = 0;
    final len = line.length;
    for (var i = 0; i < len; i++) {
      if (line.codeUnitAt(i) == 0x20) {
        // space
        count++;
      } else {
        break;
      }
    }
    return count ~/ options.indent;
  }
}
