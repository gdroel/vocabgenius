import 'package:flutter/material.dart';
import '../onboarding/theme.dart';
import 'topics_catalog.dart';
import 'topics_repository.dart';

class TopicWordsScreen extends StatelessWidget {
  final Topic topic;
  const TopicWordsScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final repo = TopicsScope.of(context);
    final following = repo.isFollowing(topic.id);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox.shrink()),
                  _FollowButton(
                    following: following,
                    onTap: () => repo.toggle(topic.id),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Brutal.borderColor,
                        width: Brutal.borderWidth,
                      ),
                      boxShadow: Brutal.shadow(dx: 4, dy: 5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      topic.icon,
                      size: 48,
                      color: AppColors.burgundy,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    topic.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topic.blurb,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: _EmptyWords()),
          ],
        ),
      ),
    );
  }
}

class _EmptyWords extends StatelessWidget {
  const _EmptyWords();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: AppColors.ink.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Words coming soon',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool following;
  final VoidCallback onTap;
  const _FollowButton({required this.following, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: following ? AppColors.burgundy : Colors.white,
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
            Icon(
              following ? Icons.check_rounded : Icons.add_rounded,
              size: 18,
              color: following ? Colors.white : AppColors.ink,
            ),
            const SizedBox(width: 6),
            Text(
              following ? 'Following' : 'Follow',
              style: TextStyle(
                color: following ? Colors.white : AppColors.ink,
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
