import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'signup.dart';
import 'package:rayanpharma/pages/first_page.dart'; // Ensure this path is correct
// If you have a signup page, import it too:
// import 'signup_page.dart'; // Or your signup page route name

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // To show loading indicator

  Future<void> _login() async {
    // Validate the form first
    if (!_formKey.currentState!.validate()) {
      return; // If form is not valid, do nothing
    }

    // Show loading indicator and disable button
    setState(() {
      _isLoading = true;
    });

    try {
      // Sign in with Firebase Auth using user input
      UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: _emailController.text.trim(), // Get email from controller
              password: _passwordController.text.trim() // Get password from controller
              );

      // If login is successful, navigate to MainMenu
      if (credential.user != null && mounted) {
        // String uid = credential.user!.uid; // You can get the uid if needed by MainMenu
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                MainMenu(), // Pass uid if MainMenu requires it: MainMenu(uid: uid)
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase errors
      String errorMessage = "Login failed. Please check your credentials.";
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is not valid.';
      } else {
         errorMessage = e.message ?? errorMessage; // Use Firebase message if available
      }
       _showError(errorMessage);
    } catch (e) {
      // Handle other generic errors
      _showError("An unexpected error occurred. Please try again.");
    } finally {
      // Hide loading indicator regardless of success or failure
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) { // Ensure the widget is still mounted before showing snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent, // Make error stand out
        ),
      );
    }
  }

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login"),
        backgroundColor: Colors.tealAccent, // Change to your theme color
        automaticallyImplyLeading: false, // Remove back button if it's the root
      ),
      body: Center(
        child: SingleChildScrollView( // Allows scrolling on smaller screens
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400), // Limit width on larger screens
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey, // Assign the key to the form
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons stretch
                  children: [
                    const Text(
                      "Welcome to LIU Pharma!",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Sign in to continue",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null; // Return null if valid
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: "Password",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true, // Hide password characters
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        // Optional: Add minimum length validation if needed for login
                        // if (value.length < 6) {
                        //   return 'Password must be at least 6 characters';
                        // }
                        return null; // Return null if valid
                      },
                    ),
                    const SizedBox(height: 24),

                    // Login Button (conditionally shows loading indicator)
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _login, // Call the login function
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent, // Change to your theme color
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                            child: const Text("Login"),
                          ),
                    const SizedBox(height: 16),

                    // Optional: Link to Signup Page
                    TextButton(
                      onPressed: _isLoading ? null : () { // Disable while loading
                        // Navigate to your Signup page
                      MaterialPageRoute:
                       Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => SignUp()),
                         );
                      },
                      child: const Text("Don't have an account? Sign Up"),
                    ),

                     // Optional: Forgot Password Link
                     TextButton(
                       onPressed: _isLoading ? null : () {
                         // TODO: Implement password reset logic/navigation
                         ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Forgot Password clicked (implement functionality)")),
                         );
                       },
                       child: const Text("Forgot Password?"),
                     ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}