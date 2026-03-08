import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/file_sync/file_sync_repository.dart';

void main() {
  group('DiffReleaseAsset', () {
    test('parses DIFF asset names from GitHub release assets', () {
      final asset = DiffReleaseAsset.tryParse(
        {
          'name': '1-2.DIFF.zst',
          'browser_download_url':
              'https://github.com/Otzaria/SeforimLibrary/releases/download/v2/1-2.DIFF.zst',
        },
        releaseTag: 'v2',
        releaseName: 'Version 2',
      );

      expect(asset, isNotNull);
      expect(asset!.fromVersion, 1);
      expect(asset.toVersion, 2);
      expect(asset.assetName, '1-2.DIFF.zst');
    });

    test('ignores non diff assets', () {
      final asset = DiffReleaseAsset.tryParse(
        {
          'name': 'seforim.db.zip',
          'browser_download_url':
              'https://github.com/Otzaria/SeforimLibrary/releases/download/v2/seforim.db.zip',
        },
        releaseTag: 'v2',
        releaseName: 'Version 2',
      );

      expect(asset, isNull);
    });
  });

  group('FileSyncRepository.buildUpdateChain', () {
    test('builds contiguous update chain only', () {
      final chain = FileSyncRepository.buildUpdateChain(
        currentVersion: 1,
        availableAssets: const [
          DiffReleaseAsset(
            fromVersion: 1,
            toVersion: 2,
            assetName: '1-2.DIFF.zst',
            downloadUrl: 'https://example.com/1-2.DIFF.zst',
            releaseTag: 'v2',
            releaseName: 'Version 2',
          ),
          DiffReleaseAsset(
            fromVersion: 2,
            toVersion: 3,
            assetName: '2-3.DIFF.zst',
            downloadUrl: 'https://example.com/2-3.DIFF.zst',
            releaseTag: 'v3',
            releaseName: 'Version 3',
          ),
          DiffReleaseAsset(
            fromVersion: 4,
            toVersion: 5,
            assetName: '4-5.DIFF.zst',
            downloadUrl: 'https://example.com/4-5.DIFF.zst',
            releaseTag: 'v5',
            releaseName: 'Version 5',
          ),
        ],
      );

      expect(chain.map((asset) => asset.assetName), [
        '1-2.DIFF.zst',
        '2-3.DIFF.zst',
      ]);
    });

    test('stops at requested target version', () {
      final chain = FileSyncRepository.buildUpdateChain(
        currentVersion: 1,
        targetVersion: 3,
        availableAssets: const [
          DiffReleaseAsset(
            fromVersion: 1,
            toVersion: 2,
            assetName: '1-2.DIFF.zst',
            downloadUrl: 'https://example.com/1-2.DIFF.zst',
            releaseTag: 'v2',
            releaseName: 'Version 2',
          ),
          DiffReleaseAsset(
            fromVersion: 2,
            toVersion: 3,
            assetName: '2-3.DIFF.zst',
            downloadUrl: 'https://example.com/2-3.DIFF.zst',
            releaseTag: 'v3',
            releaseName: 'Version 3',
          ),
          DiffReleaseAsset(
            fromVersion: 3,
            toVersion: 4,
            assetName: '3-4.DIFF.zst',
            downloadUrl: 'https://example.com/3-4.DIFF.zst',
            releaseTag: 'v4',
            releaseName: 'Version 4',
          ),
        ],
      );

      expect(chain.map((asset) => asset.assetName), [
        '1-2.DIFF.zst',
        '2-3.DIFF.zst',
      ]);
    });

    test('does not allow skipping versions', () {
      final chain = FileSyncRepository.buildUpdateChain(
        currentVersion: 1,
        availableAssets: const [
          DiffReleaseAsset(
            fromVersion: 1,
            toVersion: 3,
            assetName: '1-3.DIFF.zst',
            downloadUrl: 'https://example.com/1-3.DIFF.zst',
            releaseTag: 'v3',
            releaseName: 'Version 3',
          ),
        ],
      );

      expect(chain, isEmpty);
    });
  });

  group('FileSyncRepository.splitSqlStatements', () {
    test('splits simple diff transaction into statements', () {
      const sql = '''
BEGIN TRANSACTION;
UPDATE db_meta SET value='2' WHERE "key"='content_version_int';
COMMIT;
''';

      expect(
        FileSyncRepository.splitSqlStatements(sql),
        [
          'BEGIN TRANSACTION',
          'UPDATE db_meta SET value=\'2\' WHERE "key"=\'content_version_int\'',
          'COMMIT',
        ],
      );
    });

    test('does not split semicolons inside strings', () {
      const sql = '''
UPDATE db_meta SET value='value;still-value' WHERE key='note';
''';

      expect(
        FileSyncRepository.splitSqlStatements(sql),
        [
          'UPDATE db_meta SET value=\'value;still-value\' WHERE key=\'note\'',
        ],
      );
    });
  });
}
