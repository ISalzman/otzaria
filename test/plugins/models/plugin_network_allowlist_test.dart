import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/plugin_network_allowlist.dart';

void main() {
  group('isUriAllowedForPluginNetwork', () {
    test('מתיר URL של מאגר הספרים המאושר ותתי-נתיביו', () {
      expect(
        isUriAllowedForPluginNetwork(Uri.parse(
            'https://github.com/YairDaniel123/Otzarya-Library/releases/latest/download/a.zip')),
        isTrue,
      );
    });

    test('חוסם דומייני CDN של גיטהאב כגישה ישירה (אינם ברשימה הגלובלית)', () {
      expect(
        isUriAllowedForPluginNetwork(
            Uri.parse('https://objects.githubusercontent.com/abc/a.zip')),
        isFalse,
      );
      expect(
        isUriAllowedForPluginNetwork(Uri.parse(
            'https://release-assets.githubusercontent.com/abc/a.zip')),
        isFalse,
      );
    });

    test('חוסם מאגר גיטהאב אחר', () {
      expect(
        isUriAllowedForPluginNetwork(
            Uri.parse('https://github.com/Someone/Other/releases')),
        isFalse,
      );
    });

    test('מתיר גישה לשרתי הנקדן המאושרים של Dicta', () {
      expect(
        isUriAllowedForPluginNetwork(
            Uri.parse('https://nakdan.dicta.org.il/api')),
        isTrue,
      );
      expect(
        isUriAllowedForPluginNetwork(
            Uri.parse('https://nakdan-u1-0.loadbalancer.dicta.org.il/api')),
        isTrue,
      );
      expect(
        isUriAllowedForPluginNetwork(Uri.parse(
            'https://nakdan-5-1.loadbalancer.dicta.org.il/api?text=שלום')),
        isTrue,
      );
    });
  });

  group('isGithubReleaseRedirectAllowed', () {
    final allowedGithubRelease = Uri.parse(
        'https://github.com/YairDaniel123/Otzarya-Library/releases/latest/download/a.zip');
    final cdn =
        Uri.parse('https://release-assets.githubusercontent.com/abc/a.zip');

    test('מתיר redirect מ-release מאושר ב-github.com אל ה-CDN', () {
      expect(isGithubReleaseRedirectAllowed(allowedGithubRelease, cdn), isTrue);
    });

    test('מתיר המשך שרשרת redirect בין דומייני CDN', () {
      final cdn2 = Uri.parse('https://objects.githubusercontent.com/x/a.zip');
      expect(isGithubReleaseRedirectAllowed(cdn, cdn2), isTrue);
    });

    test('חוסם redirect ל-CDN כשה-hop הקודם הוא github.com לא מאושר', () {
      final otherRepo =
          Uri.parse('https://github.com/Someone/Other/releases/download/a.zip');
      expect(isGithubReleaseRedirectAllowed(otherRepo, cdn), isFalse);
    });

    test('חוסם redirect ליעד שאינו דומיין CDN של גיטהאב', () {
      final evil = Uri.parse('https://evil.example.com/a.zip');
      expect(
          isGithubReleaseRedirectAllowed(allowedGithubRelease, evil), isFalse);
    });

    test('חוסם redirect ל-CDN ממקור שרירותי שאינו github/CDN', () {
      final arbitrary = Uri.parse('https://otzaria.org/x');
      expect(isGithubReleaseRedirectAllowed(arbitrary, cdn), isFalse);
    });
  });
}
