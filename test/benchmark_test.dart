import 'package:toonx/toonx.dart';

/// Performance benchmark for toonX encode/decode operations.
///
/// Run with: dart test test/benchmark_test.dart
void main() {
  // Generate test data: 1000 users with 6 fields each (tabular format friendly)
  final data = {
    'users': List.generate(1000, (i) => {
      'id': i,
      'name': 'user_$i',
      'email': 'u$i@test.com',
      'active': i % 2 == 0,
      'score': i * 1.5,
      'tag': 'tag${i % 5}',
    })
  };

  // Warm up
  for (var i = 0; i < 5; i++) {
    final toon = encode(data);
    decode(toon);
  }

  // Benchmark encode
  final encodeStopwatch = Stopwatch()..start();
  for (var i = 0; i < 100; i++) {
    encode(data);
  }
  encodeStopwatch.stop();

  // Benchmark decode
  final toonData = encode(data);
  final decodeStopwatch = Stopwatch()..start();
  for (var i = 0; i < 100; i++) {
    decode(toonData);
  }
  decodeStopwatch.stop();

  // Benchmark round-trip
  final roundTripStopwatch = Stopwatch()..start();
  for (var i = 0; i < 100; i++) {
    final toon = encode(data);
    decode(toon);
  }
  roundTripStopwatch.stop();

  print('=== toonX Performance Benchmark ===');
  print('Data: 1000 records x 6 fields');
  print('Iterations: 100');
  print('');
  print('Encode (100 iterations): ${encodeStopwatch.elapsedMilliseconds}ms');
  print('Decode (100 iterations): ${decodeStopwatch.elapsedMilliseconds}ms');
  print('Round-trip (100 iterations): ${roundTripStopwatch.elapsedMilliseconds}ms');
  print('');
  print('Per iteration:');
  print('  Encode: ${(encodeStopwatch.elapsedMicroseconds / 100).toStringAsFixed(1)}µs');
  print('  Decode: ${(decodeStopwatch.elapsedMicroseconds / 100).toStringAsFixed(1)}µs');
  print('  Round-trip: ${(roundTripStopwatch.elapsedMicroseconds / 100).toStringAsFixed(1)}µs');
}
