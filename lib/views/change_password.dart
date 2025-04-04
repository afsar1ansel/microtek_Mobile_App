import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final _formKey = GlobalKey<FormState>();

  // Visibility toggles for password fields
  bool isCurrentPasswordVisible = false;
  bool isNewPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  // Regex for password validation
  final RegExp passwordRegex = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\W).{8,}$');

  void snackbarFunction(String message) {
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Color(0xFF203344),
        showCloseIcon: true,
        behavior: SnackBarBehavior.floating, // Make it float on top
      ),
    );
  }

  // Function to handle password reset
  Future<void> resetPassword() async {
    if (_formKey.currentState!.validate()) {
      String currentPassword = currentPasswordController.text.trim();
      String newPassword = newPasswordController.text.trim();

      // Retrieve token from secure storage
      final storage = FlutterSecureStorage();
      String? token = await storage.read(key: 'userToken');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User token not found!")),
        );
        return;
      }

      // Prepare data to send to the backend
      Map<String, String> data = {
        'oldPassword': currentPassword,
        'newPassword': newPassword,
        'token': token,
      };

      // Send POST request to the API
      final response = await http.post(
        Uri.parse('https://bt.meshaenergy.com/apis/app-users/change-password'),
        body: data,
      );
      print(
          '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
      print(response.body);
      print(
          '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['errFlag'] == 0) {
          snackbarFunction(responseData['message']);
          Navigator.pop(context);
        } else {
          snackbarFunction(responseData['message']);
        }
      } else {
        snackbarFunction("An error occurred. Please try again later.");
      }

      // Print updated values for debugging
      print("Current Password: $currentPassword");
      print("New Password: $newPassword");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // Center the title horizontally
        title: Text(
          "Change Password",
          style: TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instruction Text
                Text(
                  "Your new password must be different from previous used passwords.",
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),

                // Current Password Field
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: !isCurrentPasswordVisible,
                  decoration: InputDecoration(
                    labelText: "Current Password",
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isCurrentPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          isCurrentPasswordVisible = !isCurrentPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Current password cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // New Password Field
                TextFormField(
                  controller: newPasswordController,
                  obscureText: !isNewPasswordVisible,
                  decoration: InputDecoration(
                    labelText: "New Password",
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isNewPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          isNewPasswordVisible = !isNewPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'New password cannot be empty';
                    } else if (!passwordRegex.hasMatch(value)) {
                      return 'Password must contain at least 8 characters,\n1 uppercase, 1 lowercase, and 1 symbol.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: !isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          isConfirmPasswordVisible = !isConfirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm password cannot be empty';
                    } else if (value != newPasswordController.text.trim()) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: resetPassword,
         style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1D4694), // Same background color
            padding: const EdgeInsets.symmetric(
                vertical: 16.0), // Same vertical padding
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0), // Same border radius
            ),
          ),
         child: const Text(
            "Reset Password",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
