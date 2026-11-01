import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class ApiService {
  // Cloudflare forwards this same-origin prefix to the existing Flask routes.
  // Native/local clients can override with --dart-define=API_BASE_URL=https://...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL', defaultValue: '/api',
  );

  // ── TOKEN MANAGEMENT ──
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }



  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  static Future<Map<String, String>> get _headers async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ════════════════════════════
  //  AUTH
  // ════════════════════════════

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await saveToken(data['token']);
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Could not connect to server'};
    }
  }

  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Could not connect to server'};
    }
  }

  static Future<void> logout() async {
    await clearToken();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // ════════════════════════════
  //  TRANSACTIONS
  // ════════════════════════════
  
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final headers = await _headers;
      final response = await http.get(Uri.parse('$baseUrl/transactions'), headers: headers);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<bool> addTransaction(Map<String, dynamic> transactionMap) async {
    try {
      final headers = await _headers;
      final response = await http.post(Uri.parse('$baseUrl/transactions'), headers: headers, body: jsonEncode(transactionMap));
      if (response.statusCode == 401) await clearToken();
      return response.statusCode == 201;
    } catch (e) { return false; }
  }

  static Future<bool> clearTransactions(String period) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/transactions/clear?period=$period'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ════════════════════════════
  //  GOALS
  // ════════════════════════════

  static Future<List<Map<String, dynamic>>> getGoals() async {
    try {
      final headers = await _headers;
      final response = await http.get(
        Uri.parse('$baseUrl/goals'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching goals: $e');
      return [];
    }
  }

  static Future<bool> addGoal(Map<String, dynamic> goalMap) async {
    try {
      final headers = await _headers;
      final response = await http.post(
        Uri.parse('$baseUrl/goals'),
        headers: headers,
        body: jsonEncode(goalMap),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Error adding goal: $e');
      return false;
    }
  }

  static Future<bool> updateGoal(int id, Map<String, dynamic> goalMap) async {
    try {
      final headers = await _headers;
      final response = await http.put(
        Uri.parse('$baseUrl/goals/$id'),
        headers: headers,
        body: jsonEncode(goalMap),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating goal: $e');
      return false;
    }
  }

  static Future<bool> deleteGoal(int id) async {
    try {
      final token = await getToken();
      final url = '$baseUrl/goals/$id'; // Fixed path without /api/
      
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Delete Goal Error: $e');
      return false;
    }
  }

  // ════════════════════════════
  //  NOTIFICATIONS
  // ════════════════════════════

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final headers = await _headers;
      final response = await http.get(Uri.parse('$baseUrl/notifications'), headers: headers);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<bool> addNotification(Map<String, dynamic> notifMap) async {
    try {
      final headers = await _headers;
      final response = await http.post(
        Uri.parse('$baseUrl/notifications'), 
        headers: headers, 
        body: jsonEncode(notifMap)
      );
      return response.statusCode == 201;
    } catch (e) { return false; }
  }

  static Future<bool> markAllNotificationsRead() async {
    try {
      final headers = await _headers;
      final response = await http.put(Uri.parse('$baseUrl/notifications/mark-all-read'), headers: headers);
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  // ════════════════════════════
  //  USER PROFILE / SETTINGS
  // ════════════════════════════
  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final headers = await _headers;
      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final headers = await _headers;
      final response = await http.get(Uri.parse('$baseUrl/auth/profile'), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
         try {
           return jsonDecode(response.body);
         } catch (_) {
           return {'success': false, 'message': 'Server error: ${response.statusCode}'};
         }
      }
      
      return jsonDecode(response.body);
    } catch (e) {
      print('Forgot Password Error: $e'); 
      return {'success': false, 'message': 'Could not connect to server'};
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp, 'new_password': newPassword}),
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
         try {
           return jsonDecode(response.body);
         } catch (_) {
           return {'success': false, 'message': 'Server error: ${response.statusCode}'};
         }
      }

      return jsonDecode(response.body);
    } catch (e) {
      print('Reset Password Error: $e');
      return {'success': false, 'message': 'Could not connect to server'};
    }
  }
  // ════════════════════════════
  //  SUBSCRIPTIONS
  // ════════════════════════════

  static Future<List<Map<String, dynamic>>> getSubscriptions() async {
    try {
      final headers = await _headers;
      final response = await http.get(Uri.parse('$baseUrl/subscriptions'), headers: headers);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching subscriptions: $e');
      return [];
    }
  }

  static Future<bool> addSubscription(Map<String, dynamic> subMap) async {
    try {
      final headers = await _headers;
      final response = await http.post(
        Uri.parse('$baseUrl/subscriptions'),
        headers: headers,
        body: jsonEncode(subMap),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Error adding subscription: $e');
      return false;
    }
  }

  static Future<bool> updateSubscription(int id, Map<String, dynamic> subMap) async {
    try {
      final headers = await _headers;
      final response = await http.put(
        Uri.parse('$baseUrl/subscriptions/$id'),
        headers: headers,
        body: jsonEncode(subMap),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating subscription: $e');
      return false;
    }
  }

  static Future<bool> deleteSubscription(int id) async {
    try {
      final headers = await _headers;
      final response = await http.delete(
        Uri.parse('$baseUrl/subscriptions/$id'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting subscription: $e');
      return false;
    }
  }
  static Future<bool> updateTransaction(int id, Map<String, dynamic> data) async {
    try {
      final headers = await _headers;
      final response = await http.put(Uri.parse('$baseUrl/transactions/$id'), headers: headers, body: jsonEncode(data));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteTransaction(int id) async {
    try {
      final headers = await _headers;
      final response = await http.delete(Uri.parse('$baseUrl/transactions/$id'), headers: headers);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
 // ── MAGIC ENTRY API ──
static Future<Map<String, dynamic>?> sendMagicEntry(String text) async {
  try {
    final headers = await _headers;
    final response = await http.post(
      Uri.parse('$baseUrl/api/magic/entry'), 
      headers: headers,
      body: jsonEncode({'text': text}),
    );
    
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      // Flask returns {'message': '...', 'transaction': {...}}
      // We want to return that transaction object!
      return data['transaction']; 
    }
    return null; 
  } catch (e) {
    return null;
  }
}
  // ════════════════════════════
  //  CATEGORIES
  // ════════════════════════════
  static Future<bool> addCategory(String name) async {
    try {
      final headers = await _headers;
      final response = await http.post(
        Uri.parse('$baseUrl/categories'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'icon': 'category',   // Default icon
          'color': '#3EB489'    // Default color
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Error adding category: $e');
      return false;
    }
  }
  static Future<bool> deleteCategoryByName(String name) async {
    try {
      final token = await getToken();
      // ── ADDED ENCODING FOR SPACES ──
      final encodedName = Uri.encodeComponent(name); 
      final response = await http.delete(
        Uri.parse('$baseUrl/categories/by-name/$encodedName'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateCategoryByName(String oldName, String newName) async {
    try {
      final headers = await _headers;
      // ── ADDED ENCODING FOR SPACES ──
      final encodedOldName = Uri.encodeComponent(oldName);
      final response = await http.put(
        Uri.parse('$baseUrl/categories/by-name/$encodedOldName'),
        headers: headers,
        body: jsonEncode({'new_name': newName}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  // ════════════════════════════
  //  OUTINGS
  // ════════════════════════════
  
  static Future<List<Map<String, dynamic>>> getOutings() async {
    try {
      final headers = await _headers;
      final response = await http.get(Uri.parse('$baseUrl/outings'), headers: headers);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> addOuting(Map<String, dynamic> outingData) async {
    try {
      final headers = await _headers;
      final response = await http.post(
        Uri.parse('$baseUrl/outings'),
        headers: headers,
        body: jsonEncode(outingData),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateOutingDebt(int debtId, Map<String, dynamic> debtData) async {
    try {
      final headers = await _headers;
      final response = await http.put(
        Uri.parse('$baseUrl/outings/debt/$debtId'),
        headers: headers,
        body: jsonEncode(debtData),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  static Future<bool> deleteOuting(int id) async {
    try {
      final headers = await _headers;
      final response = await http.delete(Uri.parse('$baseUrl/outings/$id'), headers: headers);
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<bool> updateOuting(int id, Map<String, dynamic> data) async {
    try {
      final headers = await _headers;
      final response = await http.put(Uri.parse('$baseUrl/outings/$id'), headers: headers, body: jsonEncode(data));
      return response.statusCode == 200;
    } catch (e) { return false; }
  }
  // ── 5. ONCE-A-DAY DEBT CHECK ──
  static Future<void> checkDailyDebtReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10); // Format: YYYY-MM-DD
      final lastReminder = prefs.getString('last_debt_reminder');

      // If we already reminded them today, skip it!
      if (lastReminder == today) return; 

      // Fetch active outings to check balances
      final outings = await getOutings();
      if (outings.isEmpty) return;

      double toReceive = 0.0;
      double toPay = 0.0;

      for (var outing in outings) {
        for (var friend in outing['friends']) {
          if (!friend['is_settled']) {
            if (friend['is_owed_to_me']) {
              toReceive += (friend['amount'] as num).toDouble();
            } else {
              toPay += (friend['amount'] as num).toDouble();
            }
          }
        }
      }

      // If there are debts, fire the alerts!
      if (toReceive > 0 || toPay > 0) {
        // 1. Fire Local Push Notification
        // (Make sure to import NotificationService at the top of api_service.dart)
        await NotificationService.showDebtReminder(toReceive: toReceive, toPay: toPay);

        // 2. Save an in-app notification to your database
        await addNotification({
          'title': 'Pending Outing Debts',
          'message': 'You have pending splits! To Receive: ₹${toReceive.toStringAsFixed(0)} | To Pay: ₹${toPay.toStringAsFixed(0)}',
          'type': 'warning'
        });

        // 3. Mark today as reminded
        await prefs.setString('last_debt_reminder', today);
      }
    } catch (e) {
      print('Failed to check daily debts: $e');
    }
  }
  // ── 6. GET AI FINANCIAL INSIGHTS ──
  static Future<List<String>> getAiInsights(String currency) async {
    try {
      final headers = await _headers;
      
      // We encode the currency (e.g., '₹ INR' becomes '%E2%82%B9%20INR') so it doesn't break the URL
      final encodedCurrency = Uri.encodeComponent(currency);
      
      final response = await http.get(
        Uri.parse('$baseUrl/analysis/insights?currency=$encodedCurrency'), 
        headers: headers
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> rawInsights = data['insights'];
        return rawInsights.map((e) => e.toString()).toList();
      }
      return ["⚠️ Failed to connect to AI server."];
    } catch (e) {
      return ["⚠️ Network error while fetching insights."];
    }
  }
}
