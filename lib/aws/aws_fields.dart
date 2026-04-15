import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String subFolderName = "p140";

/// base url for AWS
final baseUrl = "https://go.atlassyguld.info/";
// "https://d1r9c4nksnam33.cloudfront.net/";
final String baseUrlForUploadPostApi = "${baseUrl}upload";
final String baseUrlToFetchStaticImage = "$baseUrl$bundleNameToFetchImage";
final String baseUrlToUploadAndFetchUsersImage =
    "$baseUrl${bundleNameToFetchImage}upload";
const String bundleNameForPostAPI = "app";
//  "p97";

/// it will be fixed, it will never changed
String get bundleNameToFetchImage => "";

/// w04/ in testing

/// it will be empty for production, will be 388/ for testing
String getUrlForUserUploadedImage(String imageName) {
  if (imageName.startsWith("http")) {
    return imageName;
  }
  if (imageName.startsWith("/")) {
    return baseUrlToUploadAndFetchUsersImage + imageName;
  }
  return "$baseUrlToUploadAndFetchUsersImage/$subFolderName/$imageName";
}

Future<String?> uploadImageToAWS({
  required File file,
  required String fileName,
}) async {
  String? url = await getSignedUrl(fileName, bundleNameForPostAPI);
  if (url != null && url.isNotEmpty) {
    return await uploadFileToS3(
      signedUrl: url,
      filePath: file.path,
      fileName: fileName,
    );
  }
  return null;
}

Future<String?> getSignedUrl(String fileName, String bundle) async {
  String folderFileName = "$subFolderName/$fileName";
  final Map<String, String> payload = {
    'fileName': folderFileName, // image.png
    'bundle': bundle,
  };
  debugPrint("folderFileName: $folderFileName");

  // Convert the payload to JSON
  final String jsonPayload = json.encode(payload);

  try {
    // Make the PUT request
    final response = await http.post(
      Uri.parse(baseUrlForUploadPostApi),
      headers: {'Content-Type': 'application/json'},
      body: jsonPayload,
    );

    // Check the response status
    if (response.statusCode == 200) {
      debugPrint('getSignedUrl Request successful: ${response.body}');
      Map map = json.decode(response.body);
      if (map.containsKey("data")) {
        String signedUrl = map['data'];
        return signedUrl;
      }
    } else {
      debugPrint(
        'getSignedUrl Failed request: ${response.statusCode} : ${response.body}',
      );
    }
  } catch (e) {
    debugPrint('getSignedUrl Error: $e');
  }
  return null;
}

Future<String?> uploadFileToS3({
  required String signedUrl,
  required String filePath,
  required String fileName,
}) async {
  try {
    // Create a File object from the provided file path
    final file = File(filePath);

    // Make sure the file exists
    if (await file.exists()) {
      // Read the file as bytes
      final fileBytes = await file.readAsBytes();

      // Send a PUT request with the file bytes as the body
      final response = await http.put(
        Uri.parse(signedUrl), // The signed URL provided
        headers: {
          'Content-Type':
              'application/octet-stream', // Ensure the correct content type
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes, // Send the file content as the body
      );
      // debugPrint("File uploaded string [${(await response).toString()}]");
      // Check if the upload was successful
      if (response.statusCode == 200) {
        debugPrint("File uploaded body [${response.body}]");
        // Map map = json.decode(response.body);

        debugPrint(
          'File uploaded successfully! at path ${getUrlForUserUploadedImage(fileName)}',
        );
        return fileName;
      } else {
        debugPrint(
          'File uploaded Failed to upload file: ${response.statusCode} : ${response.body}',
        );
        debugPrint(response.body);
      }
    } else {
      debugPrint(
        'File uploaded File not found at the specified path: $filePath',
      );
    }
  } catch (e) {
    debugPrint('File uploaded Error uploading file: $e');
  }

  return null;
}
