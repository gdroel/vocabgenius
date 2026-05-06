import 'dart:math';

import 'package:flutter/material.dart';
import '../onboarding/theme.dart';
import '../topics/topics_catalog.dart';
import '../topics/topics_repository.dart';
import '../topics/words_data.dart';
import 'saved_screen.dart';
import 'topics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _bookmarks = <String>{};
  final _rng = Random();
  Word? _current;

  void _refreshIfNeeded(TopicsRepository repo) {
    if (_current == null || !repo.isFollowing(_current!.topicId)) {
      _pickNext(repo);
    }
  }

  void _pickNext(TopicsRepository repo) {
    final ids = repo.followed;
    final next = WordsData.randomFor(ids, rng: _rng);
    setState(() => _current = next);
  }

  String _wordKey(Word w) => '${w.topicId}::${w.word}';

  @override
  Widget build(BuildContext context) {
    final repo = TopicsScope.of(context);
    _refreshIfNeeded(repo);
    final word = _current;
    final hasFollowed = repo.followed.isNotEmpty;
    final isBookmarked = word != null && _bookmarks.contains(_wordKey(word));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              _TopBar(
                followedCount: repo.followed.length,
                onTopics: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TopicsScreen()),
                ),
                onSaved: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SavedScreen()),
                ),
              ),
              const Spacer(flex: 3),
              if (word != null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.18, 0),
                      end: Offset.zero,
                    ).animate(anim);
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: _WordCard(
                    key: ValueKey(_wordKey(word)),
                    word: word.word,
                    partOfSpeech: word.partOfSpeech,
                    definition: word.definition,
                    example: word.example,
                    topic: TopicsCatalog.byId(word.topicId),
                  ),
                )
              else
                _EmptyState(
                  hasFollowed: hasFollowed,
                  onChooseTopics: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TopicsScreen()),
                  ),
                ),
              const Spacer(flex: 4),
              _BottomBar(
                enabled: word != null,
                bookmarked: isBookmarked,
                onShare: () {},
                onNext: () => _pickNext(repo),
                onBookmark: word == null
                    ? () {}
                    : () => setState(() {
                        final key = _wordKey(word);
                        _bookmarks.contains(key)
                            ? _bookmarks.remove(key)
                            : _bookmarks.add(key);
                      }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFollowed;
  final VoidCallback onChooseTopics;
  const _EmptyState({
    required this.hasFollowed,
    required this.onChooseTopics,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 48,
            color: AppColors.muted,
          ),
          const SizedBox(height: 16),
          Text(
            hasFollowed
                ? 'No words yet for these topics'
                : 'Follow some topics to start',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onChooseTopics,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.burgundy,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: Brutal.borderColor,
                  width: Brutal.borderWidth,
                ),
                boxShadow: Brutal.shadow(dx: 3, dy: 4),
              ),
              child: const Text(
                'Browse topics',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int followedCount;
  final VoidCallback onTopics;
  final VoidCallback onSaved;
  const _TopBar({
    required this.followedCount,
    required this.onTopics,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _TopicsPill(onTap: onTopics, followedCount: followedCount),
        _SavedPill(onTap: onSaved),
      ],
    );
  }
}

class _SavedPill extends StatelessWidget {
  final VoidCallback onTap;
  const _SavedPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 2, dy: 3),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_outline_rounded,
              size: 18,
              color: AppColors.ink,
            ),
            SizedBox(width: 6),
            Text(
              'Saved',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicsPill extends StatelessWidget {
  final VoidCallback onTap;
  final int followedCount;
  const _TopicsPill({required this.onTap, required this.followedCount});

  @override
  Widget build(BuildContext context) {
    final label = followedCount > 0
        ? '$followedCount selected'
        : 'Topics';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 2, dy: 3),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grid_view_rounded, size: 18, color: AppColors.ink),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (followedCount > 0) ...[
              const SizedBox(width: 6),
              const Icon(Icons.add_rounded, size: 16, color: AppColors.muted),
            ],
          ],
        ),
      ),
    );
  }
}


class _WordCard extends StatelessWidget {
  final String word;
  final String partOfSpeech;
  final String definition;
  final String example;
  final Topic topic;
  const _WordCard({
    super.key,
    required this.word,
    required this.partOfSpeech,
    required this.definition,
    required this.example,
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopicTag(topic: topic),
        const SizedBox(height: 22),
        Text(
          word,
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '($partOfSpeech)',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          definition,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 19,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 22),
        _PipSpeechBubble(text: example),
      ],
    );
  }
}

class _PipSpeechBubble extends StatefulWidget {
  final String text;
  const _PipSpeechBubble({required this.text});

  @override
  State<_PipSpeechBubble> createState() => _PipSpeechBubbleState();
}

class _PipSpeechBubbleState extends State<_PipSpeechBubble>
    with TickerProviderStateMixin {
  late final AnimationController _ctl;
  late Animation<int> _chars;
  late final AnimationController _bobCtl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (widget.text.length * 22).clamp(700, 2400),
      ),
    );
    _chars = StepTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(parent: _ctl, curve: Curves.easeOut),
    );
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _ctl.forward();
    });
    _bobCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _ctl.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.forward) {
        _bobCtl.repeat(reverse: true);
      } else {
        _bobCtl.stop();
        _bobCtl.value = 0;
      }
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _bobCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _bobCtl,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, -2.5 * _bobCtl.value),
              child: child,
            ),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Brutal.borderColor,
                  width: Brutal.borderWidth,
                ),
                boxShadow: Brutal.shadow(dx: 2, dy: 3),
              ),
              clipBehavior: Clip.antiAlias,
              child: Transform.scale(
                scale: 1.35,
                child: Image.asset(
                  'assets/hero-image.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          CustomPaint(
            painter: _BubbleTailPainter(),
            size: const Size(12, 22),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Brutal.borderColor,
                  width: Brutal.borderWidth,
                ),
                boxShadow: Brutal.shadow(dx: 3, dy: 4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Professor Pip',
                    style: TextStyle(
                      color: AppColors.burgundy,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _chars,
                    builder: (_, _) {
                      final shown = widget.text.substring(0, _chars.value);
                      final isTyping = _chars.value < widget.text.length;
                      return RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                          ),
                          children: [
                            TextSpan(text: shown),
                            if (isTyping)
                              const TextSpan(
                                text: '▍',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontStyle: FontStyle.normal,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Brutal.borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = Brutal.borderWidth
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    // Cover the right edge so the bubble border merges seamlessly.
    final cover = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(size.width - 1, 1, 2, size.height - 2),
      cover,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopicTag extends StatelessWidget {
  final Topic topic;
  const _TopicTag({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Brutal.borderColor,
          width: Brutal.borderWidth,
        ),
        boxShadow: Brutal.shadow(dx: 2, dy: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(topic.icon, size: 16, color: AppColors.ink),
          const SizedBox(width: 6),
          Text(
            topic.title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool enabled;
  final bool bookmarked;
  final VoidCallback onShare;
  final VoidCallback onNext;
  final VoidCallback onBookmark;
  const _BottomBar({
    required this.enabled,
    required this.bookmarked,
    required this.onShare,
    required this.onNext,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ActionCircle(
          icon: Icons.ios_share_rounded,
          onTap: enabled ? onShare : () {},
          dim: !enabled,
        ),
        Expanded(
          child: Center(
            child: _NextButton(onTap: onNext, dim: !enabled),
          ),
        ),
        _ActionCircle(
          icon: bookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_outline_rounded,
          onTap: enabled ? onBookmark : () {},
          dim: !enabled,
        ),
      ],
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool dim;
  const _ActionCircle({
    required this.icon,
    required this.onTap,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: dim
              ? AppColors.burgundy.withValues(alpha: 0.4)
              : AppColors.burgundy,
          shape: BoxShape.circle,
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 3, dy: 4),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class _NextButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool dim;
  const _NextButton({required this.onTap, this.dim = false});

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 260),
  );

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _bounce() async {
    await _ctl.forward();
    await _ctl.animateBack(0, curve: Curves.elasticOut);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _bounce();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.10 * _ctl.value, child: child),
        child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: widget.dim
                  ? AppColors.burgundy.withValues(alpha: 0.4)
                  : AppColors.burgundy,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: Brutal.borderColor,
                width: Brutal.borderWidth,
              ),
              boxShadow: Brutal.shadow(dx: 4, dy: 5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      );
  }
}
