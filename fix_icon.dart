import 'package:image/image.dart';
import 'dart:io';

void main() {
  final file = File('web/icons/Icon-512.png');
  var original = decodeImage(file.readAsBytesSync())!;

  // Must convert to 4 channels (RGBA) so the PNG encoder inside IcoEncoder doesn't produce corrupted artifacts
  if (original.numChannels == 3) {
    original = original.convert(numChannels: 4);
  }

  // Windows standard ICO sizes
  final sizes = [16, 24, 32, 48, 64, 128, 256];
  final images = <Image>[];

  for (final size in sizes) {
    // cubic interpolation gives best quality for downscaling
    final resized = copyResize(original,
        width: size, height: size, interpolation: Interpolation.cubic);
    images.add(resized);
  }

  final icc = IcoEncoder();
  final icoData = icc.encodeImages(images);

  final icoFile = File('windows/runner/resources/app_icon.ico');
  icoFile.writeAsBytesSync(icoData);
  print(
      'Successfully generated multiresolution app_icon.ico with multiple explicit images and 4-channels');
}
