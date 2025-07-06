import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({Key? key, required this.postId}) : super(key: key);

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController _newCommentController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  String? _replyingToCommentId;

  final currentUser = FirebaseAuth.instance.currentUser;

  // Método para agregar un nuevo comentario
  Future<void> _addComment() async {
    final content = _newCommentController.text.trim();
    if (content.isEmpty) return;

    final commentsRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments');

    try {
      await commentsRef.add({
        'authorId': currentUser?.uid,
        'authorEmail': currentUser?.email,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'replies': [], // Lista vacía para respuestas
      });
      _newCommentController.clear();
    } catch (e) {
      print("Error al agregar comentario: $e");
    }
  }

  // Método para agregar una respuesta a un comentario
  Future<void> _addReply(String commentId) async {
    final replyController = _replyControllers[commentId];
    final replyText = replyController?.text.trim() ?? '';
    if (replyText.isEmpty) return;

    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies'); // Subcolección de respuestas

    try {
      // Agregar una nueva respuesta como un documento en la subcolección 'replies'
      await commentRef.add({
        'authorId': currentUser?.uid,
        'authorEmail': currentUser?.email,
        'content': replyText,
        'createdAt': FieldValue.serverTimestamp(),
      });

      replyController?.clear();
      setState(() {
        _replyingToCommentId = null;
      });
    } catch (e) {
      print("Error al agregar respuesta: $e");
    }
  }

  // Método para mostrar las respuestas de un comentario
  // Método para mostrar las respuestas de un comentario
  Widget _buildReplies(String commentId) {
    final repliesRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies');

    return StreamBuilder<QuerySnapshot>(
      stream: repliesRef.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox(); // Si no hay respuestas, no mostrar nada
        }

        return Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8),
          child: Column(
            children: snapshot.data!.docs.map<Widget>((replyDoc) {
              final replyData = replyDoc.data() as Map<String, dynamic>;
              final createdAtTimestamp = replyData['createdAt'] as Timestamp?;
              final createdAt = createdAtTimestamp != null
                  ? createdAtTimestamp.toDate()
                  : DateTime.now();

              return ListTile(
                title: Text(replyData['authorEmail'] ?? 'Anon'),
                subtitle: Text(replyData['content'] ?? ''),
                trailing: Text(
                  '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Método para construir el item del comentario
  Widget _buildCommentItem(DocumentSnapshot commentDoc) {
    final data = commentDoc.data() as Map<String, dynamic>;
    final commentId = commentDoc.id;

    final createdAtTimestamp = data['createdAt'] as Timestamp?;
    final createdAt = createdAtTimestamp != null
        ? createdAtTimestamp.toDate()
        : DateTime.now();

    _replyControllers.putIfAbsent(commentId, () => TextEditingController());

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['authorEmail'] ?? 'Anon',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(data['content'] ?? ''),
            const SizedBox(height: 6),
            Text(
              '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_replyingToCommentId == commentId) {
                    _replyingToCommentId = null;
                  } else {
                    _replyingToCommentId = commentId;
                  }
                });
              },
              child: Text(
                _replyingToCommentId == commentId ? 'Cancelar' : 'Responder',
              ),
            ),
            if (_replyingToCommentId == commentId)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _replyControllers[commentId],
                      decoration: const InputDecoration(
                        labelText: 'Escribe tu respuesta',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ElevatedButton(
                      onPressed: () => _addReply(commentId),
                      child: const Text('Enviar respuesta'),
                    ),
                  ],
                ),
              ),
            // Llamar a _buildReplies con el commentId
            _buildReplies(commentId),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newCommentController.dispose();
    _replyControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Post')),
      body: FutureBuilder<DocumentSnapshot>(
        future: postRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Post no encontrado'));
          }

          final postData = snapshot.data!.data() as Map<String, dynamic>;

          List<dynamic> images = postData['images'] ?? [];

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      postData['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(postData['description'] ?? ''),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          return Image.network(
                            images[index],
                            width: 200,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Reseñas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    StreamBuilder<QuerySnapshot>(
                      stream: postRef
                          .collection('comments')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text('No hay comentarios aún.');
                        }

                        return Column(
                          children: snapshot.data!.docs
                              .map((doc) => _buildCommentItem(doc))
                              .toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _newCommentController,
                      decoration: const InputDecoration(
                        labelText: 'Añadir nueva reseña',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ElevatedButton(
                      onPressed: _addComment,
                      child: const Text('Publicar reseña'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
