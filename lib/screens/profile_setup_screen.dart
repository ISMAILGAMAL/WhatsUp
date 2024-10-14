import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsup/screens/home_screen.dart';
import 'package:whatsup/helpers.dart';

const List<String> allowedFileExtensions = [
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
];

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController displayNameController = TextEditingController();
  File? _profileImage;
  bool isDisplayNameValid = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    displayNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _uploadProfileData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final isUnique =
          await isUsernameUnique(displayNameController.text.trim());

      if (!isUnique && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Username already taken.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 6),
          ),
        );
        return;
      }

      String? imageUrl;

      if (_profileImage != null) {
        String fileExtension = _profileImage!.path.split('.').last;

        if (!allowedFileExtensions.contains(fileExtension) && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Unsupported file type. Please upload a JPG or PNG image.'),
            ),
          );
          setState(() {
            _profileImage = null;
          });
          return;
        }

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child(user.uid)
            .child('${user.uid}.$fileExtension');

        await storageRef.putFile(_profileImage!);
        imageUrl = await storageRef.getDownloadURL();
      }

      // Update display name and photo URL
      await user.updateDisplayName(displayNameController.text.trim());
      if (imageUrl != null) {
        await user.updatePhotoURL(imageUrl);
      }

      final db = FirebaseFirestore.instance;

      db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': displayNameController.text.trim(),
        'nameLower': displayNameController.text.trim().toLowerCase(),
        'email': user.email,
        'profileUrl': imageUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile setup complete!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      // Display error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete profile setup: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Set up your Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage:
                      _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? const Icon(Icons.add_a_photo, size: 30)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                  controller: displayNameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Display Name',
                  ),
                  onChanged: (value) {
                    setState(() {
                      isDisplayNameValid =
                          value.trim().isNotEmpty && value.trim().length >= 4;
                    });
                  }),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isDisplayNameValid ? _uploadProfileData : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Complete Profile Setup',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
