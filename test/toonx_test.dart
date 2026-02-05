import 'package:test/test.dart';
import 'package:toonx/toonx.dart';

void main() {
  group('Encode Tests', () {
    test('encode simple object', () {
      final data = {'id': 1, 'name': 'Alice', 'active': true};
      final result = encode(data);
      expect(result, 'id: 1\nname: Alice\nactive: true');
    });

    test('encode nested object', () {
      final data = {
        'user': {'id': 1, 'name': 'Alice'},
      };
      final result = encode(data);
      expect(result, 'user:\n  id: 1\n  name: Alice');
    });

    test('encode primitive array', () {
      final data = {
        'tags': ['admin', 'ops', 'dev'],
      };
      final result = encode(data);
      expect(result, 'tags[3]: admin,ops,dev');
    });

    test('encode tabular array', () {
      final data = {
        'items': [
          {'id': 1, 'qty': 5},
          {'id': 2, 'qty': 3},
        ],
      };
      final result = encode(data);
      expect(result, 'items[2]{id,qty}:\n  1,5\n  2,3');
    });

    test('encode mixed array', () {
      final data = {
        'items': [
          1,
          {'a': 1},
          'x',
        ],
      };
      final result = encode(data);
      expect(result, 'items[3]:\n  - 1\n  - a: 1\n  - x');
    });

    test('encode empty array', () {
      final data = {'items': []};
      final result = encode(data);
      expect(result, 'items[0]:');
    });

    test('encode empty object', () {
      final data = {};
      final result = encode(data);
      expect(result, '');
    });

    test('encode root array', () {
      final data = ['x', 'y', 'z'];
      final result = encode(data);
      expect(result, '[3]: x,y,z');
    });
  });

  group('Delimiter Options Tests', () {
    test('encode with tab delimiter', () {
      final data = {
        'items': [
          {'id': 1, 'name': 'Widget'},
          {'id': 2, 'name': 'Gadget'},
        ],
      };
      final result = encode(data, options: EncodeOptions(delimiter: '\t'));
      expect(result, 'items[2\t]{id\tname}:\n  1\tWidget\n  2\tGadget');
    });

    test('encode with pipe delimiter', () {
      final data = {
        'tags': ['a', 'b', 'c'],
      };
      final result = encode(data, options: EncodeOptions(delimiter: '|'));
      expect(result, 'tags[3|]: a|b|c');
    });
  });

  group('Length Marker Tests', () {
    test('encode with length marker', () {
      final data = {
        'tags': ['a', 'b', 'c'],
      };
      final result = encode(data, options: EncodeOptions(lengthMarker: '#'));
      expect(result, 'tags[#3]: a,b,c');
    });

    test('encode tabular with length marker', () {
      final data = {
        'items': [
          {'id': 1},
          {'id': 2},
        ],
      };
      final result = encode(data, options: EncodeOptions(lengthMarker: '#'));
      expect(result, 'items[#2]{id}:\n  1\n  2');
    });
  });

  group('Custom Indentation Tests', () {
    test('encode with 4-space indent', () {
      final data = {
        'user': {'id': 1, 'name': 'Alice'},
      };
      final result = encode(data, options: EncodeOptions(indent: 4));
      expect(result, 'user:\n    id: 1\n    name: Alice');
    });
  });

  group('Quoting Rules Tests', () {
    test('quote empty string', () {
      final data = {'key': ''};
      final result = encode(data);
      expect(result, 'key: ""');
    });

    test('quote string with leading space', () {
      final data = {'key': ' padded'};
      final result = encode(data);
      expect(result, 'key: " padded"');
    });

    test('quote string with comma', () {
      final data = {'key': 'a,b'};
      final result = encode(data);
      expect(result, 'key: "a,b"');
    });

    test('quote string with colon', () {
      final data = {'key': 'a:b'};
      final result = encode(data);
      expect(result, 'key: "a:b"');
    });

    test('quote boolean-like string', () {
      final data = {'key': 'true'};
      final result = encode(data);
      expect(result, 'key: "true"');
    });

    test('do not quote unicode', () {
      final data = {'key': 'hello 👋 world'};
      final result = encode(data);
      expect(result, 'key: hello 👋 world');
    });

    test('quote key with special chars', () {
      final data = {'user name': 'Alice'};
      final result = encode(data);
      expect(result, '"user name": Alice');
    });
  });

  group('Flat Map Tests', () {
    test('flatten nested map on encode', () {
      final data = {
        'a': {
          'b': {'c': 1},
        },
      };
      final result = encode(
        data,
        options: EncodeOptions(enforceFlatMap: true, flatMapSeparator: '_'),
      );
      expect(result, 'a_b_c: 1');
    });

    test('flatten with custom separator', () {
      final data = {
        'a': {
          'b': {'c': 1},
        },
      };
      final result = encode(
        data,
        options: EncodeOptions(enforceFlatMap: true, flatMapSeparator: '.'),
      );
      expect(result, 'a.b.c: 1');
    });

    test('unflatten map on decode', () {
      final toon = 'a_b_c: 1';
      final result = decode(
        toon,
        options: DecodeOptions(enforceFlatMap: true, flatMapSeparator: '_'),
      );
      expect(result, {
        'a': {
          'b': {'c': 1},
        },
      });
    });
  });

  group('Decode Tests', () {
    test('decode simple object', () {
      final toon = 'id: 1\nname: Alice\nactive: true';
      final result = decode(toon);
      expect(result, {'id': 1, 'name': 'Alice', 'active': true});
    });

    test('decode nested object', () {
      final toon = 'user:\n  id: 1\n  name: Alice';
      final result = decode(toon);
      expect(result, {
        'user': {'id': 1, 'name': 'Alice'},
      });
    });

    test('decode primitive array', () {
      final toon = 'tags[3]: admin,ops,dev';
      final result = decode(toon);
      expect(result, {
        'tags': ['admin', 'ops', 'dev'],
      });
    });

    test('decode tabular array', () {
      final toon = 'items[2]{id,qty}:\n  1,5\n  2,3';
      final result = decode(toon);
      expect(result, {
        'items': [
          {'id': 1, 'qty': 5},
          {'id': 2, 'qty': 3},
        ],
      });
    });

    test('decode empty array', () {
      final toon = 'items[0]:';
      final result = decode(toon);
      expect(result, {'items': []});
    });

    test('decode root array', () {
      final toon = '[3]: x,y,z';
      final result = decode(toon);
      expect(result, ['x', 'y', 'z']);
    });

    test('decode with tab delimiter', () {
      final toon = 'items[2\t]{id\tname}:\n  1\tWidget\n  2\tGadget';
      final result = decode(toon);
      expect(result, {
        'items': [
          {'id': 1, 'name': 'Widget'},
          {'id': 2, 'name': 'Gadget'},
        ],
      });
    });

    test('decode with pipe delimiter', () {
      final toon = 'tags[3|]: a|b|c';
      final result = decode(toon);
      expect(result, {
        'tags': ['a', 'b', 'c'],
      });
    });

    test('decode quoted strings', () {
      final toon = 'key: "hello, world"';
      final result = decode(toon);
      expect(result, {'key': 'hello, world'});
    });

    test('decode escaped strings', () {
      final toon = r'key: "line1\nline2"';
      final result = decode(toon);
      expect(result, {'key': 'line1\nline2'});
    });
  });

  group('Strict Mode Tests', () {
    test('strict mode throws on array length mismatch', () {
      final toon = 'items[3]{id,name}:\n  1,Alice';
      expect(
        () => decode(toon, options: DecodeOptions(strict: true)),
        throwsA(isA<ToonException>()),
      );
    });

    test('lenient mode allows array length mismatch', () {
      final toon = 'items[3]: a,b';
      final result = decode(toon, options: DecodeOptions(strict: false));
      expect(result, {
        'items': ['a', 'b'],
      });
    });
  });

  group('Edge Cases', () {
    test('encode null values', () {
      final data = {'key': null};
      final result = encode(data);
      expect(result, 'key: null');
    });

    test('encode numbers', () {
      final data = {'int': 42, 'double': 3.14, 'negative': -5};
      final result = encode(data);
      expect(result, 'int: 42\ndouble: 3.14\nnegative: -5');
    });

    test('encode array of arrays', () {
      final data = {
        'pairs': [
          [1, 2],
          [3, 4],
        ],
      };
      final result = encode(data);
      expect(result, 'pairs[2]:\n  - [2]: 1,2\n  - [2]: 3,4');
    });

    test('roundtrip encode and decode', () {
      final data = {
        'users': [
          {'id': 1, 'name': 'Alice', 'role': 'admin'},
          {'id': 2, 'name': 'Bob', 'role': 'user'},
        ],
        'settings': {'theme': 'dark', 'notifications': true},
      };

      final toon = encode(data);
      final decoded = decode(toon);
      expect(decoded, data);
    });
  });
}
