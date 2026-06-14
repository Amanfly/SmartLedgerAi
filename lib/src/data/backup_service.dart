import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(googleSignInProvider));
});

class BackupService {
  BackupService(this._googleSignIn);
  final GoogleSignIn _googleSignIn;

  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account != null;
    } catch (e) {
      // For debugging: return a BackupResult or similar with the error
      print('Google Sign-In Error: $e');
      rethrow; // Rethrow to let the UI catch it or see it in logs
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<GoogleSignInAccount?> get currentUser async => _googleSignIn.currentUser;

  Future<BackupResult> backupToGoogleDrive() async {
    final account = _googleSignIn.currentUser;
    if (account == null) {
      return const BackupResult.pendingConfiguration('Google account not connected.');
    }

    try {
      final authHeaders = await account.authHeaders;
      final authenticateClient = _GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'smartledger.sqlite'));
      if (!await file.exists()) {
        return const BackupResult.error('Database file not found.');
      }

      final media = drive.Media(file.openRead(), await file.length());
      final driveFile = drive.File();
      driveFile.name = 'smartledger_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite';

      // Simple implementation: always creates a new file. 
      // In production, you'd probably search for an existing one to update.
      await driveApi.files.create(driveFile, uploadMedia: media);

      return const BackupResult.ok('Backup successful.');
    } catch (e) {
      return BackupResult.error('Backup failed: $e');
    }
  }

  Future<BackupResult> restoreFromGoogleDrive() async {
    // Restore logic would involve listing files, choosing the latest, and downloading.
    return const BackupResult.pendingConfiguration(
      'Restore logic requires file selection UI.',
    );
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class BackupResult {
  const BackupResult._(this.success, this.message);

  const BackupResult.pendingConfiguration(String message) : this._(false, message);
  const BackupResult.ok(String message) : this._(true, message);
  const BackupResult.error(String message) : this._(false, message);

  final bool success;
  final String message;
}
