import 'dart:convert';
import 'package:http/http.dart' as http;

/// Modern HTTP service to replace the HTTP methods in the legacy Net class
class HttpService {
  final String baseUrl;
  
  HttpService({required this.baseUrl}) {
    print('🔍 HttpService created with baseUrl: $baseUrl');
  }
  
  Future<http.Response> getDB(String route) async {
    print('🔍 HttpService.getDB: $route');
    return await http.get(Uri.parse(baseUrl + route), headers: <String, String>{
      "Content-Type": "application/json; charset=UTF-8",
    });
  }

  Future<http.Response> postDB(String route, Map<String, dynamic> json) async {
    print('🔍 HttpService.postDB: $route');
    return await http.post(Uri.parse(baseUrl + route),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: jsonEncode(json));
  }

  Future<http.Response> updateDB(String route, Map<String, dynamic> json) async {
    print('🔍 HttpService.updateDB: $route');
    return await http.post(Uri.parse(baseUrl + route),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: jsonEncode(json));
  }

  Future<http.Response> deleteDB(String route) async {
    print('🔍 HttpService.deleteDB: $route');
    return await http.delete(Uri.parse(baseUrl + route), headers: <String, String>{
      "Content-Type": "application/json; charset=UTF-8",
    });
  }

  Future<http.Response> deleteUser(String route, String email) async {
    print('🔍 HttpService.deleteUser: $route, email: $email');
    return await http.delete(Uri.parse("$baseUrl$route?email=$email"),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        });
  }

  Future<http.Response> login(String userName, String password) async {
    print('🔍 HttpService.login: username: $userName');
    return await http.post(Uri.parse("$baseUrl/Login"),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: jsonEncode(<String, String>{
          "email": userName,
          "password": password,
        }));
  }

  Future<http.Response> signup(String userName, String password) async {
    print('🔍 HttpService.signup: username: $userName');
    return await http.post(Uri.parse("$baseUrl/Signup"),
        headers: <String, String>{
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: jsonEncode(<String, String>{
          "email": userName,
          "password": password,
        }));
  }
}
