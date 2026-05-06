import 'package:flutter/material.dart';
import '../onboarding/theme.dart';
import '../topics/topics_catalog.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  static const _saved = <_SavedWord>[
    _SavedWord(
      word: 'jouska',
      phonetic: 'ˈdʒaʊskə',
      partOfSpeech: 'n.',
      topicId: 'emotions',
      definition:
          'The mental habit of rehearsing or imagining conversations that never actually occur',
    ),
    _SavedWord(
      word: 'sonder',
      phonetic: 'ˈsɒndər',
      partOfSpeech: 'n.',
      topicId: 'emotions',
      definition:
          'The realization that each passerby has a life as vivid and complex as your own',
    ),
    _SavedWord(
      word: 'petrichor',
      phonetic: 'ˈpɛtrɪkɔr',
      partOfSpeech: 'n.',
      topicId: 'beautiful',
      definition:
          'The pleasant, earthy smell after rain falls on dry ground',
    ),
    _SavedWord(
      word: 'salubrious',
      phonetic: 'səˈluːbriəs',
      partOfSpeech: 'adj.',
      topicId: 'beautiful',
      definition: 'Health-giving; clean and conducive to wellbeing',
    ),
    _SavedWord(
      word: 'lucubration',
      phonetic: 'ˌluːkjuˈbreɪʃn',
      partOfSpeech: 'n.',
      topicId: 'literature',
      definition: 'Study or writing done late into the night',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: _saved.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, i) => _SavedCard(word: _saved[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedWord {
  final String word;
  final String phonetic;
  final String partOfSpeech;
  final String topicId;
  final String definition;
  const _SavedWord({
    required this.word,
    required this.phonetic,
    required this.partOfSpeech,
    required this.topicId,
    required this.definition,
  });
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Brutal.borderColor,
                  width: Brutal.borderWidth,
                ),
                boxShadow: Brutal.shadow(dx: 2, dy: 3),
              ),
              child: const Icon(Icons.close, color: AppColors.ink),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Saved',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _MiniTopicTag extends StatelessWidget {
  final Topic topic;
  const _MiniTopicTag({required this.topic});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.burgundy,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(topic.icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              topic.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final _SavedWord word;
  const _SavedCard({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Brutal.borderColor,
          width: Brutal.borderWidth,
        ),
        boxShadow: Brutal.shadow(dx: 4, dy: 5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _MiniTopicTag(topic: TopicsCatalog.byId(word.topicId))),
              const Icon(
                Icons.bookmark_rounded,
                color: AppColors.burgundy,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            word.word,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${word.phonetic}  ·  ${word.partOfSpeech}',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            word.definition,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
