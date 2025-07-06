import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  List<File> _images = []; // Móvil
  List<Uint8List> _webImages = []; // Web
  bool isUploading = false;

  Future<void> _pickImage() async {
    const maxImages = 5;
    final currentCount = kIsWeb ? _webImages.length : _images.length;

    if (currentCount >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Máximo 5 imágenes permitidas")),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // importante para Web
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        if (kIsWeb) {
          if (pickedFile.bytes != null) {
            setState(() {
              _webImages.add(pickedFile.bytes!);
            });
          }
        } else {
          if (pickedFile.path != null) {
            setState(() {
              _images.add(File(pickedFile.path!));
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al seleccionar imagen: $e")),
      );
    }
  }

  Future<void> _submitPost() async {
    final hasImages = kIsWeb ? _webImages.isNotEmpty : _images.isNotEmpty;

    if (titleController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        !hasImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Completa todos los campos y añade al menos una imagen"),
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
        throw Exception('Usuario no autenticado');
      }

      final postRef = FirebaseFirestore.instance.collection('posts').doc();
      List<String> imageUrls = [];
      final supabase = Supabase.instance.client;

      if (kIsWeb) {
        for (int i = 0; i < _webImages.length; i++) {
          final bytes = _webImages[i];
          final fileName = "${DateTime.now().millisecondsSinceEpoch}_$i.jpg";
          final filePath = "posts/${postRef.id}/$fileName";

          await supabase.storage.from('posts').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

          final url = supabase.storage.from('posts').getPublicUrl(filePath);
          imageUrls.add(url);
        }
      } else {
        for (int i = 0; i < _images.length; i++) {
          final file = _images[i];
          final bytes = await file.readAsBytes();
          final fileName = "${DateTime.now().millisecondsSinceEpoch}_$i.jpg";
          final filePath = "posts/${postRef.id}/$fileName";

          await supabase.storage.from('posts').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

          final url = supabase.storage.from('posts').getPublicUrl(filePath);
          imageUrls.add(url);
        }
      }

      // Guardar el post en Firestore
      await postRef.set({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'images': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'authorId': user.uid,
        'authorEmail': user.email,
        'comments': [],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Publicación creada exitosamente")),
      );
      Navigator.pop(context);
    } catch (e) {
      print("Error al publicar: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al publicar: $e")),
      );
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImages = kIsWeb ? _webImages : _images;

    return Scaffold(
      appBar: AppBar(title: const Text("Nueva Publicación")),
      body: isUploading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "Título"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: "Descripción"),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (kIsWeb)
                        for (var image in _webImages)
                          Image.memory(
                            image,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          )
                      else
                        for (var image in _images)
                          Image.file(
                            image,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                      if (currentImages.length < 5)
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
