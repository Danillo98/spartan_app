import 'package:image/image.dart';
import 'dart:io';

void main() {
  final file = File('web/icons/Icon-512.png');
  var original = decodeImage(file.readAsBytesSync())!;

  if (original.numChannels == 3) {
    print('Converting to 4 channels...');
    original = original.convert(numChannels: 4);
  }

  final sizes = [16, 24, 32, 48, 64, 128, 256];
  final images = <Image>[];

  for (final size in sizes) {
    images.add(copyResize(original,
        width: size, height: size, interpolation: Interpolation.average));
  }

  final icc = IcoEncoder();
  final icoData = icc.encodeImages(images);
  File('test2.ico').writeAsBytesSync(icoData);
  print('Generated test2.ico');
}
