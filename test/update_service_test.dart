import 'package:flutter_test/flutter_test.dart';
import 'package:icnative/services/update_service.dart';

void main() {
  group('UpdateService - Semantic Version Comparison', () {
    test('Identical versions return false', () {
      expect(UpdateService.isNewerVersion('v1.4.12', '1.4.12'), isFalse);
      expect(UpdateService.isNewerVersion('1.4.12', '1.4.12'), isFalse);
      expect(UpdateService.isNewerVersion('v1.4.12+2008', '1.4.12+2008'), isFalse);
      expect(UpdateService.isNewerVersion('v1.4.12-release', '1.4.12'), isFalse);
    });

    test('Newer patch version returns true', () {
      expect(UpdateService.isNewerVersion('v1.4.13', '1.4.12'), isTrue);
      expect(UpdateService.isNewerVersion('v1.4.20', '1.4.9'), isTrue);
      expect(UpdateService.isNewerVersion('1.4.13+2009', '1.4.12+2008'), isTrue);
    });

    test('Older patch version returns false', () {
      expect(UpdateService.isNewerVersion('v1.4.11', '1.4.12'), isFalse);
      expect(UpdateService.isNewerVersion('v1.4.9', '1.4.12'), isFalse);
      expect(UpdateService.isNewerVersion('1.4.0', '1.4.12'), isFalse);
    });

    test('Newer minor version returns true', () {
      expect(UpdateService.isNewerVersion('v1.5.0', '1.4.12'), isTrue);
      expect(UpdateService.isNewerVersion('v1.10.0', '1.4.12'), isTrue);
    });

    test('Older minor version returns false', () {
      expect(UpdateService.isNewerVersion('v1.3.99', '1.4.0'), isFalse);
    });

    test('Newer major version returns true', () {
      expect(UpdateService.isNewerVersion('v2.0.0', '1.4.12'), isTrue);
    });

    test('Older major version returns false', () {
      expect(UpdateService.isNewerVersion('v0.9.9', '1.4.12'), isFalse);
    });

    test('Malformed version strings do not throw and return false', () {
      expect(UpdateService.isNewerVersion('', '1.4.12'), isFalse);
      expect(UpdateService.isNewerVersion('invalid_tag', '1.4.12'), isFalse);
      expect(UpdateService.isNewerVersion('...', '1.4.12'), isFalse);
    });
  });

  group('UpdateService - Dual-Release Anti-Mismatch Rule', () {
    final mockAssets = [
      {
        'name': 'Orbit-v1.4.12-clean-release.apk',
        'browser_download_url': 'https://github.com/release/clean.apk',
        'size': 169155365,
      },
      {
        'name': 'Orbit-v1.4.12-demo-showcase.apk',
        'browser_download_url': 'https://github.com/release/demo.apk',
        'size': 169155365,
      },
      {
        'name': 'Orbit-v1.4.12.ipa',
        'browser_download_url': 'https://github.com/release/app.ipa',
        'size': 120000000,
      },
    ];

    test('Clean Release build strictly selects clean-release APK and NEVER demo', () {
      final matched = UpdateService.matchReleaseAsset(
        assets: mockAssets,
        isDemo: false,
        isIos: false,
        htmlUrl: 'https://github.com/release',
      );

      expect(matched.targetDownloadUrl, 'https://github.com/release/clean.apk');
      expect(matched.targetDownloadUrl, isNot(contains('demo')));
      expect(matched.targetSize, 169155365);
    });

    test('Clean Release build with generic apk avoids demo keyword', () {
      final assetsWithoutCleanTag = [
        {
          'name': 'Orbit-v1.4.12-demo-showcase.apk',
          'browser_download_url': 'https://github.com/release/demo.apk',
          'size': 160000000,
        },
        {
          'name': 'Orbit-v1.4.12-release.apk',
          'browser_download_url': 'https://github.com/release/generic_release.apk',
          'size': 160000000,
        },
      ];

      final matched = UpdateService.matchReleaseAsset(
        assets: assetsWithoutCleanTag,
        isDemo: false,
        isIos: false,
        htmlUrl: 'https://github.com/release',
      );

      expect(matched.targetDownloadUrl, 'https://github.com/release/generic_release.apk');
      expect(matched.targetDownloadUrl, isNot(contains('demo')));
    });

    test('Demo Showcase build prioritizes demo-showcase APK', () {
      final matched = UpdateService.matchReleaseAsset(
        assets: mockAssets,
        isDemo: true,
        isIos: false,
        htmlUrl: 'https://github.com/release',
      );

      expect(matched.targetDownloadUrl, 'https://github.com/release/demo.apk');
      expect(matched.targetDownloadUrl, contains('demo'));
      expect(matched.targetSize, 169155365);
    });

    test('iOS platform selects .ipa asset', () {
      final matched = UpdateService.matchReleaseAsset(
        assets: mockAssets,
        isDemo: false,
        isIos: true,
        htmlUrl: 'https://github.com/release',
      );

      expect(matched.targetDownloadUrl, 'https://github.com/release/app.ipa');
      expect(matched.ipaUrl, 'https://github.com/release/app.ipa');
      expect(matched.targetSize, 120000000);
    });

    test('iOS platform falls back to htmlUrl when no .ipa is found', () {
      final noIpaAssets = [
        {
          'name': 'Orbit-v1.4.12-clean-release.apk',
          'browser_download_url': 'https://github.com/release/clean.apk',
          'size': 169155365,
        },
      ];

      final matched = UpdateService.matchReleaseAsset(
        assets: noIpaAssets,
        isDemo: false,
        isIos: true,
        htmlUrl: 'https://github.com/release',
      );

      expect(matched.targetDownloadUrl, 'https://github.com/release');
      expect(matched.ipaUrl, isNull);
    });
  });

  group('GitHubReleaseInfo model formatting', () {
    test('formattedSize formats MB correctly', () {
      final info = GitHubReleaseInfo(
        tagName: 'v1.4.12',
        title: 'Orbit 1.4.12',
        notes: 'Changelog',
        apkDownloadUrl: 'https://download.apk',
        apkSizeBytes: 169155365,
        publishedAt: '2026-11-07',
      );

      expect(info.formattedSize, '161.3 MB');
    });

    test('formattedSize handles 0 or negative bytes', () {
      final infoAndroid = GitHubReleaseInfo(
        tagName: 'v1.4.12',
        title: 'Orbit 1.4.12',
        notes: '',
        apkDownloadUrl: '',
        apkSizeBytes: 0,
        publishedAt: '',
        isIos: false,
      );
      expect(infoAndroid.formattedSize, isEmpty);

      final infoIos = GitHubReleaseInfo(
        tagName: 'v1.4.12',
        title: 'Orbit 1.4.12',
        notes: '',
        apkDownloadUrl: '',
        apkSizeBytes: 0,
        publishedAt: '',
        isIos: true,
      );
      expect(infoIos.formattedSize, 'Bản Cập Nhật iOS');
    });
  });
}
