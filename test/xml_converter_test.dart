import 'package:test/test.dart';
import 'package:toonx/toonx.dart';

void main() {
  group('XML to TOON Tests (Parker)', () {
    test('convert simple XML to TOON', () {
      final xml = '''
<user>
  <name>Alice</name>
  <age>30</age>
  <active>true</active>
</user>
''';
      final toon = xmlToToon(xml);
      expect(toon, contains('user:'));
      expect(toon, contains('name: Alice'));
      // xml2json outputs numbers and booleans as strings
      expect(toon, contains('age:'));
      expect(toon, contains('active:'));
    });

    test('convert nested XML to TOON', () {
      final xml = '''
<person>
  <name>Bob</name>
  <contact>
    <email>bob@example.com</email>
    <phone>123-456-7890</phone>
  </contact>
</person>
''';
      final toon = xmlToToon(xml);
      expect(toon, contains('person:'));
      expect(toon, contains('name: Bob'));
      expect(toon, contains('contact:'));
      expect(toon, contains('email: bob@example.com'));
    });

    test('convert XML with repeated elements to TOON array', () {
      final xml = '''
<root>
  <item>admin</item>
  <item>developer</item>
  <item>ops</item>
</root>
''';
      final toon = xmlToToon(xml);
      expect(toon, contains('root:'));
      expect(toon, contains('item[3]:'));
      expect(toon, contains('admin'));
      expect(toon, contains('developer'));
      expect(toon, contains('ops'));
    });

    test('convert XML with mixed content to TOON', () {
      final xml = '''
<users>
  <user>
    <id>1</id>
    <name>Alice</name>
    <role>admin</role>
  </user>
  <user>
    <id>2</id>
    <name>Bob</name>
    <role>user</role>
  </user>
</users>
''';
      final toon = xmlToToon(xml);
      expect(toon, contains('users:'));
      expect(toon, contains('user[2]{id,name,role}:'));
      expect(toon, contains('Alice'));
      expect(toon, contains('Bob'));
    });

    test('convert empty XML element to TOON', () {
      final xml = '<root><empty/></root>';
      final toon = xmlToToon(xml);
      expect(toon, contains('root:'));
    });

    test('convert XML with numbers to TOON', () {
      final xml = '''
<data>
  <integer>42</integer>
  <float>3.14</float>
  <negative>-10</negative>
</data>
''';
      final toon = xmlToToon(xml);
      // xml2json outputs all values as strings
      expect(toon, contains('integer:'));
      expect(toon, contains('float:'));
      expect(toon, contains('negative:'));
    });

    test('convert XML with boolean-like values to TOON', () {
      final xml = '''
<flags>
  <active>true</active>
  <verified>false</verified>
</flags>
''';
      final toon = xmlToToon(xml);
      // xml2json outputs booleans as strings
      expect(toon, contains('active:'));
      expect(toon, contains('verified:'));
    });

    test('convert XML with special characters to TOON', () {
      final xml = '''
<data>
  <message>Hello, World!</message>
  <escaped>&lt;tag&gt;</escaped>
</data>
''';
      final toon = xmlToToon(xml);
      expect(toon, contains('message:'));
      expect(toon, contains('escaped:'));
    });

    test('convert XML with custom delimiter option', () {
      final xml = '''
<root>
  <item>admin</item>
  <item>ops</item>
  <item>dev</item>
</root>
''';
      final toon = xmlToToon(xml, options: EncodeOptions(delimiter: '\t'));
      expect(toon, contains('item[3\t]:'));
    });

    test('convert XML with length marker option', () {
      final xml = '''
<root>
  <item>apple</item>
  <item>banana</item>
  <item>cherry</item>
</root>
''';
      final toon = xmlToToon(xml, options: EncodeOptions(lengthMarker: '#'));
      expect(toon, contains('item[#3]:'));
    });

    test('throw FormatException on invalid XML', () {
      final invalidXml = '''
<root>
  <unclosed>
  <item>test</item>
''';
      expect(() => xmlToToon(invalidXml), throwsFormatException);
    });
  });

  group('TOON to XML Tests', () {
    test('convert simple TOON to XML', () {
      final toon = '''
user:
  name: Alice
  age: 30
  active: true
''';
      final xml = toonToXml(toon);
      expect(xml, contains('<name>Alice</name>'));
      expect(xml, contains('<age>30</age>'));
      expect(xml, contains('<active>true</active>'));
    });

    test('convert nested TOON to XML', () {
      final toon = '''
person:
  name: Bob
  contact:
    email: bob@example.com
    phone: 123-456-7890
''';
      final xml = toonToXml(toon);
      expect(xml, contains('<name>Bob</name>'));
      expect(xml, contains('<contact>'));
      expect(xml, contains('<email>bob@example.com</email>'));
      expect(xml, contains('</contact>'));
    });

    test('convert TOON array to XML', () {
      final toon = 'tags[3]: admin,developer,ops';
      final xml = toonToXml(toon);
      expect(xml, contains('<tags>admin</tags>'));
      expect(xml, contains('<tags>developer</tags>'));
      expect(xml, contains('<tags>ops</tags>'));
    });

    test('convert TOON tabular array to XML', () {
      final toon = '''
users[2]{id,name,role}:
  1,Alice,admin
  2,Bob,user
''';
      final xml = toonToXml(toon);
      expect(xml, contains('<id>1</id>'));
      expect(xml, contains('<name>Alice</name>'));
      expect(xml, contains('<role>admin</role>'));
    });

    test('convert empty TOON to XML', () {
      final toon = '';
      final xml = toonToXml(toon);
      expect(xml, isNotEmpty);
    });

    test('convert TOON with numbers to XML', () {
      final toon = '''
data:
  integer: 42
  float: 3.14
  negative: -10
''';
      final xml = toonToXml(toon);
      expect(xml, contains('<integer>42</integer>'));
      expect(xml, contains('<float>3.14</float>'));
      expect(xml, contains('<negative>-10</negative>'));
    });

    test('convert TOON with booleans to XML', () {
      final toon = '''
flags:
  active: true
  verified: false
''';
      final xml = toonToXml(toon);
      expect(xml, contains('<active>true</active>'));
      expect(xml, contains('<verified>false</verified>'));
    });
  });

  group('XML ↔ TOON Round-trip Tests', () {
    test('round-trip simple object', () {
      final xml = '''
<user>
  <name>Alice</name>
  <age>30</age>
</user>
''';
      final toon = xmlToToon(xml);
      final xmlRestored = toonToXml(toon);

      // Verify data integrity
      expect(xmlRestored, contains('<name>Alice</name>'));
      expect(xmlRestored, contains('<age>30</age>'));
    });

    test('round-trip nested object', () {
      final xml = '''
<person>
  <name>Bob</name>
  <contact>
    <email>bob@example.com</email>
  </contact>
</person>
''';
      final toon = xmlToToon(xml);
      final xmlRestored = toonToXml(toon);

      expect(xmlRestored, contains('<name>Bob</name>'));
      expect(xmlRestored, contains('<email>bob@example.com</email>'));
    });

    test('round-trip array', () {
      final xml = '''
<root>
  <item>admin</item>
  <item>developer</item>
  <item>ops</item>
</root>
''';
      final toon = xmlToToon(xml);
      final xmlRestored = toonToXml(toon);

      expect(xmlRestored, contains('admin'));
      expect(xmlRestored, contains('developer'));
      expect(xmlRestored, contains('ops'));
    });
  });

  group('XML Badgerfish Tests', () {
    test('convert XML with attributes using Badgerfish', () {
      final xml = '<user id="1" active="true">Alice</user>';
      final toon = xmlToToonBadgerfish(xml);
      
      // Badgerfish preserves attributes with @ prefix
      expect(toon, contains('user:'));
    });

    test('convert complex XML with namespaces using Badgerfish', () {
      final xml = '''
<root xmlns:custom="http://example.com">
  <custom:item>test</custom:item>
</root>
''';
      final toon = xmlToToonBadgerfish(xml);
      expect(toon, contains('root:'));
    });
  });

  group('XML Large Data Tests', () {
    test('convert large XML with multiple users to TOON', () {
      final xml = '''
<users>
  <user>
    <id>1</id>
    <name>Alice Smith</name>
    <email>alice@example.com</email>
    <role>admin</role>
    <active>true</active>
  </user>
  <user>
    <id>2</id>
    <name>Bob Jones</name>
    <email>bob@example.com</email>
    <role>user</role>
    <active>false</active>
  </user>
  <user>
    <id>3</id>
    <name>Charlie Brown</name>
    <email>charlie@example.com</email>
    <role>moderator</role>
    <active>true</active>
  </user>
</users>
''';
      final toon = xmlToToon(xml);
      expect(toon, contains('users:'));
      expect(toon, contains('user[3]{id,name,email,role,active}:'));
      expect(toon, contains('Alice Smith'));
      expect(toon, contains('Bob Jones'));
      expect(toon, contains('Charlie Brown'));
    });

    test('convert e-commerce XML to TOON', () {
      final xml = '''
<order>
  <id>ORD-2024-001</id>
  <customer>
    <name>Jane Doe</name>
    <email>jane@example.com</email>
  </customer>
  <item>
    <sku>LAPTOP-X1</sku>
    <qty>1</qty>
    <price>1299.99</price>
  </item>
  <item>
    <sku>MOUSE-M2</sku>
    <qty>2</qty>
    <price>29.99</price>
  </item>
  <total>1359.97</total>
  <status>shipped</status>
</order>
''';
      final toon = xmlToToon(xml);
      expect(toon, contains('order:'));
      expect(toon, contains('customer:'));
      expect(toon, contains('item[2]{sku,qty,price}:'));
      expect(toon, contains('total:'));
    });

    test('convert configuration XML to TOON', () {
      final xml = '''
<config>
  <application>
    <name>MyApp</name>
    <version>1.0.0</version>
    <environment>production</environment>
  </application>
  <database>
    <host>localhost</host>
    <port>5432</port>
    <name>mydb</name>
  </database>
  <cache>
    <enabled>true</enabled>
    <ttl>3600</ttl>
  </cache>
</config>
''';
      final toon = xmlToToon(xml);
      expect(toon, contains('config:'));
      expect(toon, contains('application:'));
      expect(toon, contains('database:'));
      expect(toon, contains('cache:'));
    });
  });
}

