import 'package:get_it/get_it.dart';

import '../../core/config/env.dart';
import 'data/datasources/auth_mock_data_source.dart';
import 'data/datasources/auth_remote_data_source.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/get_current_user_usecase.dart';
import 'domain/usecases/login_usecase.dart';
import 'domain/usecases/logout_usecase.dart';
import 'presentation/bloc/auth_bloc.dart';
import 'presentation/cubit/login_cubit.dart';

void registerAuthDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => Env.useMockApi
          ? AuthMockDataSource()
          : AuthRemoteDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remote: getIt(), tokenStorage: getIt()),
    )
    ..registerFactory(() => LoginUseCase(getIt()))
    ..registerFactory(() => GetCurrentUserUseCase(getIt()))
    ..registerFactory(() => LogoutUseCase(getIt()))
    ..registerFactory(
      () =>
          AuthBloc(getCurrentUser: getIt(), logout: getIt(), eventBus: getIt()),
    )
    ..registerFactory(() => LoginCubit(getIt()));
}
