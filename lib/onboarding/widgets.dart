import 'package:flutter/material.dart';
import 'theme.dart';

class OnboardingScaffold extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final bool showBack;
  final bool showSkip;
  final double progress;

  const OnboardingScaffold({
    super.key,
    required this.child,
    required this.progress,
    this.onBack,
    this.onSkip,
    this.showBack = true,
    this.showSkip = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: showBack ? onBack : null,
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: showBack ? AppColors.ink : Colors.transparent,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: AppColors.creamSoft,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: showSkip
                        ? GestureDetector(
                            onTap: onSkip,
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Skip',
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onPressed != null;
    final pressed = _down && active;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: active ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(
          pressed ? 4 : 0,
          pressed ? 6 : 0,
          0,
        ),
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: active
              ? AppColors.teal
              : AppColors.teal.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: pressed ? const [] : Brutal.shadow(dx: 4, dy: 6),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsets padding;
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? AppColors.burgundy : Colors.white,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 3, dy: 4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _Radio(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final bool selected;
  const _Radio({required this.selected});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : Brutal.borderColor,
          width: Brutal.borderWidth,
        ),
        color: selected ? Colors.white : Colors.transparent,
      ),
      child: selected
          ? const Icon(Icons.check, color: AppColors.burgundy, size: 16)
          : null,
    );
  }
}

class Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 2, dy: 3),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class HeroIllustration extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  const HeroIllustration({
    super.key,
    required this.icon,
    this.size = 200,
    this.color = AppColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.creamSoft,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: Brutal.borderColor,
          width: Brutal.borderWidth,
        ),
        boxShadow: Brutal.shadow(dx: 5, dy: 7),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.55, color: color),
    );
  }
}

class TitleHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextAlign align;
  const TitleHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.align = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: align,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            textAlign: align,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ],
    );
  }
}
