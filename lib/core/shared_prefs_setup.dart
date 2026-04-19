import 'dart:io';

import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'app_paths.dart';

/// A [PathProviderWindows] subclass that always returns the otzaria data root
/// as the application support directory, bypassing the VERSIONINFO-based
/// company/product name detection (which would produce a Hebrew-named path).
class _OtzariaPathProvider extends PathProviderWindows {
  final String _dataRoot;
  _OtzariaPathProvider(this._dataRoot);

  @override
  Future<String?> getApplicationSupportPath() async => _dataRoot;
}

/// On Windows, overrides the default [SharedPreferencesStorePlatform] so that
/// `shared_preferences.json` is written to `%APPDATA%\otzaria` instead of the
/// Hebrew-named path that the default VERSIONINFO lookup would produce.
///
/// Must be called before the first [SharedPreferences.getInstance] call.
Future<void> configureSharedPreferencesPath() async {
  if (!Platform.isWindows) return;

  final dataRoot = await AppPaths.getDataRootPath();
  final prefs = SharedPreferencesWindows();
  // ignore: invalid_use_of_visible_for_testing_member
  prefs.pathProvider = _OtzariaPathProvider(dataRoot);
  SharedPreferencesStorePlatform.instance = prefs;
}
