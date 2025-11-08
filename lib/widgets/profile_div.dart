import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
//import 'package:skillxchange/pages/user_Profile_Page.dart';
//import 'package:skillxchange/widget/applications_vacacies_screen.dart';

class ProfileDiv extends StatefulWidget {
  final String userId; // Accepts current user UID

  const ProfileDiv({super.key, required this.userId});

  @override
  State<ProfileDiv> createState() => _ProfileDivState();
}

class _ProfileDivState extends State<ProfileDiv> {
  String userName = '';
  String skill = '';
  String pfp = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUser();
    _getCurrentUserId(); // Fetch the current user's ID if needed
  }

  // Fetch the current user's ID (if needed)
  void _getCurrentUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {});
    }
  }

  Future<void> fetchUser() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId) // Fetch specific user by ID
          .get();

      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          userName = userData['name'] ?? '';
          skill = userData['educationLvl'] ?? '';
          // Use 'userImg' field for the profile picture
          pfp = userData['userImg'] ?? '';
          isLoading = false;
        });
      } else {
        print('User not found');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching user: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _navigateToProfile() {
   // Navigator.push(
  //    context,
   //   MaterialPageRoute(
   //     builder: (context) => UserProfilePage(userId: widget.userId),
    //  ),
   // );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _navigateToProfile,
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.blue.withAlpha(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ensures the column only takes as much height as needed
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 30),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: pfp.isNotEmpty
                            ? Image.network(
                                pfp,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.error);
                                },
                              )
                            : const Icon(Icons.account_circle, size: 72),
                      ),
                      const SizedBox(width: 36),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          isLoading
                              ? const CircularProgressIndicator()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Name: $userName",
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text("Skill: $skill"),
                                  ],
                                ),
                        ],
                      ),
                    ],
                  ),
SizedBox(
  width: MediaQuery.of(context).size.width * 0.45,
  height: MediaQuery.of(context).size.height * 0.1,
 
),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
