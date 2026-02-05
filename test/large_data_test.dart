import 'package:test/test.dart';
import 'package:toonx/toonx.dart';

void main() {
  group('Large Data Tests', () {
    test('encode/decode 100 user records', () {
      final users = List.generate(
        100,
        (i) => {
          'id': i + 1,
          'username': 'user_${i + 1}',
          'email': 'user${i + 1}@example.com',
          'age': 20 + (i % 50),
          'isActive': i % 2 == 0,
          'score': (i * 12.34).toDouble(),
        },
      );

      final data = {'users': users, 'total': 100};
      final toon = encode(data);
      final decoded = decode(toon);

      expect(decoded['total'], 100);
      expect((decoded['users'] as List).length, 100);
      expect(decoded['users'][0]['username'], 'user_1');
      expect(decoded['users'][99]['username'], 'user_100');
    });

    test('encode large e-commerce order', () {
      final order = {
        'orderId': 'ORD-2025-001234',
        'orderDate': '2025-01-15T10:30:00Z',
        'customer': {
          'id': 12345,
          'name': 'John Doe',
          'email': 'john.doe@example.com',
          'address': {
            'street': '123 Main St',
            'city': 'Springfield',
            'zipCode': '62701',
          },
        },
        'items': [
          {'sku': 'W-001', 'name': 'Widget', 'qty': 2, 'price': 29.99},
          {'sku': 'G-042', 'name': 'Gadget', 'qty': 1, 'price': 149.99},
          {'sku': 'T-123', 'name': 'Tool', 'qty': 3, 'price': 89.99},
        ],
        'totals': {'subtotal': 451.44, 'tax': 36.12, 'total': 487.56},
      };

      final toon = encode(order);
      final decoded = decode(toon);

      expect(decoded['orderId'], 'ORD-2025-001234');
      expect(decoded['customer']['name'], 'John Doe');
      expect(decoded['customer']['address']['city'], 'Springfield');
      expect((decoded['items'] as List).length, 3);
      expect(decoded['totals']['total'], 487.56);
    });

    test('encode 50 GitHub-style repositories', () {
      final repos = List.generate(
        50,
        (i) => {
          'id': i + 1,
          'name': 'repo-${i + 1}',
          'language': ['Dart', 'JavaScript', 'Python'][i % 3],
          'stars': i * 10,
          'forks': i * 5,
          'isPrivate': i % 3 == 0,
        },
      );

      final data = {'repositories': repos, 'count': 50};
      final toon = encode(data);
      final decoded = decode(toon);

      expect((decoded['repositories'] as List).length, 50);
      expect(decoded['count'], 50);
    });

    test('encode nested configuration', () {
      final config = {
        'app': {
          'name': 'MyApp',
          'version': '1.2.3',
          'server': {
            'host': 'localhost',
            'port': 8080,
            'ssl': {'enabled': true, 'cert': '/path/cert'},
          },
          'database': {
            'host': 'db.local',
            'port': 5432,
            'credentials': {'user': 'admin', 'pass': 'secret'},
          },
        },
      };

      final toon = encode(config);
      final decoded = decode(toon);

      expect(decoded['app']['name'], 'MyApp');
      expect(decoded['app']['server']['port'], 8080);
      expect(decoded['app']['server']['ssl']['enabled'], true);
      expect(decoded['app']['database']['credentials']['user'], 'admin');
    });

    test('encode analytics with 31 daily metrics', () {
      final analytics = {
        'website': 'example.com',
        'dailyMetrics': List.generate(
          31,
          (i) => {
            'date': '2025-01-${(i + 1).toString().padLeft(2, '0')}',
            'visitors': 1000 + (i * 50),
            'pageViews': 5000 + (i * 200),
            'conversions': 10 + i,
          },
        ),
        'summary': {
          'totalVisitors': 47500,
          'totalPageViews': 248000,
          'avgConversions': 25,
        },
      };

      final toon = encode(analytics);
      final decoded = decode(toon);

      expect((decoded['dailyMetrics'] as List).length, 31);
      expect(decoded['summary']['totalVisitors'], 47500);
    });

    test('roundtrip large mixed data with tab delimiter', () {
      final data = {
        'products': List.generate(
          50,
          (i) => {
            'id': i + 1,
            'sku': 'SKU-${i + 1}',
            'price': 10.0 + i,
            'stock': 100 - i,
          },
        ),
      };

      final toon = encode(data, options: EncodeOptions(delimiter: '\t'));
      final decoded = decode(toon);

      expect((decoded['products'] as List).length, 50);
      expect(decoded['products'][0]['sku'], 'SKU-1');
    });

    test('flat map deeply nested configuration', () {
      final config = {
        'app': {
          'name': 'MyApp',
          'server': {
            'host': 'localhost',
            'port': 8080,
            'ssl': {'enabled': true, 'cert': '/path/cert'},
          },
        },
      };

      final toon = encode(
        config,
        options: EncodeOptions(enforceFlatMap: true, flatMapSeparator: '.'),
      );
      final decoded = decode(
        toon,
        options: DecodeOptions(enforceFlatMap: true, flatMapSeparator: '.'),
      );

      expect(decoded['app']['name'], 'MyApp');
      expect(decoded['app']['server']['ssl']['enabled'], true);
    });
  });
}
