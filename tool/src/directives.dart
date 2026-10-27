// Shared by the tool scripts: keeps `directives_ordering` happy after a
// generator or rename touched the imports of a Dart file.

/// Sorts every contiguous block of single-line `import 'package:...';`
/// directives alphabetically. Other directive kinds and multi-line imports are
/// left where they are, which is all the generated/renamed code needs.
String sortPackageImports(String source) {
  final lines = source.split('\n');
  final isPackageImport = RegExp(r"^import 'package:[^']+'( as \w+)?;$");
  var start = -1;
  for (var i = 0; i <= lines.length; i++) {
    final inBlock = i < lines.length && isPackageImport.hasMatch(lines[i]);
    if (inBlock && start == -1) start = i;
    if (!inBlock && start != -1) {
      final block = lines.sublist(start, i)..sort();
      lines.replaceRange(start, i, block);
      start = -1;
    }
  }
  return lines.join('\n');
}
