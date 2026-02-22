import 'package:image/image.dart';
import 'dart:io';

void main() {
  final img = decodeImage(File('web/icons/Icon-512.png').readAsBytesSync())!;
  print(
      'width: ${img.width}, height: ${img.height}, channels: ${img.numChannels}');

  bool hasTrans = false;
  for (final p in img) {
    if (p.a < 255) {
      hasTrans = true;
      break;
    }
  }
  print('has transparency: $hasTrans');
}
