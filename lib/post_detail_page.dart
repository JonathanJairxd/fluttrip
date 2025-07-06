import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

class PostDetailPage extends StatelessWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    return Scaffold(
      appBar: AppBar(title: const Text("Detalles del sitio")),
      body: FutureBuilder<DocumentSnapshot>(
        future: postRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Publicación no encontrada."));
          }

          final post = snapshot.data!;
          final title = post['title'] ?? 'Sin título';
          final description = post['description'] ?? '';
          final imageUrls = List<String>.from(post['images'] ?? []);
          final comments = List<String>.from(post['comments'] ?? []);

          final user = FirebaseAuth.instance.currentUser;
          final TextEditingController commentController =
              TextEditingController();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(description, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        if (imageUrls.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Fotos:",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final url in imageUrls)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Image.network(
                                    url,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 20),
                        const Text(
                          "Reseñas:",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (comments.isEmpty) const Text("Aún no hay reseñas."),
                        for (final comment in comments)
                          ListTile(
                            leading: const Icon(Icons.comment),
                            title: Text(comment),
                          ),
                      ],
                    ),
                  ),
                ),
                if (user != null) ...[
                  const Divider(),
                  TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      labelText: "Escribe una reseña",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final commentText = commentController.text.trim();
                      if (commentText.isEmpty) return;

                      await postRef.update({
                        'comments': FieldValue.arrayUnion([
                          "${user.email}: $commentText",
                        ]),
                      });

                      commentController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Reseña publicada")),
                      );
                    },
                    child: const Text("Publicar"),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      "Inicia sesión para escribir una reseña.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
