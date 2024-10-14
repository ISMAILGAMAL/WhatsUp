import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsup/helpers.dart';
import 'package:whatsup/screens/login.dart'; 

const List<String> allowedFileExtensions = [
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() {
    return _EditProfileScreenState();
  }
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  String? _profileUrl;
  User? user;
  String? currentEmail;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isNameEditable = false;
  bool _isEmailEditable = false;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    currentEmail = user!.email;
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (user != null) {
      _nameController.text = user!.displayName!;
      _emailController.text = user!.email!;
      setState(() {
        _profileUrl = user!.photoURL;
      });
    }
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
      if (user == null) return;

      final userName = _nameController.text.trim();
      final newEmail = _emailController.text.trim();

      final isUnique = await isUsernameUnique(userName);

      if (!isUnique && mounted && userName != user!.displayName) {
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

      // Upload profile picture to Firebase Storage
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
            .child(user!.uid)
            .child('${user!.uid}.$fileExtension');

        await storageRef.putFile(_profileImage!);
        imageUrl = await storageRef.getDownloadURL();
      }

      if (newEmail != currentEmail) {
        bool shouldUpdate =
            await _showEmailChangeDialog(); 

        if (shouldUpdate) {
          await _updateEmailAndLogout(newEmail);
          return; // Stop further profile update as user will be logged out
        } else {
          return; // If user cancels, don't proceed with profile update
        }
      }

      // Update display name and photo URL
      await user!.updateDisplayName(userName);
      if (imageUrl != null) {
        await user!.updatePhotoURL(imageUrl);
      }

      final db = FirebaseFirestore.instance;

      db.collection('users').doc(user!.uid).set({
        'uid': user!.uid,
        'name': userName,
        'nameLower': userName.toLowerCase(),
        'email': user!.email,
        'profileUrl': user!.photoURL,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile Updated!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _showEmailChangeDialog() async {
    return await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Email Change'),
          content: const Text(
              'Changing your email will log you out and you will need to verify the new email before logging back in. Do you want to proceed?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context, false);
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.pop(context, true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateEmailAndLogout(String newEmail) async {
    try {
      await user!.verifyBeforeUpdateEmail(newEmail);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email updated! Please verify your new email address.'),
          backgroundColor: Colors.blue,
        ),
      );

      await FirebaseAuth.instance.signOut();
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update email: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 80,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : (_profileUrl != null
                            ? NetworkImage(_profileUrl!)
                            : null),
                    child: _profileImage == null && _profileUrl == null
                        ? const Icon(Icons.add_a_photo, size: 30)
                        : null,
                  ),
                  const Positioned(
                    bottom: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: const Icon(
                        Icons.add_a_photo,
                        color: Colors.teal,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildTextField(_nameController, 'Name', _isNameEditable, (value) {
              setState(() {
                _isNameEditable = !value;
              });
            }),
            const SizedBox(height: 15),
            _buildTextField(_emailController, 'Email', _isEmailEditable,
                (value) {
              setState(() {
                _isEmailEditable = !value;
              });
            }),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadProfileData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      bool isEditable, Function(bool) toggle) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: isEditable,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.grey.shade200,
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            isEditable ? Icons.check : Icons.edit,
            color: Colors.teal,
          ),
          onPressed: () => toggle(isEditable),
        ),
      ],
    );
  }
}
