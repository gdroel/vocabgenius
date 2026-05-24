import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_genius/topics/topics_catalog.dart';
import 'package:vocab_genius/topics/words_data.dart';

void main() {
  test('print and sanity-check vocab counts per topic', () {
    var total = 0;
    for (final t in TopicsCatalog.all) {
      final n = WordsData.forTopic(t.id).length;
      total += n;
      // ignore: avoid_print
      print('${t.id.padRight(16)} ${n.toString().padLeft(5)}');
    }
    // ignore: avoid_print
    print('---');
    // ignore: avoid_print
    print('TOTAL            ${total.toString().padLeft(5)}');
    // ignore: avoid_print
    print('all.length       ${WordsData.all.length.toString().padLeft(5)}');

    expect(WordsData.forTopic('science').length, greaterThanOrEqualTo(700));
    expect(WordsData.forTopic('business').length, greaterThanOrEqualTo(600));
    expect(WordsData.forTopic('philosophy').length, greaterThanOrEqualTo(600));
    expect(WordsData.forTopic('literature').length, greaterThanOrEqualTo(600));
    expect(WordsData.forTopic('cuisine').length, greaterThanOrEqualTo(600));
    expect(WordsData.forTopic('travel').length, greaterThanOrEqualTo(600));
    expect(WordsData.forTopic('music').length, greaterThanOrEqualTo(600));

    expect(WordsData.all.length, equals(total));
  });

  test('every Word has non-empty fields and matches its topicId', () {
    for (final t in TopicsCatalog.all) {
      for (final w in WordsData.forTopic(t.id)) {
        expect(w.topicId, equals(t.id), reason: 'wrong topicId on $w');
        expect(w.word.isNotEmpty, isTrue, reason: 'empty word in ${t.id}');
        expect(w.partOfSpeech.isNotEmpty, isTrue,
            reason: 'empty POS for ${w.word} in ${t.id}');
        expect(w.definition.isNotEmpty, isTrue,
            reason: 'empty def for ${w.word} in ${t.id}');
        expect(w.example.isNotEmpty, isTrue,
            reason: 'empty example for ${w.word} in ${t.id}');
      }
    }
  });
}
