// Generates placeholder branding images (app icon, adaptive foreground,
// splash glyph) per flavor so `make branding` works out of the box.
//
//   dart run tool/placeholder_branding.dart [--out assets/branding]
//
// Replace the PNGs under assets/branding/<flavor>/ with real artwork, then
// re-run `make branding`. This script is only for the placeholders; it writes
// PNGs by hand so it needs no image package.
import 'dart:io';
import 'dart:typed_data';

const _flavors = {
  'dev': 0xF97316, // orange
  'staging': 0x7C3AED, // purple
  'prod': 0x2563EB, // blue — same seed as AppTheme
};

void main(List<String> args) {
  var out = 'assets/branding';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) out = args[++i];
  }

  for (final entry in _flavors.entries) {
    final dir = Directory('$out/${entry.key}')..createSync(recursive: true);
    final color = entry.value;
    // Full-bleed icon: colored background + glyph. 1024px as the stores want.
    _write('${dir.path}/icon.png', _render(1024, color, background: color));
    // Adaptive icon foreground / Android 12 splash icon: transparent
    // background, glyph inside the 66% safe zone.
    _write('${dir.path}/icon_foreground.png', _render(1024, color));
    // Splash glyph. flutter_native_splash treats the source as xxxhdpi/3x,
    // so 512px ≈ 128dp on Android and ≈170pt on iOS.
    _write('${dir.path}/splash.png', _render(512, color));
    stdout.writeln('${dir.path}: icon.png, icon_foreground.png, splash.png');
  }
}

/// A white ring with a colored dot. Boring on purpose: it is a placeholder.
Uint8List _render(int size, int color, {int? background}) {
  final pixels = Uint8List(size * size * 4);
  final center = size / 2;
  final outer = size * 0.28;
  final inner = size * 0.12;
  final r = (color >> 16) & 0xFF, g = (color >> 8) & 0xFF, b = color & 0xFF;

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x + 0.5 - center, dy = y + 0.5 - center;
      final d = _sqrt(dx * dx + dy * dy);
      final ringCov = _coverage(outer - d);
      final dotCov = _coverage(inner - d);

      // Composite: background → white ring → colored dot.
      var pr = 0.0, pg = 0.0, pb = 0.0, pa = 0.0;
      if (background != null) {
        pr = r.toDouble();
        pg = g.toDouble();
        pb = b.toDouble();
        pa = 1;
      }
      (pr, pg, pb, pa) = _over(pr, pg, pb, pa, 255, 255, 255, ringCov);
      (pr, pg, pb, pa) = _over(pr, pg, pb, pa, r, g, b, dotCov);

      final i = (y * size + x) * 4;
      pixels[i] = pr.round();
      pixels[i + 1] = pg.round();
      pixels[i + 2] = pb.round();
      pixels[i + 3] = (pa * 255).round();
    }
  }
  return _encodePng(size, size, pixels);
}

/// Anti-aliased coverage of a pixel whose center is [signedDistance] inside
/// an edge (positive = inside).
double _coverage(double signedDistance) =>
    (signedDistance + 0.5).clamp(0.0, 1.0);

/// Source-over compositing of an opaque color with coverage [a] onto a
/// premultiplied-free (straight alpha) destination.
(double, double, double, double) _over(
  double dr,
  double dg,
  double db,
  double da,
  int sr,
  int sg,
  int sb,
  double a,
) {
  if (a == 0) return (dr, dg, db, da);
  final outA = a + da * (1 - a);
  double blend(double d, int s) => (s * a + d * da * (1 - a)) / outA;
  return (blend(dr, sr), blend(dg, sg), blend(db, sb), outA);
}

double _sqrt(double v) {
  // Newton iterations are plenty for pixel distances; avoids dart:math import
  // noise in a tool file. (dart:math would be fine too.)
  if (v == 0) return 0;
  var x = v;
  for (var i = 0; i < 20; i++) {
    x = 0.5 * (x + v / x);
  }
  return x;
}

// ---- Minimal PNG encoder (RGBA8, no filtering) ----

Uint8List _encodePng(int width, int height, Uint8List rgba) {
  final raw = BytesBuilder(copy: false);
  final stride = width * 4;
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: none
    raw.add(Uint8List.sublistView(rgba, y * stride, (y + 1) * stride));
  }
  final idat = ZLibEncoder(level: 9).convert(raw.takeBytes());

  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // color type RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);

  final png = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _chunk(png, 'IHDR', ihdr.buffer.asUint8List());
  _chunk(png, 'IDAT', Uint8List.fromList(idat));
  _chunk(png, 'IEND', Uint8List(0));
  return png.takeBytes();
}

void _chunk(BytesBuilder out, String type, Uint8List data) {
  final typeBytes = Uint8List.fromList(type.codeUnits);
  final len = ByteData(4)..setUint32(0, data.length);
  out
    ..add(len.buffer.asUint8List())
    ..add(typeBytes)
    ..add(data);
  final crcInput = Uint8List(typeBytes.length + data.length)
    ..setAll(0, typeBytes)
    ..setAll(typeBytes.length, data);
  final crc = ByteData(4)..setUint32(0, _crc32(crcInput));
  out.add(crc.buffer.asUint8List());
}

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(Uint8List bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

void _write(String path, Uint8List bytes) => File(path).writeAsBytesSync(bytes);
