import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MyProfile extends StatefulWidget {
  const MyProfile({super.key});

  @override
  _MyProfileState createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile> {
  // Controllers for text fields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController userIdController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController branchController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  // Function to fetch user data from the API
  Future<void> fetchUserData() async {
    try {
      final token = await storage.read(key: 'userToken');
      final response = await http.get(
        Uri.parse('https://met.microtek.in/app-users/profile/details/$token'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          nameController.text = data['username'] ?? '';
          emailController.text = data['email'] ?? '';
          userIdController.text = data['user_id'] ?? '';
          mobileController.text = data['contact_no'] ?? '';
          branchController.text = data['branch'] ?? '';
          cityController.text = data['city'] ?? '';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch user data")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // Function to handle update
  void updateProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        final token = await storage.read(key: 'userToken');
        Map<String, dynamic> data = {
          'token': token,
          'username': nameController.text.trim(),
          'email': emailController.text.trim(),
          'user_id': userIdController.text.trim(),
          'contact_no': mobileController.text.trim(),
          'branch': branchController.text.trim(),
          'city': cityController.text.trim(),
        };

        final response = await http.post(
          Uri.parse('https://met.microtek.in/app/update-email-username'),
          body: data,
        );

        print(response.body);
        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          if (responseData['errFlag'] == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['message'])),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['message'])),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update profile")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "My Profile",
          style: TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name Field
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Name",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Name cannot be empty';
                          } else if (!RegExp(r'^[a-zA-Z\s]+$')
                              .hasMatch(value)) {
                            return 'Name should contain only letters and spaces';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // User ID Field
                      TextFormField(
                        controller: userIdController,
                        decoration: const InputDecoration(
                          labelText: "User ID",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'User ID cannot be empty';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      // TextFormField(
                      //   controller: emailController,
                      //   decoration: const InputDecoration(
                      //     labelText: "Email",
                      //     border: OutlineInputBorder(),
                      //   ),
                      //   keyboardType: TextInputType.emailAddress,
                      //   validator: (value) {
                      //     if (value == null || value.isEmpty) {
                      //       return 'Email cannot be empty';
                      //     } else if (!RegExp(
                      //             r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                      //         .hasMatch(value)) {
                      //       return 'Please enter a valid email address';
                      //     }
                      //     return null;
                      //   },
                      // ),
                      // const SizedBox(height: 16),

                      // Mobile Number Field
                      TextFormField(
                        controller: mobileController,
                        decoration: const InputDecoration(
                          labelText: "Mobile Number",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Mobile number cannot be empty';
                          } else if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                            return 'Please enter a valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Branch Field
                      TextFormField(
                        controller: branchController,
                        decoration: const InputDecoration(
                          labelText: "Branch",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Branch cannot be empty';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // City Field
                      TextFormField(
                        controller: cityController,
                        decoration: const InputDecoration(
                          labelText: "City",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'City cannot be empty';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Logo and Version
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo_grey.png',
                    width: 120,
                  ),
                  const Text(
                    'Version 1.0.14b269',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF848B9F),
                    ),
                  ),
                ],
              ),
            ),

            // Update Button
            // Padding(
            //   padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            //   child: TextButton(
            //     onPressed: updateProfile,
            //     style: TextButton.styleFrom(
            //       backgroundColor: const Color(0xFF1D4694),
            //       padding: const EdgeInsets.symmetric(vertical: 16.0),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(10.0),
            //       ),
            //       minimumSize: const Size(double.infinity, 50),
            //     ),
            //     child: const Text(
            //       "Update Profile",
            //       style: TextStyle(
            //         color: Colors.white,
            //         fontSize: 20,
            //         fontWeight: FontWeight.w500,
            //       ),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
