import 'package:flutter/material.dart';
import '../billing/billing_service.dart';
import '../billing/paywall_screen.dart';
import '../onboarding/theme.dart';
import '../topics/topics_catalog.dart';
import '../topics/topics_repository.dart';

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key});

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  void _presentPaywall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaywallScreen(
          onDismiss: () => Navigator.of(context).pop(),
          onPurchased: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _onToggle(TopicsRepository repo, BillingService billing, Topic t) {
    if (TopicsCatalog.isFree(t.id) || billing.isPro) {
      repo.toggle(t.id);
    } else {
      _presentPaywall();
    }
  }

  void _onSelectAll(TopicsRepository repo, BillingService billing, List<Topic> topics) {
    final allowed = billing.isPro
        ? topics.map((t) => t.id)
        : topics.where((t) => TopicsCatalog.isFree(t.id)).map((t) => t.id);
    final allFollowed = repo.followed.length == allowed.length &&
        allowed.every(repo.isFollowing);
    if (allFollowed) {
      repo.setAll(const []);
    } else {
      repo.setAll(allowed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = TopicsScope.of(context);
    final billing = BillingScope.of(context);
    final topics = TopicsCatalog.all;
    final followingCount = topics.where((t) => repo.isFollowing(t.id)).length;
    final selectableIds = billing.isPro
        ? topics.map((t) => t.id).toSet()
        : topics.where((t) => TopicsCatalog.isFree(t.id)).map((t) => t.id).toSet();
    final allFollowed = followingCount == selectableIds.length &&
        selectableIds.every(repo.isFollowing);

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
                    onTap: () => _onSelectAll(repo, billing, topics),
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
                    final locked = !billing.isPro && !TopicsCatalog.isFree(topic.id);
                    return _TopicRow(
                      topic: topic,
                      following: repo.isFollowing(topic.id),
                      locked: locked,
                      onToggle: () => _onToggle(repo, billing, topic),
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
  final bool locked;
  final VoidCallback onToggle;
  const _TopicRow({
    required this.topic,
    required this.following,
    required this.locked,
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        topic.title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (TopicsCatalog.isFree(topic.id)) ...[
                      const SizedBox(width: 8),
                      const _FreeBadge(),
                    ],
                  ],
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
          _FollowChip(following: following, locked: locked, onTap: onToggle),
        ],
      ),
    );
  }
}

class _FreeBadge extends StatelessWidget {
  const _FreeBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.creamSoft,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Brutal.borderColor,
          width: 1.4,
        ),
      ),
      child: const Text(
        'FREE',
        style: TextStyle(
          color: AppColors.ink,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _FollowChip extends StatelessWidget {
  final bool following;
  final bool locked;
  final VoidCallback onTap;
  const _FollowChip({
    required this.following,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    final Color bg;
    final Color fg;
    if (locked) {
      icon = Icons.lock_rounded;
      label = 'Unlock';
      bg = AppColors.creamSoft;
      fg = AppColors.ink;
    } else if (following) {
      icon = Icons.check_rounded;
      label = 'Following';
      bg = AppColors.burgundy;
      fg = Colors.white;
    } else {
      icon = Icons.add_rounded;
      label = 'Follow';
      bg = Colors.white;
      fg = AppColors.ink;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
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
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: fg,
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
