import 'package:image/image.dart';
import 'dart:io';

void main() {
  final decoder = IcoDecoder();
  final icostruct = decoder.decode(File('test.ico').readAsBytesSync());
  if (icostruct != null) {
    print('frames inside test.ico: ${icostruct.numFrames}');
    for (int i = 0; i < icostruct.numFrames; i++) {
      print(
          'Frame $i: ${icostruct.frames[i].width} x ${icostruct.frames[i].height}');
    }
  }
}
