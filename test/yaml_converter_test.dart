import 'package:test/test.dart';
import 'package:toonx/toonx.dart';

void main() {
  group('YAML to TOON Tests', () {
    test('convert simple YAML object to TOON', () {
      final yaml = '''
name: Alice
age: 30
active: true
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('name: Alice'));
      expect(toon, contains('age: 30'));
      expect(toon, contains('active: true'));
    });

    test('convert nested YAML object to TOON', () {
      final yaml = '''
person:
  name: Bob
  contact:
    email: bob@example.com
    phone: "123-456-7890"
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('person:'));
      expect(toon, contains('name: Bob'));
      expect(toon, contains('contact:'));
      expect(toon, contains('email: bob@example.com'));
    });

    test('convert YAML array to TOON', () {
      final yaml = '''
tags:
  - admin
  - developer
  - ops
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('tags[3]:'));
      expect(toon, contains('admin'));
      expect(toon, contains('developer'));
      expect(toon, contains('ops'));
    });

    test('convert YAML with tabular array to TOON', () {
      final yaml = '''
users:
  - id: 1
    name: Alice
    role: admin
  - id: 2
    name: Bob
    role: user
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('users[2]{id,name,role}:'));
      expect(toon, contains('1,Alice,admin'));
      expect(toon, contains('2,Bob,user'));
    });

    test('convert empty YAML object to TOON', () {
      final yaml = '{}';
      final toon = yamlToToon(yaml);
      expect(toon.trim(), isEmpty);
    });

    test('convert empty YAML array to TOON', () {
      final yaml = '''
items: []
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('items[0]:'));
    });

    test('convert YAML with null values to TOON', () {
      final yaml = '''
name: Alice
middleName: null
age: 30
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('name: Alice'));
      expect(toon, contains('middleName: null'));
      expect(toon, contains('age: 30'));
    });

    test('convert YAML with numbers to TOON', () {
      final yaml = '''
integer: 42
float: 3.14
negative: -10
scientific: 1.5e10
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('integer: 42'));
      expect(toon, contains('float: 3.14'));
      expect(toon, contains('negative: -10'));
    });

    test('convert YAML with booleans to TOON', () {
      final yaml = '''
active: true
verified: false
enabled: yes
disabled: no
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('active: true'));
      expect(toon, contains('verified: false'));
    });

    test('convert YAML with special characters to TOON', () {
      final yaml = '''
message: "Hello, World!"
quote: "She said \\"Hello\\""
multiline: "Line 1\\nLine 2"
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('message:'));
      expect(toon, contains('quote:'));
      expect(toon, contains('multiline:'));
    });

    test('convert complex nested YAML to TOON', () {
      final yaml = '''
config:
  database:
    host: localhost
    port: 5432
    credentials:
      user: admin
      password: secret
  cache:
    enabled: true
    ttl: 3600
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('config:'));
      expect(toon, contains('database:'));
      expect(toon, contains('host: localhost'));
      expect(toon, contains('port: 5432'));
      expect(toon, contains('credentials:'));
      expect(toon, contains('cache:'));
      expect(toon, contains('enabled: true'));
    });

    test('convert YAML with custom delimiter option', () {
      final yaml = '''
tags:
  - admin
  - ops
  - dev
''';
      final toon = yamlToToon(yaml, options: EncodeOptions(delimiter: '\t'));
      expect(toon, contains('tags[3\t]:'));
    });

    test('convert YAML with length marker option', () {
      final yaml = '''
items:
  - apple
  - banana
  - cherry
''';
      final toon = yamlToToon(yaml, options: EncodeOptions(lengthMarker: '#'));
      expect(toon, contains('items[#3]:'));
    });

    test('throw FormatException on invalid YAML', () {
      final invalidYaml = '''
name: Alice
  age: 30
invalid indentation
''';
      expect(() => yamlToToon(invalidYaml), throwsFormatException);
    });
  });

  group('TOON to YAML Tests', () {
    test('convert simple TOON to YAML', () {
      final toon = '''
name: Alice
age: 30
active: true
''';
      final yaml = toonToYaml(toon);
      expect(yaml, contains('name: Alice'));
      expect(yaml, contains('age: 30'));
      expect(yaml, contains('active: true'));
    });

    test('convert nested TOON to YAML', () {
      final toon = '''
person:
  name: Bob
  contact:
    email: bob@example.com
    phone: 123-456-7890
''';
      final yaml = toonToYaml(toon);
      expect(yaml, contains('person:'));
      expect(yaml, contains('name: Bob'));
      expect(yaml, contains('contact:'));
      expect(yaml, contains('email: bob@example.com'));
    });

    test('convert TOON array to YAML', () {
      final toon = 'tags[3]: admin,developer,ops';
      final yaml = toonToYaml(toon);
      expect(yaml, contains('tags:'));
      expect(yaml, contains('- admin'));
      expect(yaml, contains('- developer'));
      expect(yaml, contains('- ops'));
    });

    test('convert TOON tabular array to YAML', () {
      final toon = '''
users[2]{id,name,role}:
  1,Alice,admin
  2,Bob,user
''';
      final yaml = toonToYaml(toon);
      expect(yaml, contains('users:'));
      expect(yaml, contains('id: 1'));
      expect(yaml, contains('name: Alice'));
      expect(yaml, contains('role: admin'));
    });

    test('convert empty TOON to YAML', () {
      final toon = '';
      final yaml = toonToYaml(toon);
      expect(yaml, equals('{}\n'));
    });

    test('convert TOON with null values to YAML', () {
      final toon = '''
name: Alice
middleName: null
age: 30
''';
      final yaml = toonToYaml(toon);
      expect(yaml, contains('name: Alice'));
      expect(yaml, contains('middleName: null'));
      expect(yaml, contains('age: 30'));
    });

    test('convert TOON with numbers to YAML', () {
      final toon = '''
integer: 42
float: 3.14
negative: -10
''';
      final yaml = toonToYaml(toon);
      expect(yaml, contains('integer: 42'));
      expect(yaml, contains('float: 3.14'));
      expect(yaml, contains('negative: -10'));
    });

    test('convert TOON with booleans to YAML', () {
      final toon = '''
active: true
verified: false
''';
      final yaml = toonToYaml(toon);
      expect(yaml, contains('active: true'));
      expect(yaml, contains('verified: false'));
    });

    test('convert TOON with quoted strings to YAML', () {
      final toon = '''
message: "Hello, World!"
quote: "She said \\"Hello\\""
''';
      final yaml = toonToYaml(toon);
      expect(yaml, contains('message:'));
      expect(yaml, contains('quote:'));
    });

    test('convert TOON empty array to YAML', () {
      final toon = 'items[0]:';
      final yaml = toonToYaml(toon);
      expect(yaml, contains('items: []'));
    });
  });

  group('YAML ↔ TOON Round-trip Tests', () {
    test('round-trip simple object', () {
      final yaml = '''
name: Alice
age: 30
active: true
''';
      final toon = yamlToToon(yaml);
      final yamlRestored = toonToYaml(toon);

      // Verify data integrity
      expect(yamlRestored, contains('name: Alice'));
      expect(yamlRestored, contains('age: 30'));
      expect(yamlRestored, contains('active: true'));
    });

    test('round-trip nested object', () {
      final yaml = '''
person:
  name: Bob
  contact:
    email: bob@example.com
''';
      final toon = yamlToToon(yaml);
      final yamlRestored = toonToYaml(toon);

      expect(yamlRestored, contains('person:'));
      expect(yamlRestored, contains('name: Bob'));
      expect(yamlRestored, contains('contact:'));
      expect(yamlRestored, contains('email: bob@example.com'));
    });

    test('round-trip array', () {
      final yaml = '''
tags:
  - admin
  - developer
  - ops
''';
      final toon = yamlToToon(yaml);
      final yamlRestored = toonToYaml(toon);

      expect(yamlRestored, contains('tags:'));
      expect(yamlRestored, contains('- admin'));
      expect(yamlRestored, contains('- developer'));
      expect(yamlRestored, contains('- ops'));
    });

    test('round-trip complex nested structure', () {
      final yaml = '''
config:
  database:
    host: localhost
    port: 5432
  cache:
    enabled: true
    ttl: 3600
  servers:
    - name: server1
      ip: 192.168.1.1
    - name: server2
      ip: 192.168.1.2
''';
      final toon = yamlToToon(yaml);
      final yamlRestored = toonToYaml(toon);

      expect(yamlRestored, contains('config:'));
      expect(yamlRestored, contains('database:'));
      expect(yamlRestored, contains('host: localhost'));
      expect(yamlRestored, contains('cache:'));
      expect(yamlRestored, contains('servers:'));
    });

    test('round-trip with null values', () {
      final yaml = '''
name: Alice
middleName: null
age: 30
''';
      final toon = yamlToToon(yaml);
      final yamlRestored = toonToYaml(toon);

      expect(yamlRestored, contains('name: Alice'));
      expect(yamlRestored, contains('middleName: null'));
      expect(yamlRestored, contains('age: 30'));
    });

    test('round-trip empty containers', () {
      final yaml = '''
emptyObject: {}
emptyArray: []
''';
      final toon = yamlToToon(yaml);
      final yamlRestored = toonToYaml(toon);

      expect(yamlRestored, contains('emptyObject: {}'));
      expect(yamlRestored, contains('emptyArray: []'));
    });
  });

  group('YAML Large Data Tests', () {
    test('convert large YAML with multiple users to TOON', () {
      final yaml = '''
users:
  - id: 1
    name: Alice Smith
    email: alice@example.com
    role: admin
    active: true
  - id: 2
    name: Bob Jones
    email: bob@example.com
    role: user
    active: false
  - id: 3
    name: Charlie Brown
    email: charlie@example.com
    role: moderator
    active: true
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('users[3]{id,name,email,role,active}:'));
      expect(toon, contains('Alice Smith'));
      expect(toon, contains('Bob Jones'));
      expect(toon, contains('Charlie Brown'));
    });

    test('convert e-commerce YAML to TOON', () {
      final yaml = '''
order:
  id: ORD-2024-001
  customer:
    name: Jane Doe
    email: jane@example.com
  items:
    - sku: LAPTOP-X1
      qty: 1
      price: 1299.99
    - sku: MOUSE-M2
      qty: 2
      price: 29.99
  total: 1359.97
  status: shipped
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('order:'));
      expect(toon, contains('customer:'));
      expect(toon, contains('items[2]{sku,qty,price}:'));
      expect(toon, contains('total: 1359.97'));
    });

    test('convert configuration YAML to TOON', () {
      final yaml = '''
application:
  name: MyApp
  version: 1.0.0
  environment: production
database:
  primary:
    host: db1.example.com
    port: 5432
    ssl: true
  replica:
    host: db2.example.com
    port: 5432
    ssl: true
cache:
  redis:
    enabled: true
    host: redis.example.com
    port: 6379
logging:
  level: info
  outputs:
    - console
    - file
    - syslog
''';
      final toon = yamlToToon(yaml);
      expect(toon, contains('application:'));
      expect(toon, contains('database:'));
      expect(toon, contains('cache:'));
      expect(toon, contains('logging:'));
    });
  });
}

