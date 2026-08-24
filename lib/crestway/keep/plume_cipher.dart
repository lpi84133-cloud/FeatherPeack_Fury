import 'dart:convert';
import 'dart:typed_data';

// Position-keyed XOR over a project-unique 12-byte salt. Single pass, no
// state array, no PRGA loop — deliberately unlike the RC4-style KSA/PRGA
// families used by other iOS shells in this portfolio.
//
// The salt is unique to Featherpeak Fury; NEVER copy it to another project.
// Regenerate every encoded byte array in `crest_config.dart` after touching
// this constant by running:
//   dart run tool/forge_crest_values.dart
const List<int> _plumeSalt = <int>[
  0x8E, 0x2A, 0x7C, 0x11, 0xF0, 0x63,
  0xB4, 0xD5, 0x39, 0x9C, 0xEE, 0x47,
];

int _keyStreamByte(int i) {
  final saltByte = _plumeSalt[i % _plumeSalt.length];
  final scramble = ((i * 131) ^ (i >> 3)) & 0xFF;
  return (saltByte ^ scramble) & 0xFF;
}

String unfurl(List<int> encoded) {
  final out = Uint8List(encoded.length);
  for (var i = 0; i < encoded.length; i++) {
    out[i] = (encoded[i] ^ _keyStreamByte(i)) & 0xFF;
  }
  return utf8.decode(out);
}

List<int> furl(String plain) {
  final bytes = utf8.encode(plain);
  final out = List<int>.filled(bytes.length, 0);
  for (var i = 0; i < bytes.length; i++) {
    out[i] = (bytes[i] ^ _keyStreamByte(i)) & 0xFF;
  }
  return out;
}
