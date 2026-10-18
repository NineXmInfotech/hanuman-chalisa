import 'package:flutter_test/flutter_test.dart';
import 'package:hanumanchalisa/chalisa_data.dart';
import 'package:hanumanchalisa/strings.dart';

void main() {
  test('Chalisa has 40 chaupais and 3 dohas', () {
    expect(allVerses.where((v) => v.kind == VerseKind.chaupai).length, 40);
    expect(allVerses.length, 43);
  });

  test('Every app string has Hindi, Gujarati and English', () {
    for (final entry in appStrings.entries) {
      expect(entry.value.length, 3, reason: entry.key);
    }
  });
}
