/// Utility classes and functions for TOON encoding/decoding operations.
library;

// Character code constants for fast comparisons
const _kBackslash = 0x5C; // \
const _kQuote = 0x22; // "
const _kNewline = 0x0A; // \n
const _kCarriageReturn = 0x0D; // \r
const _kTab = 0x09; // \t
const _kSpace = 0x20; // space
const _kColon = 0x3A; // :
const _kComma = 0x2C; // ,
const _kPipe = 0x7C; // |
const _kOpenBracket = 0x5B; // [
const _kCloseBracket = 0x5D; // ]
const _kOpenBrace = 0x7B; // {
const _kCloseBrace = 0x7D; // }
const _kDash = 0x2D; // -
const _kUnderscore = 0x5F; // _
const _kDot = 0x2E; // .
const _k0 = 0x30; // 0
const _k9 = 0x39; // 9
const _kA = 0x41; // A
const _kZ = 0x5A; // Z
const _ka = 0x61; // a
const _kz = 0x7A; // z

/// Exception thrown during TOON encoding or decoding operations.
///
/// This exception is thrown when:
/// - Invalid TOON syntax is encountered (strict mode)
/// - Array length mismatches occur (strict mode)
/// - Delimiter inconsistencies are found (strict mode)
/// - Invalid escape sequences are encountered
class ToonException implements Exception {
  /// The error message describing what went wrong.
  final String message;

  /// Creates a new TOON exception with the given error message.
  ToonException(this.message);

  @override
  String toString() => 'ToonException: $message';
}

// ============================================================================
// String Manipulation Utilities
// ============================================================================

/// Escapes special characters in a string for TOON format.
///
/// Escapes: backslash, quotes, newlines, carriage returns, tabs
String escapeString(String value) {
  // Fast path: check if escaping needed (avoids allocations for common case)
  var needsEscape = false;
  for (var i = 0; i < value.length; i++) {
    final c = value.codeUnitAt(i);
    // Check for: \ (0x5C), " (0x22), \n (0x0A), \r (0x0D), \t (0x09)
    if (c == 0x5C || c == 0x22 || c == 0x0A || c == 0x0D || c == 0x09) {
      needsEscape = true;
      break;
    }
  }
  if (!needsEscape) return value; // No allocation!

  // Slow path: build escaped string
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final c = value.codeUnitAt(i);
    switch (c) {
      case _kBackslash:
        buffer.write('\\\\');
      case _kQuote:
        buffer.write('\\"');
      case _kNewline:
        buffer.write('\\n');
      case _kCarriageReturn:
        buffer.write('\\r');
      case _kTab:
        buffer.write('\\t');
      default:
        buffer.writeCharCode(c);
    }
  }
  return buffer.toString();
}

/// Unescapes special characters from a TOON string.
///
/// Reverses the escaping done by [escapeString]
String unescapeString(String value) {
  // Fast path: check if unescaping needed
  if (!value.contains('\\')) return value; // No allocation!

  // Slow path: build unescaped string
  final buffer = StringBuffer();
  final len = value.length;
  var i = 0;
  while (i < len) {
    final c = value.codeUnitAt(i);
    if (c == _kBackslash && i + 1 < len) {
      final next = value.codeUnitAt(i + 1);
      switch (next) {
        case 0x6E: // n
          buffer.writeCharCode(_kNewline);
          i += 2;
        case 0x72: // r
          buffer.writeCharCode(_kCarriageReturn);
          i += 2;
        case 0x74: // t
          buffer.writeCharCode(_kTab);
          i += 2;
        case _kQuote:
          buffer.writeCharCode(_kQuote);
          i += 2;
        case _kBackslash:
          buffer.writeCharCode(_kBackslash);
          i += 2;
        default:
          buffer.writeCharCode(c);
          i++;
      }
    } else {
      buffer.writeCharCode(c);
      i++;
    }
  }
  return buffer.toString();
}

/// Quotes a string if necessary for TOON format.
///
/// Adds quotes around strings that contain special characters or
/// look like other data types (numbers, booleans, etc.)
String quoteString(String value, String delimiter) {
  if (needsQuoting(value, delimiter)) {
    return '"${escapeString(value)}"';
  }
  return value;
}

/// Removes quotes from a TOON string if present.
///
/// Also unescapes any escape sequences in the string
String unquoteString(String value) {
  // Find actual content bounds (skip leading/trailing whitespace)
  var start = 0;
  var end = value.length;

  while (start < end && value.codeUnitAt(start) == _kSpace) {
    start++;
  }
  while (end > start && value.codeUnitAt(end - 1) == _kSpace) {
    end--;
  }

  final len = end - start;
  if (len >= 2 &&
      value.codeUnitAt(start) == _kQuote &&
      value.codeUnitAt(end - 1) == _kQuote) {
    return unescapeString(value.substring(start + 1, end - 1));
  }

  return start == 0 && end == value.length ? value : value.substring(start, end);
}

/// Checks if a string needs to be quoted in TOON format.
///
/// Returns true if the string:
/// - Is empty
/// - Has leading/trailing spaces
/// - Contains the delimiter, colon, quotes, or control chars
/// - Looks like a boolean, number, or null
/// - Starts with "- " (list marker)
/// - Looks like a structural token ([, {)
bool needsQuoting(String value, String delimiter) {
  final len = value.length;
  if (len == 0) return true;

  // Check leading/trailing spaces
  if (value.codeUnitAt(0) == _kSpace || value.codeUnitAt(len - 1) == _kSpace) {
    return true;
  }

  // Check for "- " prefix (list marker)
  if (len >= 2 && value.codeUnitAt(0) == _kDash && value.codeUnitAt(1) == _kSpace) {
    return true;
  }

  // Check for structural tokens [...]  or {...}
  if (len >= 2) {
    final first = value.codeUnitAt(0);
    final last = value.codeUnitAt(len - 1);
    if ((first == _kOpenBracket && last == _kCloseBracket) ||
        (first == _kOpenBrace && last == _kCloseBrace)) {
      return true;
    }
  }

  // Check for reserved words
  if (value == 'true' || value == 'false' || value == 'null') return true;

  // Check for number-like values
  if (_looksLikeNumberFast(value)) return true;

  // Get delimiter code for comparison
  final delimCode = delimiter.codeUnitAt(0);

  // Single pass for special characters
  for (var i = 0; i < len; i++) {
    final c = value.codeUnitAt(i);
    if (c == delimCode ||
        c == _kColon ||
        c == _kQuote ||
        c == _kBackslash ||
        c == _kNewline ||
        c == _kCarriageReturn ||
        c == _kTab) {
      return true;
    }
  }

  return false;
}

/// Fast number detection without parsing
bool _looksLikeNumberFast(String value) {
  final len = value.length;
  if (len == 0) return false;

  var i = 0;
  var c = value.codeUnitAt(i);

  // Optional sign
  if (c == _kDash || c == 0x2B) {
    // - or +
    i++;
    if (i >= len) return false;
    c = value.codeUnitAt(i);
  }

  // Must start with digit
  if (c < _k0 || c > _k9) return false;

  // Check rest - allow digits, one dot, one e/E
  var hasDot = false;
  var hasExp = false;
  while (i < len) {
    c = value.codeUnitAt(i);
    if (c >= _k0 && c <= _k9) {
      i++;
    } else if (c == _kDot && !hasDot && !hasExp) {
      hasDot = true;
      i++;
    } else if ((c == 0x65 || c == 0x45) && !hasExp) {
      // e or E
      hasExp = true;
      i++;
      if (i < len) {
        c = value.codeUnitAt(i);
        if (c == _kDash || c == 0x2B) i++; // optional sign after e
      }
    } else {
      return false;
    }
  }
  return true;
}

/// Checks if a string looks like a number.
bool looksLikeNumber(String value) {
  return _looksLikeNumberFast(value);
}

/// Checks if a string is a valid TOON identifier.
///
/// Valid identifiers:
/// - Start with a letter or underscore
/// - Contain only letters, digits, underscores, or dots
bool isValidIdentifier(String key) {
  final len = key.length;
  if (len == 0) return false;

  // First char must be letter or underscore
  final first = key.codeUnitAt(0);
  if (!_isLetter(first) && first != _kUnderscore) return false;

  // Rest must be letter, digit, underscore, or dot
  for (var i = 1; i < len; i++) {
    final c = key.codeUnitAt(i);
    if (!_isLetter(c) && !_isDigit(c) && c != _kUnderscore && c != _kDot) {
      return false;
    }
  }
  return true;
}

bool _isLetter(int c) => (c >= _kA && c <= _kZ) || (c >= _ka && c <= _kz);
bool _isDigit(int c) => c >= _k0 && c <= _k9;

// ============================================================================
// Value Normalization and Parsing
// ============================================================================

/// Normalizes a value for TOON encoding.
///
/// Converts:
/// - NaN/Infinity to null
/// - DateTime to ISO string
/// - Other types pass through unchanged
dynamic normalizeValue(dynamic value) {
  if (value is num) {
    if (value.isNaN || value.isInfinite) return null;
    return value;
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  return value;
}

/// Parses a string value to its appropriate Dart type.
///
/// Handles: null, booleans, numbers, and strings
dynamic parseValue(String value) {
  // Fast trim using indices
  var start = 0;
  var end = value.length;

  while (start < end && value.codeUnitAt(start) == _kSpace) {
    start++;
  }
  while (end > start && value.codeUnitAt(end - 1) == _kSpace) {
    end--;
  }

  final len = end - start;
  if (len == 0) return null;

  // Check for null/true/false by length first (fast rejection)
  if (len == 4) {
    final s = value.substring(start, end);
    if (s == 'null') return null;
    if (s == 'true') return true;
  } else if (len == 5) {
    if (value.substring(start, end) == 'false') return false;
  }

  // Get the trimmed substring only once
  final trimmed = start == 0 && end == value.length
      ? value
      : value.substring(start, end);

  // Try number (use num.tryParse for accuracy with edge cases)
  final numValue = num.tryParse(trimmed);
  if (numValue != null) return numValue;

  // String (will be unquoted)
  return unquoteString(trimmed);
}

// ============================================================================
// Delimiter Splitting Utilities
// ============================================================================

/// Splits a string by the specified delimiter.
///
/// Handles quoted strings properly (doesn't split inside quotes)
List<String> splitByDelimiter(String value, String delimiter) {
  if (delimiter == ',') {
    return splitByComma(value);
  } else if (delimiter == '\t') {
    return value.split('\t');
  } else if (delimiter == '|') {
    return value.split('|');
  }
  return [value];
}

/// Splits a string by commas, respecting quoted strings.
///
/// Does not split on commas inside quoted strings
List<String> splitByComma(String value) {
  final result = <String>[];
  final len = value.length;
  var start = 0;
  var inQuotes = false;
  var escapeNext = false;

  for (var i = 0; i < len; i++) {
    final c = value.codeUnitAt(i);

    if (escapeNext) {
      escapeNext = false;
      continue;
    }

    if (c == _kBackslash) {
      escapeNext = true;
      continue;
    }

    if (c == _kQuote) {
      inQuotes = !inQuotes;
      continue;
    }

    if (!inQuotes && c == _kComma) {
      result.add(value.substring(start, i));
      start = i + 1;
    }
  }

  result.add(value.substring(start));
  return result;
}

// ============================================================================
// Map Flattening Utilities
// ============================================================================

/// Flattens a nested map into a single-level map with compound keys.
///
/// Converts: `{'a': {'b': {'c': 1}}}` to `{'a_b_c': 1}`
Map<String, dynamic> flattenMap(
  Map<String, dynamic> map,
  String separator, [
  String prefix = '',
]) {
  final result = <String, dynamic>{};

  for (final entry in map.entries) {
    final key = prefix.isEmpty ? entry.key : '$prefix$separator${entry.key}';
    final value = entry.value;

    if (value is Map<String, dynamic> && value.isNotEmpty) {
      result.addAll(flattenMap(value, separator, key));
    } else {
      result[key] = value;
    }
  }

  return result;
}

/// Reconstructs a nested map from flattened keys.
///
/// Converts: `{'a_b_c': 1}` to `{'a': {'b': {'c': 1}}}`
Map<String, dynamic> unflattenMap(Map<String, dynamic> flat, String separator) {
  final result = <String, dynamic>{};

  for (final entry in flat.entries) {
    final parts = entry.key.split(separator);
    dynamic current = result;

    for (var i = 0; i < parts.length - 1; i++) {
      current.putIfAbsent(parts[i], () => <String, dynamic>{});
      current = current[parts[i]];
    }

    current[parts.last] = entry.value;
  }

  return result;
}
