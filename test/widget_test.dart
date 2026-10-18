import 'package:flutter_test/flutter_test.dart';
import 'package:hanuman_chalisa/chalisa_data.dart';

void main() {
  test('Chalisa has 40 chaupais and 3 dohas', () {
    expect(chaupais.length, 40);
    expect(allVerses.length, 43);
  });
}
