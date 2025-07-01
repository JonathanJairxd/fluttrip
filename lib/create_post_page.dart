import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final List<File> _images = [];
  final picker = ImagePicker();
  bool isUploading = false;

  Future<void> _pickImage() async {
    if (_images.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Máximo 5 imágenes")));
      return;
    }

    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _submitPost() async {
    if (titleController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Completa todos los campos y añade al menos una imagen",
          ),
        ),
      );
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Usuario no autenticado")));
        setState(() {
          isUploading = false;
        });
        return;
      }

      final postRef = FirebaseFirestore.instance.collection('posts').doc();

      List<String> imageUrls = [];

      final supabase = Supabase.instance.client;

      for (File image in _images) {
        final fileName = path.basename(image.path);
        final key = 'posts/${postRef.id}/$fileName';

        // Sube la imagen a Supabase Storage
        try {
          final String filePath = await supabase.storage
              .from('posts')
              .upload(key, image);
          final url = supabase.storage.from('posts').getPublicUrl(filePath);
          imageUrls.add(url);
        } catch (e) {
          throw Exception('Error al subir imagen: $e');
        }

        // Obtén la URL pública
        final urlResponse = supabase.storage
            .from('your-bucket-name')
            .getPublicUrl(key);
        imageUrls.add(urlResponse);
      }

      // Guarda el post en Firestore
      await postRef.set({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'images': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'authorId': user.uid,
        'authorEmail': user.email,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Publicación creada")));

      Navigator.pop(context); // Regresa al home
    } catch (e) {
      print("Error al subir publicación: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al subir publicación: $e")));
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nueva Publicación")),
      body: isUploading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "Título"),
                  ),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: "Descripción"),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var image in _images)
                        Image.file(
                          image,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      if (_images.length < 5)
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[300],
                            child: const Icon(Icons.add_a_photo),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submitPost,
                    child: const Text("Publicar"),
                  ),
                ],
              ),
            ),
    );
  }
}
