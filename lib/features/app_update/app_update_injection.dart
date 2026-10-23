import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'domain/app_version.dart';
import 'presentation/cubit/app_update_cubit.dart';

void registerAppUpdateDependencies(GetIt getIt) {
  getIt.registerFactory(
    () => AppUpdateCubit(
      config: getIt(),
      currentVersion: AppVersion.tryParse(getIt<PackageInfo>().version),
    ),
  );
}
