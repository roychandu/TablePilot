// The parameter class to hold the file path and the compressed image path
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
 
class CompressImageParams {
  String imgFilePath;
  String compressedImagePath;

  CompressImageParams(this.imgFilePath, this.compressedImagePath);
}

// This function will run inside the isolate
Future<CompressImageParams> compressImageInIsolate(
    CompressImageParams params) async {
  try {
    final imgFile = File(params.imgFilePath);
    final bytes = await imgFile.readAsBytes();
    final image = img.decodeImage(Uint8List.fromList(bytes));

    // Compress the image to reduce size
    final compressedImage =
        img.encodeJpg(image!, quality: 40); // Adjust quality as needed

    // Save the compressed image to a temporary directory

    final compressedFile = File(params.compressedImagePath);

    await compressedFile.writeAsBytes(compressedImage);

    params.compressedImagePath = compressedFile.path;

    return params;
  } catch (e) {
    debugPrint("Error during image compression: $e");
    return params; // Return original image path in case of error
  }
}

Future<File> pickAndCompressImage(File imgFile) async {
  debugPrint('Image sizes before');
  final tempDir = await getTemporaryDirectory();
  final compressedImagePath =
      '${tempDir.path}/imgid_${DateTime.now().millisecondsSinceEpoch}_compressed_image.jpg';

  CompressImageParams params =
      CompressImageParams(imgFile.path, compressedImagePath);
  params = await compute(compressImageInIsolate, params);
  final orgImageSize = await imgFile.length();
  File compressedFile = File(params.compressedImagePath);
  final compressedImageSize = await (compressedFile).length();

  debugPrint(
      'Image sizes in after { $compressedImageSize/$orgImageSize scale : ${orgImageSize / compressedImageSize} } compressed and saved at: ');

  return compressedFile;
}
