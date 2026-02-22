import 'package:image/image.dart';
import 'dart:io';

void main() {
  final file = File('web/icons/Icon-512.png');
  final original = decodeImage(file.readAsBytesSync())!;

  final sizes = [16, 32, 48, 64, 128, 256];
  final images = <Image>[];

  for (final size in sizes) {
    images.add(copyResize(original,
        width: size, height: size, interpolation: Interpolation.average));
  }

  // Create an ICO with multiple frames
  for (int i = 1; i < images.length; i++) {
    images[0].addFrame(images[i]);
  }

  final icoData = encodeIco(images[0]);
  File('test.ico').writeAsBytesSync(icoData);
  print('test.ico created with sizes: ${images[0].frames.length}');
}
