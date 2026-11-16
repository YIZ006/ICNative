import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icnative/screens/story_templates_screen.dart';

void main() {
  group('StoryTemplatesScreen Data & Template Integrity Tests', () {
    test('Must contain exactly 11 curated templates and exclude removed IDs', () {
      final templates = StoryTemplatesScreen.templates;
      expect(templates.length, equals(11));

      final ids = templates.map((t) => t.id).toSet();
      expect(ids.length, equals(11));

      const expectedIds = {2, 3, 4, 6, 8, 11, 13, 15, 17, 18, 20};
      expect(ids, equals(expectedIds));

      const removedIds = {1, 5, 7, 9, 10, 12, 14, 16, 19};
      for (final removedId in removedIds) {
        expect(ids.contains(removedId), isFalse, reason: 'Template id $removedId should have been removed');
      }
    });

    test('All templates must preserve non-empty English names, metadata and valid colors', () {
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
      final y2k = templates.firstWhere((t) => t.id == 2);
      expect(y2k.name, equals('Y2K Chrome'));

      final spotify = templates.firstWhere((t) => t.id == 18);
      expect(spotify.primaryColor, equals(const Color(0xFF1DB954)));

      final polaroid = templates.firstWhere((t) => t.id == 3);
      expect(polaroid.primaryColor, equals(const Color(0xFF3A2E20)));

      final photobooth = templates.firstWhere((t) => t.id == 11);
      expect(photobooth.primaryColor, equals(const Color(0xFF1B4F72)));

      final lockscreen = templates.firstWhere((t) => t.id == 15);
      expect(lockscreen.primaryColor, equals(const Color(0xFF007AFF)));

      final redThread = templates.firstWhere((t) => t.id == 20);
      expect(redThread.primaryColor, equals(const Color(0xFFFF2A2A)));
    });
  });
}
