import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TopicsRepository extends ChangeNotifier {
  static const _key = 'followed_topics_v1';
  final Set<String> _followed = {};
  bool _loaded = false;

  Set<String> get followed => Set.unmodifiable(_followed);
  bool get loaded => _loaded;

  bool isFollowing(String id) => _followed.contains(id);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    _followed
      ..clear()
      ..addAll(list);
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    if (_followed.contains(id)) {
      _followed.remove(id);
    } else {
      _followed.add(id);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> setAll(Iterable<String> ids) async {
    _followed
      ..clear()
      ..addAll(ids);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _followed.toList());
  }
}

class TopicsScope extends InheritedNotifier<TopicsRepository> {
  const TopicsScope({
    super.key,
    required TopicsRepository repo,
    required super.child,
  }) : super(notifier: repo);

  static TopicsRepository of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TopicsScope>();
    assert(scope != null, 'TopicsScope missing');
    return scope!.notifier!;
  }
}
