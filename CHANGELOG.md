## 1.3.0

-   **Removed Flutter dependency**: Now works in pure Dart environments (server-side, CLI, etc.)
-   **Major performance improvements**: 2.2x faster round-trip (encode+decode)
-   Encoder optimized: 59% faster (133ms → 55ms for 1000 records)
-   Decoder optimized: 45% faster (120ms → 66ms for 1000 records)
-   Cached RegExp patterns to avoid repeated compilation in hot loops
-   Eliminated Set allocations in tabular format detection
-   Optimized string escaping/unescaping with early-exit fast paths
-   Replaced regex-based identifier validation with character code checks
-   Added fast number detection without parsing overhead
-   Optimized comma splitting with substring instead of StringBuffer
-   Pre-allocated arrays with known sizes in decoder
-   Used code units for character scanning (avoids 1-char String allocations)
-   Cached indent strings in encoder (avoids repeated `' ' * n`)
-   Added benchmark test for performance tracking

## 1.2.0

-   Added XML support with `xmlToToon()` and `toonToXml()` functions
-   XML conversion powered by the xml2json package
-   Support for Parker convention (lightweight, ideal for LLMs)
-   Support for Badgerfish convention (preserves attributes and namespaces)
-   CLI now supports XML files (.xml) with auto-detection
-   Added 26 comprehensive tests for XML conversion
-   Updated README with XML examples and proper credits
-   Total test count: 105+ tests

## 1.1.0

-   Added YAML support with `yamlToToon()` and `toonToYaml()` functions
-   CLI now supports YAML files (.yaml, .yml) with auto-detection
-   Added 33 comprehensive tests for YAML conversion
-   Updated README with YAML examples and usage guide
-   Total test count: 79+ tests

## 1.0.1

-   Fixed LICENSE file to comply with pub.dev requirements
-   Reduced topics to 5 for pub.dev compliance
-   Updated README with Credits & Reference section
-   Added comprehensive contribution guidelines
-   Minor documentation improvements

## 1.0.0

-   Initial release
-   `encode()` function to convert Dart objects to TOON format
-   `decode()` function to parse TOON strings back to Dart objects
-   Custom delimiters support: comma, tab, and pipe
-   Length marker option for array validation
-   Custom indentation configuration
-   Tabular array format for uniform objects
-   Flat map mode for flattening nested structures
-   Strict mode validation for decoding
-   Lenient mode for best-effort parsing
-   CLI tool for encoding and decoding files
-   Stdin/stdout support for piping
-   Auto-detection of format by file extension
