import 'package:image/image.dart';
import 'dart:io';

void main() {
  final img = decodeImage(File('web/icons/Icon-512.png').readAsBytesSync())!;
  final p = img.getPixel(0, 0);
  print('pixel 0,0: ${p.r}, ${p.g}, ${p.b}');
}
