import 'package:flutter/material.dart';

class Topic {
  final String id;
  final String title;
  final String blurb;
  final IconData icon;
  const Topic({
    required this.id,
    required this.title,
    required this.blurb,
    required this.icon,
  });
}

class TopicsCatalog {
  static const all = <Topic>[
    Topic(
      id: 'beautiful',
      title: 'Beautiful words',
      blurb: 'Words you wish you used more often',
      icon: Icons.local_florist_rounded,
    ),
    Topic(
      id: 'untranslatable',
      title: 'Untranslatable',
      blurb: 'Foreign words English borrowed for a feeling',
      icon: Icons.translate_rounded,
    ),
    Topic(
      id: 'slang',
      title: 'Slang',
      blurb: 'How people actually talk right now',
      icon: Icons.chat_bubble_outline_rounded,
    ),
    Topic(
      id: 'curse',
      title: 'Curse words',
      blurb: 'The colorful side of language',
      icon: Icons.tag_rounded,
    ),
    Topic(
      id: 'funny',
      title: 'Funny words',
      blurb: 'Words that just sound delightful',
      icon: Icons.sentiment_very_satisfied_rounded,
    ),
    Topic(
      id: 'fancy',
      title: 'Too fancy',
      blurb: 'Show-off words for when plain ones won\'t do',
      icon: Icons.auto_awesome_rounded,
    ),
    Topic(
      id: 'oldmoney',
      title: 'Old Money',
      blurb: 'Talk like you summer somewhere',
      icon: Icons.sailing_rounded,
    ),
    Topic(
      id: 'emotions',
      title: 'Emotions',
      blurb: 'Names for the feelings you didn\'t know had a name',
      icon: Icons.favorite_outline_rounded,
    ),
    Topic(
      id: 'love',
      title: 'Love & dating',
      blurb: 'The vocabulary of romance',
      icon: Icons.favorite_rounded,
    ),
    Topic(
      id: 'business',
      title: 'Business',
      blurb: 'Sound sharp in meetings and emails',
      icon: Icons.business_center_outlined,
    ),
    Topic(
      id: 'science',
      title: 'Science',
      blurb: 'Words to talk about how the world works',
      icon: Icons.science_outlined,
    ),
    Topic(
      id: 'philosophy',
      title: 'Philosophy',
      blurb: 'Big ideas in precise language',
      icon: Icons.psychology_outlined,
    ),
    Topic(
      id: 'literature',
      title: 'Literature',
      blurb: 'Words from the best writers in history',
      icon: Icons.auto_stories_rounded,
    ),
    Topic(
      id: 'cuisine',
      title: 'Food & cuisine',
      blurb: 'Talk about taste like a real critic',
      icon: Icons.restaurant_menu_rounded,
    ),
    Topic(
      id: 'travel',
      title: 'Travel',
      blurb: 'Words for places, journeys and wanderlust',
      icon: Icons.flight_takeoff_rounded,
    ),
    Topic(
      id: 'music',
      title: 'Music',
      blurb: 'The language of sound',
      icon: Icons.music_note_rounded,
    ),
  ];

  static Topic byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);
}
