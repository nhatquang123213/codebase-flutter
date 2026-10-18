import 'package:get_it/get_it.dart';

import 'presentation/cubit/settings_cubit.dart';

void registerSettingsDependencies(GetIt getIt) {
  getIt.registerFactory(() => SettingsCubit(getIt()));
}
