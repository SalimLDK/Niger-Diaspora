import 'dart:typed_data';

/// Forme hexadécimale `\x…` d'un `bytea`, telle que PostgREST l'attend en
/// entrée et la rend en sortie. Le base64 aurait été plus court, mais
/// PostgREST ne le lit pas pour ce type.
String versBytea(Uint8List octets) {
  final b = StringBuffer(r'\x');
  for (final o in octets) {
    b.write(o.toRadixString(16).padLeft(2, '0'));
  }
  return b.toString();
}

Uint8List depuisBytea(String hex) {
  final h = hex.startsWith(r'\x') ? hex.substring(2) : hex;
  final out = Uint8List(h.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
