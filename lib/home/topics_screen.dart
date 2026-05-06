import 'package:flutter/material.dart';
import '../onboarding/theme.dart';
import '../topics/topics_catalog.dart';
import '../topics/topics_repository.dart';

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key});

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = TopicsScope.of(context);
    final topics = TopicsCatalog.all;
    final followingCount = topics.where((t) => repo.isFollowing(t.id)).length;
    final allFollowed = followingCount == topics.length;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _SectionLabel(
                      text: followingCount > 0
                          ? 'Following · $followingCount'
                          : 'Discover topics',
                    ),
                  ),
                  _SelectAllButton(
                    allFollowed: allFollowed,
                    onTap: () {
                      if (allFollowed) {
                        repo.setAll(const []);
                      } else {
                        repo.setAll(topics.map((t) => t.id));
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                  itemCount: topics.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final topic = topics[i];
                    return _TopicRow(
                      topic: topic,
                      following: repo.isFollowing(topic.id),
                      onToggle: () => repo.toggle(topic.id),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                'Explore topics',
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SelectAllButton extends StatelessWidget {
  final bool allFollowed;
  final VoidCallback onTap;
  const _SelectAllButton({required this.allFollowed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: allFollowed ? AppColors.burgundy : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 2, dy: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          allFollowed ? 'Clear all' : 'Select all',
          style: TextStyle(
            color: allFollowed ? Colors.white : AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final Topic topic;
  final bool following;
  final VoidCallback onToggle;
  const _TopicRow({
    required this.topic,
    required this.following,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 3, dy: 4),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.creamSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Brutal.borderColor,
                  width: Brutal.borderWidth,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(topic.icon, size: 28, color: AppColors.burgundy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topic.blurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _FollowChip(following: following, onTap: onToggle),
          ],
        ),
    );
  }
}

class _FollowChip extends StatelessWidget {
  final bool following;
  final VoidCallback onTap;
  const _FollowChip({required this.following, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: following ? AppColors.burgundy : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 2, dy: 2),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              following ? Icons.check_rounded : Icons.add_rounded,
              size: 16,
              color: following ? Colors.white : AppColors.ink,
            ),
            const SizedBox(width: 4),
            Text(
              following ? 'Following' : 'Follow',
              style: TextStyle(
                color: following ? Colors.white : AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
