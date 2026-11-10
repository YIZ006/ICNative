import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icnative/screens/story_templates_screen.dart';

void main() {
  group('StoryTemplatesScreen Data & Template Integrity Tests', () {
    test('Must contain exactly 20 templates with unique IDs from 1 to 20', () {
      final templates = StoryTemplatesScreen.templates;
      expect(templates.length, equals(20));

      final ids = templates.map((t) => t.id).toSet();
      expect(ids.length, equals(20));
      for (int i = 1; i <= 20; i++) {
        expect(ids.contains(i), isTrue, reason: 'Template id $i must be defined');
      }
    });

    test('All templates must preserve non-empty metadata and valid colors', () {
      final templates = StoryTemplatesScreen.templates;
      for (final t in templates) {
        expect(t.name.trim().isNotEmpty, isTrue);
        expect(t.theme.trim().isNotEmpty, isTrue);
        expect(t.headline.trim().isNotEmpty, isTrue);
        expect(t.subHeadline.trim().isNotEmpty, isTrue);
        expect(t.centerIcon.trim().isNotEmpty, isTrue);
        expect(t.primaryColor.toARGB32(), isNotNull);
        expect(t.accentColor.toARGB32(), isNotNull);
        expect(t.backgroundGradient, isNotNull);
      }
    });

    test('cleanDisplayName sanitizes user tags and null values properly', () {
      expect(StoryTemplatesScreen.cleanDisplayName('Mèo Béo Đáng Yêu #554'), equals('Mèo Béo Đáng Yêu'));
      expect(StoryTemplatesScreen.cleanDisplayName('Capybara Chill #203'), equals('Capybara Chill'));
      expect(StoryTemplatesScreen.cleanDisplayName('Nguyen Van A'), equals('Nguyen Van A'));
      expect(StoryTemplatesScreen.cleanDisplayName(null), equals('Bạn thân'));
      expect(StoryTemplatesScreen.cleanDisplayName('   '), equals('Bạn thân'));
    });

    test('Core templates retain their signature primary colors per specifications', () {
      final templates = StoryTemplatesScreen.templates;
      final cosmic = templates.firstWhere((t) => t.id == 1);
      expect(cosmic.primaryColor, equals(const Color(0xFF00F0FF)));

      final spotify = templates.firstWhere((t) => t.id == 18);
      expect(spotify.primaryColor, equals(const Color(0xFF1DB954)));

      final polaroid = templates.firstWhere((t) => t.id == 3);
      expect(polaroid.primaryColor, equals(const Color(0xFF3A2E20)));

      final photobooth = templates.firstWhere((t) => t.id == 11);
      expect(photobooth.primaryColor, equals(const Color(0xFF1B4F72)));

      final lockscreen = templates.firstWhere((t) => t.id == 15);
      expect(lockscreen.primaryColor, equals(const Color(0xFF007AFF)));

      final soulmate = templates.firstWhere((t) => t.id == 9);
      expect(soulmate.primaryColor, equals(const Color(0xFFFF3366)));
    });
  });
}
