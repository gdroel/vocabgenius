import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../topics/words_data.dart';

class BookmarksRepository extends ChangeNotifier {
  static const _key = 'bookmarked_words_v1';
  final List<Word> _saved = [];
  bool _loaded = false;

  List<Word> get saved => List.unmodifiable(_saved);
  bool get loaded => _loaded;

  String _keyOf(Word w) => '${w.topicId}::${w.word}';

  bool isBookmarked(Word w) =>
      _saved.any((b) => _keyOf(b) == _keyOf(w));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList(_key) ?? [];
    final byKey = <String, Word>{
      for (final w in WordsData.all) _keyOf(w): w,
    };
    _saved
      ..clear()
      ..addAll(keys.map((k) => byKey[k]).whereType<Word>());
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggle(Word w) async {
    final key = _keyOf(w);
    final i = _saved.indexWhere((b) => _keyOf(b) == key);
    if (i >= 0) {
      _saved.removeAt(i);
    } else {
      _saved.insert(0, w);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> remove(Word w) async {
    final key = _keyOf(w);
    final before = _saved.length;
    _saved.removeWhere((b) => _keyOf(b) == key);
    if (_saved.length != before) {
      notifyListeners();
      await _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _saved.map(_keyOf).toList());
  }
}

class BookmarksScope extends InheritedNotifier<BookmarksRepository> {
  const BookmarksScope({
    super.key,
    required BookmarksRepository repo,
    required super.child,
  }) : super(notifier: repo);

  static BookmarksRepository of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<BookmarksScope>();
    assert(scope != null, 'BookmarksScope missing');
    return scope!.notifier!;
  }
}
