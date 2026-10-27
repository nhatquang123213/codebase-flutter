// Renames the template into your app: Dart package, Android applicationId /
// namespace / Kotlin package, iOS bundle id, and the display name per flavor.
//
//   dart run tool/rename_app.dart --name "Acme Shop" --android-id com.acme.shop
//       [--ios-id com.acme.shop] [--package acme_shop] [--dry-run]
//
// Defaults: --ios-id = --android-id with snake_case segments camelCased
// (bundle ids must not contain underscores); --package = last segment of
// --android-id. Current values are read from pubspec.yaml, build.gradle.kts and
// ios/Flutter/Flavors/*.xcconfig, so the script can be re-run with new values.
//
// Prefer `make rename name=... android_id=...`, which also runs pub get + l10n.
import 'dart:io';

import 'src/directives.dart';

const _textExtensions = {
  '.dart', '.yaml', '.yml', '.kts', '.kt', '.gradle', '.xml', '.plist', //
  '.xcconfig', '.pbxproj', '.md', '.json', '.arb', '.sh', '.properties', //
  '.xcscheme', '.txt', '.entitlements',
};
const _textBasenames = {'Makefile', 'Podfile'};

void main(List<String> args) {
  final opts = _Options.parse(args);
  final current = _Current.read();

  stdout
    ..writeln('Dart package : ${current.package} -> ${opts.package}')
    ..writeln('Android id   : ${current.androidId} -> ${opts.androidId}')
    ..writeln('iOS bundle id: ${current.iosId} -> ${opts.iosId}')
    ..writeln('App name     : ${current.prodName} -> ${opts.name}')
    ..writeln('               ${current.devName} -> ${opts.devName}')
    ..writeln('               ${current.stagingName} -> ${opts.stagingName}')
    ..writeln(opts.dryRun ? '(dry run — nothing written)\n' : '');

  final files = _trackedTextFiles();
  final changed = <String>[];

  for (final path in files) {
    final file = File(path);
    final before = file.readAsStringSync();
    var after = before;

    // 1. Identifiers. The Android id is replaced before the bare package name
    //    because it usually contains it (com.codebase.codebase_flutter).
    after = after.replaceAll(current.androidId, opts.androidId);
    after = after.replaceAll(current.iosId, opts.iosId);
    after = after.replaceAll(
      RegExp(
        '(?<![A-Za-z0-9_])${RegExp.escape(current.package)}(?![A-Za-z0-9_])',
      ),
      opts.package,
    );

    // 2. Display names: only where they are declared, plus README prose.
    after = switch (path) {
      'android/app/build.gradle.kts' => _renameGradleFlavors(after, opts),
      'ios/Flutter/Flavors/dev.xcconfig' => _setXcconfigName(
        after,
        opts.devName,
      ),
      'ios/Flutter/Flavors/staging.xcconfig' => _setXcconfigName(
        after,
        opts.stagingName,
      ),
      'ios/Flutter/Flavors/prod.xcconfig' => _setXcconfigName(after, opts.name),
      'ios/Runner/Info.plist' => after.replaceFirstMapped(
        RegExp(r'(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)'),
        (m) => '${m[1]}${opts.name}${m[2]}',
      ),
      'README.md' =>
        after
            .replaceAll(current.devName, opts.devName)
            .replaceAll(current.stagingName, opts.stagingName)
            .replaceAll(current.prodName, opts.name),
      _ when path.startsWith('lib/l10n/') && path.endsWith('.arb') =>
        after.replaceFirst(
          RegExp(r'"appTitle":\s*"[^"]*"'),
          '"appTitle": "${opts.name}"',
        ),
      _ => after,
    };

    // The package name moved in the alphabet, so re-sort package imports.
    if (path.endsWith('.dart')) after = sortPackageImports(after);

    if (after != before) {
      changed.add(path);
      if (!opts.dryRun) file.writeAsStringSync(after);
    }
  }

  // 3. Kotlin sources live in a directory tree that mirrors the package.
  final moved = _moveKotlinSources(
    current.androidId,
    opts.androidId,
    opts.dryRun,
  );

  if (!opts.dryRun) _formatDart(changed);

  stdout.writeln(
    '${opts.dryRun ? 'Would change' : 'Changed'} ${changed.length} file(s):',
  );
  for (final path in [...changed, ...moved]) {
    stdout.writeln('  $path');
  }
  if (!opts.dryRun) {
    stdout
      ..writeln()
      ..writeln('Next steps:')
      ..writeln(
        '  flutter pub get && make l10n   (done for you by `make rename`)',
      )
      ..writeln(
        '  make branding                  (icons + splash for the new app)',
      )
      ..writeln(
        '  make firebase-<flavor>         (re-register the new ids in Firebase)',
      )
      ..writeln(
        '  Re-create keystores / provisioning profiles for the new ids.',
      );
  }
}

/// Longer identifiers can push lines past 80 columns.
void _formatDart(List<String> changed) {
  final dartFiles = changed.where((p) => p.endsWith('.dart')).toList();
  if (dartFiles.isEmpty) return;
  final result = Process.runSync('dart', ['format', ...dartFiles]);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    _fail('dart format failed');
  }
}

String _renameGradleFlavors(String src, _Options opts) {
  // Note: String.replaceFirst does not expand $1, hence replaceFirstMapped.
  String setName(String s, String flavor, String name) => s.replaceFirstMapped(
    RegExp(
      '(create\\("$flavor"\\)\\s*\\{[\\s\\S]*?resValue\\("string",\\s*"app_name",\\s*")[^"]*(")',
    ),
    (m) => '${m[1]}$name${m[2]}',
  );
  var out = src;
  out = setName(out, 'dev', opts.devName);
  out = setName(out, 'staging', opts.stagingName);
  out = setName(out, 'prod', opts.name);
  return out;
}

String _setXcconfigName(String src, String name) => src.replaceFirst(
  RegExp(r'^APP_DISPLAY_NAME = .*$', multiLine: true),
  'APP_DISPLAY_NAME = $name',
);

List<String> _moveKotlinSources(String oldId, String newId, bool dryRun) {
  if (oldId == newId) return const [];
  final oldPath = oldId.replaceAll('.', '/');
  final newPath = newId.replaceAll('.', '/');
  final moved = <String>[];
  final srcRoot = Directory('android/app/src');
  if (!srcRoot.existsSync()) return moved;

  for (final sourceSet in srcRoot.listSync().whereType<Directory>()) {
    final oldDir = Directory('${sourceSet.path}/kotlin/$oldPath');
    if (!oldDir.existsSync()) continue;
    final newDir = Directory('${sourceSet.path}/kotlin/$newPath');
    for (final entity in oldDir.listSync(recursive: true).whereType<File>()) {
      final relative = entity.path.substring(oldDir.path.length + 1);
      final target = File('${newDir.path}/$relative');
      moved.add('${entity.path} -> ${target.path}');
      if (dryRun) continue;
      target.parent.createSync(recursive: true);
      entity.renameSync(target.path);
    }
    if (!dryRun) {
      _removeEmptyDirs(oldDir, stopAt: Directory('${sourceSet.path}/kotlin'));
    }
  }
  return moved;
}

/// Deletes [dir] and its now-empty parents up to (not including) [stopAt].
void _removeEmptyDirs(Directory dir, {required Directory stopAt}) {
  var current = dir;
  while (current.path != stopAt.path && current.existsSync()) {
    if (current.listSync().isNotEmpty) break;
    current.deleteSync();
    current = current.parent;
  }
}

List<String> _trackedTextFiles() {
  final result = Process.runSync('git', ['ls-files', '-z']);
  if (result.exitCode != 0) {
    _fail('git ls-files failed: ${result.stderr}');
  }
  return (result.stdout as String)
      .split('\x00')
      .where((p) => p.isNotEmpty)
      .where((p) {
        final base = p.split('/').last;
        final dot = base.lastIndexOf('.');
        final ext = dot == -1 ? '' : base.substring(dot);
        return _textBasenames.contains(base) || _textExtensions.contains(ext);
      })
      .where((p) => File(p).existsSync())
      .toList();
}

class _Current {
  _Current({
    required this.package,
    required this.androidId,
    required this.iosId,
    required this.devName,
    required this.stagingName,
    required this.prodName,
  });

  final String package;
  final String androidId;
  final String iosId;
  final String devName;
  final String stagingName;
  final String prodName;

  static _Current read() {
    String match(String path, RegExp re) {
      final m = re.firstMatch(File(path).readAsStringSync());
      if (m == null) _fail('Could not find ${re.pattern} in $path');
      return m.group(1)!;
    }

    final nameRe = RegExp(r'^APP_DISPLAY_NAME = (.+)$', multiLine: true);
    return _Current(
      package: match(
        'pubspec.yaml',
        RegExp(r'^name:\s*(\S+)', multiLine: true),
      ),
      androidId: match(
        'android/app/build.gradle.kts',
        RegExp(r'applicationId\s*=\s*"([^"]+)"'),
      ),
      iosId: match(
        'ios/Flutter/Flavors/prod.xcconfig',
        RegExp(r'^PRODUCT_BUNDLE_IDENTIFIER = (\S+)$', multiLine: true),
      ),
      devName: match('ios/Flutter/Flavors/dev.xcconfig', nameRe).trim(),
      stagingName: match('ios/Flutter/Flavors/staging.xcconfig', nameRe).trim(),
      prodName: match('ios/Flutter/Flavors/prod.xcconfig', nameRe).trim(),
    );
  }
}

class _Options {
  _Options({
    required this.name,
    required this.androidId,
    required this.iosId,
    required this.package,
    required this.dryRun,
  });

  final String name;
  final String androidId;
  final String iosId;
  final String package;
  final bool dryRun;

  String get devName => '$name Dev';
  String get stagingName => '$name Staging';

  static _Options parse(List<String> args) {
    String? name, androidId, iosId, package;
    var dryRun = false;
    for (var i = 0; i < args.length; i++) {
      String next() {
        if (i + 1 >= args.length) _fail('Missing value for ${args[i]}');
        return args[++i];
      }

      switch (args[i]) {
        case '--name':
          name = next();
        case '--android-id':
          androidId = next();
        case '--ios-id':
          iosId = next();
        case '--package':
          package = next();
        case '--dry-run':
          dryRun = true;
        case '-h' || '--help':
          _usage();
        default:
          _fail('Unknown argument: ${args[i]}');
      }
    }
    if (name == null || name.trim().isEmpty) _fail('--name is required');
    if (androidId == null) _fail('--android-id is required');
    if (name.contains('"')) _fail('--name must not contain quotes');
    if (!RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$').hasMatch(androidId)) {
      _fail(
        'Invalid --android-id "$androidId": expected e.g. com.company.app '
        '(lowercase, 2+ segments, segments start with a letter)',
      );
    }
    iosId ??= androidId
        .split('.')
        .map(
          (seg) => seg
              .split('_')
              .indexed
              .map((e) => e.$1 == 0 ? e.$2 : _capitalize(e.$2))
              .join(),
        )
        .join('.');
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.-]*$').hasMatch(iosId)) {
      _fail(
        'Invalid --ios-id "$iosId": only letters, digits, dots and hyphens '
        '(no underscores)',
      );
    }
    package ??= androidId.split('.').last;
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(package)) {
      _fail('Invalid --package "$package": expected snake_case');
    }
    return _Options(
      name: name.trim(),
      androidId: androidId,
      iosId: iosId,
      package: package,
      dryRun: dryRun,
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

Never _usage() {
  stdout.writeln(
    'Usage: dart run tool/rename_app.dart --name "App Name" '
    '--android-id com.company.app [--ios-id com.company.app] '
    '[--package app_name] [--dry-run]',
  );
  exit(0);
}

Never _fail(String message) {
  stderr.writeln('Error: $message');
  exit(64);
}
