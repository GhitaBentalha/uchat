import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final String userId; // ID de l'utilisateur avec qui vous discutez
  final String userName; // Nom de l'utilisateur avec qui vous discutez

  const ChatPage({super.key, required this.userId, required this.userName});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // Envoyer un message
  void _sendMessage() async {
    if (_controller.text.isNotEmpty) {
      await _firestore.collection('messages').add({
        'text': _controller.text,
        'createdAt': FieldValue.serverTimestamp(),
        'senderId': currentUserId,
        'receiverId': widget.userId,
        'isRead': false, // Par défaut, le message est marqué comme non lu
        'delivered': false, // Par défaut, le message est marqué comme non livré
      });

      _controller.clear();
    }
  }

  // Marquer les messages comme lus
  void _markMessagesAsRead() async {
    final messages = await _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('senderId', isEqualTo: widget.userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in messages.docs) {
      doc.reference.update({'isRead': true, 'delivered': true});
    }
  }

  // Supprimer un message
  void _deleteMessage(String messageId) async {
    await _firestore.collection('messages').doc(messageId).delete();
  }

  // Afficher une boîte de dialogue de confirmation pour la suppression
  void _showDeleteConfirmation(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce message ?'),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
          TextButton(
            child: const Text('Supprimer'),
            onPressed: () {
              _deleteMessage(messageId);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .where('senderId', whereIn: [currentUserId, widget.userId])
                  .where('receiverId', whereIn: [currentUserId, widget.userId])
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error.toString()}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                final messages = snapshot.data!.docs;

                // Marquer les messages comme lus lorsque l'utilisateur est dans le chat
                _markMessagesAsRead();

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isSender = message['senderId'] == currentUserId;

                    return GestureDetector(
                      onLongPress: () {
                        // Afficher la boîte de dialogue de confirmation pour supprimer le message
                        _showDeleteConfirmation(message.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: isSender
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!isSender)
                              CircleAvatar(
                                backgroundColor: Colors.grey[300],
                                child: Text(
                                  widget.userName[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                            if (!isSender) const SizedBox(width: 8),
                            Flexible(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 250),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isSender
                                        ? Color.fromARGB(144, 248, 74, 248)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(15),
                                      topRight: const Radius.circular(15),
                                      bottomLeft: isSender
                                          ? const Radius.circular(15)
                                          : const Radius.circular(0),
                                      bottomRight: isSender
                                          ? const Radius.circular(0)
                                          : const Radius.circular(15),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message['text'],
                                        style: TextStyle(
                                          color: isSender
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      if (isSender) // Afficher les coches uniquement pour les messages envoyés
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            // Vérifier si le message a été envoyé mais pas reçu
                                            if (!message[
                                                'delivered']) // Message envoyé mais non reçu
                                              Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors
                                                    .grey, // Une coche grise pour non reçu
                                              ),
                                            // Vérifier si le message a été reçu mais non lu
                                            if (message['delivered'] &&
                                                !message[
                                                    'isRead']) // Message reçu mais non lu
                                              ...[
                                              Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors
                                                    .grey, // Première coche grise
                                              ),
                                              const SizedBox(
                                                  width: 2), // Espacement
                                              Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors
                                                    .grey, // Deuxième coche grise
                                              ),
                                            ],
                                            // Vérifier si le message a été lu
                                            if (message[
                                                'isRead']) // Message reçu et lu
                                              ...[
                                              Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors
                                                    .blue, // Première coche bleue
                                              ),
                                              const SizedBox(
                                                  width: 2), // Espacement
                                              Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors
                                                    .blue, // Deuxième coche bleue
                                              ),
                                            ],
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor:
                          isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                    ),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
