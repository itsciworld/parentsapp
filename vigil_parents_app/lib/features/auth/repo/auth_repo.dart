import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vigil_parents_app/core/services/secure_storage/secure_storage.dart';

class AuthRepository {
  Future<String> login(String email, String password) async {
    final url = Uri.parse(
      'https://vigile-parent-backend.onrender.com/api/auth/login',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        final String? token = responseBody['token'];
        final String? parentId = responseBody['userId'];
        final String? parentName = responseBody['userName'];

        if (token != null) {
          // Save token and other data to secure storage
          await SecureDeviceService.saveAuthData(
            token: token,
            email: email,
            parentId: parentId,
            parentName: parentName,
          );

          return responseBody['msg'] ?? 'Logged in successfully';
        } else {
          throw Exception('Invalid response from server');
        }
      } else {
        throw Exception(responseBody['msg'] ?? 'Unknown error occurred');
      }
    } catch (e) {
      // Re-throw to be caught by the view model
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
