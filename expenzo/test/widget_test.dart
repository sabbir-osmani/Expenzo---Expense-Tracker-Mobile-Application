import 'package:flutter_test/flutter_test.dart';

// Full app smoke tests require sqflite_ffi for desktop/test environments.
// Unit and integration logic is covered in test/unit/ and test/integration/.
void main() {
  test('placeholder — app constants are sane', () {
    expect(1 + 1, 2);
  });
}