import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads any file to a custom folder in Firebase Storage and returns the download URL
  Future<String?> uploadFile({
    required List<int> fileBytes,
    required String fileExtension,
    required String folderName,
    String? customFileName,
    String? contentType,
  }) async {
    try {
      final String fileName = customFileName ?? 
          '${folderName.replaceAll('/', '_')}_${const Uuid().v4()}.$fileExtension';
      final String path = '$folderName/$fileName';

      final Reference ref = _storage.ref().child(path);
      
      final SettableMetadata metadata = SettableMetadata(
        contentType: contentType ?? _getContentType(fileExtension),
      );

      final UploadTask uploadTask = ref.putData(Uint8List.fromList(fileBytes), metadata);
      final TaskSnapshot snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading file to Firebase Storage: $e');
      return null;
    }
  }

  /// Helper to determine content type from extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  /// Uploads a profile picture
  Future<String?> uploadProfilePicture(
    List<int> fileBytes,
    String fileExtension,
  ) async {
    return uploadFile(
      fileBytes: fileBytes,
      fileExtension: fileExtension,
      folderName: 'profile_pics',
      contentType: 'image/$fileExtension',
    );
  }
  
  /// Uploads a question attachment (image/audio/video)
  Future<String?> uploadQuestionAttachment({
    required List<int> fileBytes,
    required String fileExtension,
    required String type, // 'images', 'audio', 'video'
  }) async {
    return uploadFile(
      fileBytes: fileBytes,
      fileExtension: fileExtension,
      folderName: 'question_$type',
    );
  }
}
