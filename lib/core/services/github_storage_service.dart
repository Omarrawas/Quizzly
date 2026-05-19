import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class GithubStorageService {
  // ⚠️ Store this token securely. Never hardcode in source.
  // Set via --dart-define=GITHUB_TOKEN=... at build time.
  static const String _githubToken = String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');
  static const String _githubOwner =
      'Omarrawas'; // Replace with the actual GitHub username/organization if different
  static const String _repoName = 'doraty-files';
  static const String _branch = 'main';

  final Dio _dio;

  GithubStorageService() : _dio = Dio() {
    _dio.options.headers = {
      'Authorization': 'Bearer $_githubToken',
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };
  }

  /// Uploads a file to GitHub and returns the raw URL
  Future<String?> uploadProfilePicture(
    List<int> fileBytes,
    String fileExtension,
  ) async {
    try {
      final String fileName = 'profile_${const Uuid().v4()}.$fileExtension';
      final String path = 'profile_pics/$fileName';

      final String base64Content = base64Encode(fileBytes);

      final response = await _dio.put(
        'https://api.github.com/repos/$_githubOwner/$_repoName/contents/$path',
        data: {
          'message': 'Upload profile picture $fileName',
          'content': base64Content,
          'branch': _branch,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Construct the raw URL
        return 'https://raw.githubusercontent.com/$_githubOwner/$_repoName/$_branch/$path';
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading to GitHub: $e');
      return null;
    }
  }
}
