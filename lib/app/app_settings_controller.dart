import 'package:flutter/foundation.dart';

import '../features/settings/data/settings_repository.dart';
import '../features/settings/domain/app_settings.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    required SettingsRepository repository,
    required AppSettings initialSettings,
  }) : _repository = repository,
       _settings = initialSettings;

  final SettingsRepository _repository;
  AppSettings _settings;

  AppSettings get settings => _settings;

  Future<void> update(AppSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _repository.save(settings);
  }
}
