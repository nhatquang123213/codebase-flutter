// Generates the skeleton of a new feature and wires it into the app.
//
//   make feature name=orders            # entity defaults to "order"
//   make feature name=order_items entity=order_item
//
// Produces lib/features/<name>/ (data/domain/presentation + injection),
// two tests, and inserts the endpoint, route, DI call and l10n title.
// Idempotent in the sense that it refuses to overwrite an existing feature.
//
// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  final options = _Options.parse(args);
  if (options == null) {
    stderr.writeln(
      'Usage: dart run tool/scaffold_feature.dart <snake_case_name> '
      '[--entity <snake_case_singular>]',
    );
    exitCode = 64;
    return;
  }

  final names = _Names(feature: options.feature, entity: options.entity);
  final featureDir = Directory('lib/features/${names.feature}');
  if (featureDir.existsSync()) {
    stderr.writeln('Feature "${names.feature}" already exists, aborting.');
    exitCode = 1;
    return;
  }

  final files = _templates(names);
  for (final entry in files.entries) {
    File(entry.key)
      ..createSync(recursive: true)
      ..writeAsStringSync(entry.value);
    print('  create  ${entry.key}');
  }

  final touched = [
    ..._wire(names),
    ...files.keys,
  ].where((path) => path.endsWith('.dart')).toList();
  final format = Process.runSync('dart', ['format', ...touched]);
  if (format.exitCode != 0) {
    stderr.write(format.stderr);
    exitCode = format.exitCode;
    return;
  }

  print('''

Feature "${names.feature}" created. Next:
  1. make gen l10n          (model .g.dart + localized title)
  2. Adjust ${names.entityPascal}Model fields and ApiEndpoints.${names.featureCamel}
  3. Navigate with context.go(AppRoutes.${names.featureCamel})
''');
}

class _Options {
  const _Options({required this.feature, required this.entity});

  final String feature;
  final String entity;

  static final RegExp _snake = RegExp(r'^[a-z][a-z0-9_]*$');

  static _Options? parse(List<String> args) {
    String? feature;
    String? entity;
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--entity' && i + 1 < args.length) {
        entity = args[++i];
      } else if (arg.startsWith('--entity=')) {
        entity = arg.substring('--entity='.length);
      } else if (feature == null) {
        feature = arg;
      } else {
        return null;
      }
    }
    if (feature == null || !_snake.hasMatch(feature)) return null;
    entity ??= _singular(feature);
    if (!_snake.hasMatch(entity)) return null;
    return _Options(feature: feature, entity: entity);
  }

  /// Good enough for "orders" → "order", "categories" → "category";
  /// pass --entity for anything else.
  static String _singular(String word) {
    if (word.endsWith('ies')) return '${word.substring(0, word.length - 3)}y';
    if (word.endsWith('ses') || word.endsWith('xes')) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith('s') && !word.endsWith('ss')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }
}

class _Names {
  _Names({required this.feature, required this.entity});

  final String feature;
  final String entity;

  late final String featurePascal = _pascal(feature);
  late final String featureCamel = _camel(feature);
  late final String entityPascal = _pascal(entity);
  late final String entityCamel = _camel(entity);
  late final String featureTitle = feature
      .split('_')
      .map(_capitalize)
      .join(' ');

  static String _pascal(String snake) =>
      snake.split('_').map(_capitalize).join();

  static String _camel(String snake) {
    final pascal = _pascal(snake);
    return pascal[0].toLowerCase() + pascal.substring(1);
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ---------------------------------------------------------------------------
// Wiring into existing files. Each step is best-effort: if an anchor is not
// found the step is reported and left for the developer.
// ---------------------------------------------------------------------------

List<String> _wire(_Names n) {
  final touched = <String>[];

  void edit(String path, String? Function(String source) transform) {
    final file = File(path);
    final result = transform(file.readAsStringSync());
    if (result == null) {
      print('  MANUAL  $path (anchor not found)');
      return;
    }
    file.writeAsStringSync(result);
    touched.add(path);
    print('  update  $path');
  }

  edit(
    'lib/core/network/api_endpoints.dart',
    (src) => _insertBeforeLastBrace(
      src,
      "  static const String ${n.featureCamel} = '/${n.feature}';",
    ),
  );

  edit(
    'lib/app/router/app_routes.dart',
    (src) => _insertBeforeLastBrace(
      src,
      "  static const String ${n.featureCamel} = '/${n.feature}';",
    ),
  );

  edit('lib/app/router/app_router.dart', (src) {
    final withImport = _addRelativeImport(
      src,
      "import '../../features/${n.feature}/presentation/pages/${n.feature}_page.dart';",
    );
    if (withImport == null) return null;
    final anchor = RegExp(r'^( +)GoRoute\(path: .*$', multiLine: true);
    final matches = anchor.allMatches(withImport).toList();
    if (matches.isEmpty) return null;
    final last = matches.last;
    final indent = last.group(1)!;
    final route =
        '\n${indent}GoRoute(path: AppRoutes.${n.featureCamel}, '
        'builder: (_, _) => const ${n.featurePascal}Page()),';
    return withImport.replaceRange(last.end, last.end, route);
  });

  edit('lib/core/di/injection.dart', (src) {
    final withImport = _addRelativeImport(
      src,
      "import '../../features/${n.feature}/${n.feature}_injection.dart';",
    );
    if (withImport == null) return null;
    final anchor = RegExp(
      r'^ +register\w+Dependencies\(getIt\);$',
      multiLine: true,
    );
    final matches = anchor.allMatches(withImport).toList();
    if (matches.isEmpty) return null;
    final last = matches.last;
    return withImport.replaceRange(
      last.end,
      last.end,
      '\n  register${n.featurePascal}Dependencies(getIt);',
    );
  });

  for (final arb in ['lib/l10n/app_en.arb', 'lib/l10n/app_vi.arb']) {
    edit(arb, (src) {
      final close = src.lastIndexOf('}');
      if (close < 0) return null;
      final body = src.substring(0, close).trimRight();
      final needsComma = !body.endsWith('{') && !body.endsWith(',');
      return '$body${needsComma ? ',' : ''}\n'
          '  "${n.featureCamel}Title": "${n.featureTitle}"\n'
          '}\n';
    });
  }

  return touched;
}

String? _insertBeforeLastBrace(String src, String line) {
  final close = src.lastIndexOf('}');
  if (close < 0) return null;
  return '${src.substring(0, close).trimRight()}\n$line\n}\n';
}

/// Adds [import] to the block of relative imports, keeping it sorted so
/// `directives_ordering` stays happy.
String? _addRelativeImport(String src, String import) {
  final lines = src.split('\n');
  bool isRelative(String l) =>
      l.startsWith("import '") &&
      !l.startsWith("import 'package:") &&
      !l.startsWith("import 'dart:");
  final first = lines.indexWhere(isRelative);
  if (first < 0) return null;
  var last = first;
  while (last + 1 < lines.length && isRelative(lines[last + 1])) {
    last++;
  }
  final block = lines.sublist(first, last + 1)..add(import);
  if (block.toSet().length != block.length) return src; // already imported
  block.sort();
  lines.replaceRange(first, last + 1, block);
  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// Templates
// ---------------------------------------------------------------------------

Map<String, String> _templates(_Names n) {
  final f = n.feature;
  final fp = n.featurePascal;
  final fc = n.featureCamel;
  final e = n.entity;
  final ep = n.entityPascal;
  final ec = n.entityCamel;
  final lib = 'lib/features/$f';
  final test = 'test/features/$f';

  return {
    '$lib/domain/entities/$e.dart':
        '''
import 'package:equatable/equatable.dart';

class $ep extends Equatable {
  const $ep({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
''',
    '$lib/domain/repositories/${f}_repository.dart':
        '''
import '../../../../core/error/result.dart';
import '../entities/$e.dart';

abstract interface class ${fp}Repository {
  Future<Result<List<$ep>>> get$fp();
}
''',
    '$lib/domain/usecases/get_${f}_usecase.dart':
        '''
import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/$e.dart';
import '../repositories/${f}_repository.dart';

class Get${fp}UseCase implements UseCase<List<$ep>, NoParams> {
  const Get${fp}UseCase(this._repository);

  final ${fp}Repository _repository;

  @override
  Future<Result<List<$ep>>> call(NoParams params) => _repository.get$fp();
}
''',
    '$lib/data/models/${e}_model.dart':
        '''
import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/$e.dart';

part '${e}_model.g.dart';

/// Wire format of a $ec. Run `make gen` after changing fields.
@JsonSerializable()
class ${ep}Model {
  const ${ep}Model({required this.id, required this.name});

  factory ${ep}Model.fromJson(Map<String, dynamic> json) =>
      _\$${ep}ModelFromJson(json);

  @JsonKey(fromJson: _idFromJson)
  final String id;
  @JsonKey(defaultValue: '')
  final String name;

  Map<String, dynamic> toJson() => _\$${ep}ModelToJson(this);

  $ep toEntity() => $ep(id: id, name: name);
}

String _idFromJson(Object? value) => value.toString();
''',
    '$lib/data/datasources/${f}_remote_data_source.dart':
        '''
import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/request_extra.dart';
import '../models/${e}_model.dart';

/// Throws [DioException] on failure; the repository converts it to a `Failure`.
abstract interface class ${fp}RemoteDataSource {
  Future<List<${ep}Model>> get$fp();
}

class ${fp}RemoteDataSourceImpl implements ${fp}RemoteDataSource {
  const ${fp}RemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<${ep}Model>> get$fp() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.$fc);
    return response.requireData
        .map((item) => ${ep}Model.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
''',
    '$lib/data/datasources/${f}_mock_data_source.dart':
        '''
import '../models/${e}_model.dart';
import '${f}_remote_data_source.dart';

/// Used when `USE_MOCK_API=true` so the app runs without a backend.
class ${fp}MockDataSource implements ${fp}RemoteDataSource {
  const ${fp}MockDataSource();

  static const Duration _latency = Duration(milliseconds: 600);

  @override
  Future<List<${ep}Model>> get$fp() async {
    await Future<void>.delayed(_latency);
    return List.generate(
      5,
      (i) => ${ep}Model(id: '\${i + 1}', name: '${n.featureTitle} \${i + 1}'),
    );
  }
}
''',
    '$lib/data/repositories/${f}_repository_impl.dart':
        '''
import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/$e.dart';
import '../../domain/repositories/${f}_repository.dart';
import '../datasources/${f}_remote_data_source.dart';

class ${fp}RepositoryImpl implements ${fp}Repository {
  const ${fp}RepositoryImpl(this._remote);

  final ${fp}RemoteDataSource _remote;

  @override
  Future<Result<List<$ep>>> get$fp() => guard(() async {
    final models = await _remote.get$fp();
    return models.map((m) => m.toEntity()).toList();
  });
}
''',
    '$lib/presentation/cubit/${f}_cubit.dart':
        '''
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/$e.dart';
import '../../domain/usecases/get_${f}_usecase.dart';

part '${f}_state.dart';

class ${fp}Cubit extends Cubit<${fp}State> {
  ${fp}Cubit(this._get$fp) : super(const ${fp}State());

  final Get${fp}UseCase _get$fp;

  Future<void> load() async {
    emit(state.copyWith(status: ${fp}Status.loading));
    final result = await _get$fp(const NoParams());
    emit(switch (result) {
      Success(:final data) => ${fp}State(
        status: ${fp}Status.success,
        items: data,
      ),
      Failed(:final failure) => state.copyWith(
        status: ${fp}Status.failure,
        failure: failure,
      ),
    });
  }
}
''',
    '$lib/presentation/cubit/${f}_state.dart':
        '''
part of '${f}_cubit.dart';

enum ${fp}Status { initial, loading, success, failure }

final class ${fp}State extends Equatable {
  const ${fp}State({
    this.status = ${fp}Status.initial,
    this.items = const [],
    this.failure,
  });

  final ${fp}Status status;
  final List<$ep> items;
  final Failure? failure;

  ${fp}State copyWith({
    ${fp}Status? status,
    List<$ep>? items,
    Failure? failure,
  }) => ${fp}State(
    status: status ?? this.status,
    items: items ?? this.items,
    failure: failure ?? this.failure,
  );

  @override
  List<Object?> get props => [status, items, failure];
}
''',
    '$lib/presentation/pages/${f}_page.dart':
        '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/extensions/context_x.dart';
import '../../../../core/extensions/failure_x.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../cubit/${f}_cubit.dart';

class ${fp}Page extends StatelessWidget {
  const ${fp}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<${fp}Cubit>()..load(),
      child: const _${fp}View(),
    );
  }
}

class _${fp}View extends StatelessWidget {
  const _${fp}View();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.${fc}Title)),
      body: BlocBuilder<${fp}Cubit, ${fp}State>(
        builder: (context, state) => switch (state.status) {
          ${fp}Status.initial || ${fp}Status.loading => const LoadingView(),
          ${fp}Status.failure => ErrorView(
            message: state.failure!.localizedMessage(context.l10n),
            onRetry: () => context.read<${fp}Cubit>().load(),
          ),
          ${fp}Status.success => RefreshIndicator(
            onRefresh: () => context.read<${fp}Cubit>().load(),
            child: ListView.separated(
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = state.items[index];
                return ListTile(title: Text(item.name), subtitle: Text(item.id));
              },
            ),
          ),
        },
      ),
    );
  }
}
''',
    '$lib/${f}_injection.dart':
        '''
import 'package:get_it/get_it.dart';

import '../../core/config/env.dart';
import 'data/datasources/${f}_mock_data_source.dart';
import 'data/datasources/${f}_remote_data_source.dart';
import 'data/repositories/${f}_repository_impl.dart';
import 'domain/repositories/${f}_repository.dart';
import 'domain/usecases/get_${f}_usecase.dart';
import 'presentation/cubit/${f}_cubit.dart';

void register${fp}Dependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<${fp}RemoteDataSource>(
      () => Env.useMockApi
          ? const ${fp}MockDataSource()
          : ${fp}RemoteDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<${fp}Repository>(
      () => ${fp}RepositoryImpl(getIt()),
    )
    ..registerFactory(() => Get${fp}UseCase(getIt()))
    ..registerFactory(() => ${fp}Cubit(getIt()));
}
''',
    '$test/data/${f}_repository_impl_test.dart':
        '''
import 'package:codebase_flutter/core/error/failure.dart';
import 'package:codebase_flutter/core/error/result.dart';
import 'package:codebase_flutter/features/$f/data/datasources/${f}_remote_data_source.dart';
import 'package:codebase_flutter/features/$f/data/repositories/${f}_repository_impl.dart';
import 'package:codebase_flutter/features/$f/domain/entities/$e.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;

  ${fp}RepositoryImpl build(FakeHandler handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    return ${fp}RepositoryImpl(${fp}RemoteDataSourceImpl(dio));
  }

  test('maps the list response to entities', () async {
    final repository = build(
      (_) => jsonResponse([
        {'id': 1, 'name': 'First'},
        {'id': '2'},
      ]),
    );

    final result = await repository.get$fp();

    expect(adapter.requests.single.path, '/$f');
    expect(
      result,
      const Success<List<$ep>>([
        $ep(id: '1', name: 'First'),
        $ep(id: '2', name: ''),
      ]),
    );
  });

  test('maps server errors to ServerFailure', () async {
    final repository = build((_) => jsonResponse({'message': 'boom'}, 500));

    final result = await repository.get$fp();

    expect(result, isA<Failed<List<$ep>>>());
    final failure = (result as Failed<List<$ep>>).failure;
    expect(failure, isA<ServerFailure>());
    expect((failure as ServerFailure).statusCode, 500);
  });
}
''',
    '$test/presentation/${f}_cubit_test.dart':
        '''
import 'package:bloc_test/bloc_test.dart';
import 'package:codebase_flutter/core/error/failure.dart';
import 'package:codebase_flutter/core/error/result.dart';
import 'package:codebase_flutter/core/usecase/usecase.dart';
import 'package:codebase_flutter/features/$f/domain/entities/$e.dart';
import 'package:codebase_flutter/features/$f/domain/usecases/get_${f}_usecase.dart';
import 'package:codebase_flutter/features/$f/presentation/cubit/${f}_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGet${fp}UseCase extends Mock implements Get${fp}UseCase {}

void main() {
  const items = [$ep(id: '1', name: 'First')];

  late _MockGet${fp}UseCase get$fp;

  setUp(() => get$fp = _MockGet${fp}UseCase());

  blocTest<${fp}Cubit, ${fp}State>(
    'emits [loading, success] with items',
    setUp: () => when(
      () => get$fp(const NoParams()),
    ).thenAnswer((_) async => const Success(items)),
    build: () => ${fp}Cubit(get$fp),
    act: (cubit) => cubit.load(),
    expect: () => const [
      ${fp}State(status: ${fp}Status.loading),
      ${fp}State(status: ${fp}Status.success, items: items),
    ],
  );

  blocTest<${fp}Cubit, ${fp}State>(
    'emits [loading, failure] and keeps previous items',
    seed: () => const ${fp}State(status: ${fp}Status.success, items: items),
    setUp: () => when(
      () => get$fp(const NoParams()),
    ).thenAnswer((_) async => const Failed(NetworkFailure())),
    build: () => ${fp}Cubit(get$fp),
    act: (cubit) => cubit.load(),
    expect: () => const [
      ${fp}State(status: ${fp}Status.loading, items: items),
      ${fp}State(
        status: ${fp}Status.failure,
        items: items,
        failure: NetworkFailure(),
      ),
    ],
  );
}
''',
  };
}
