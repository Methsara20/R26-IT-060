import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatbotPanel extends StatefulWidget {
  final Map<String, dynamic>? context;

  final bool isActive;

  const ChatbotPanel({
    super.key,

    required this.context,

    required this.isActive,
  });

  @override
  State<ChatbotPanel> createState() => _ChatbotPanelState();
}

class _ChatbotPanelState extends State<ChatbotPanel> {
  final TextEditingController controller = TextEditingController();

  final List<Map<String, dynamic>> messages = [];

  bool isTyping = false;

 
  //  SEND MESSAGE
 

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) {
      return;
    }

    //  NO PREDICTION CONTEXT
    if (widget.context == null) {
      setState(() {
        messages.add({"role": "user", "message": message});

        messages.add({
          "role": "ai",

          "message":
              "Please generate a prediction first before using the AI assistant.",
        });
      });

      return;
    }

    //  ADD USER MESSAGE
    setState(() {
      messages.add({"role": "user", "message": message});

      isTyping = true;
    });

    controller.clear();

    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/chat"),

        headers: {"Content-Type": "application/json"},

        body: jsonEncode({"message": message, "context": widget.context}),
      );

      final data = jsonDecode(response.body);

      final aiReply = data["reply"] ?? "No response generated.";

      setState(() {
        isTyping = false;

        messages.add({"role": "ai", "message": aiReply});
      });
    } catch (e) {
      setState(() {
        isTyping = false;

        messages.add({
          "role": "ai",

          "message": "AI service connection failed.",
        });
      });
    }
  }

 
  //  QUICK PROMPT CHIP
 

  Widget promptChip(String text) {
    return GestureDetector(
      onTap: () {
        sendMessage(text);
      },

      child: Container(
        margin: const EdgeInsets.only(right: 10, bottom: 10),

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),

          borderRadius: BorderRadius.circular(14),
        ),

        child: Text(
          text,

          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,

            color: Color(0xFF2563EB),
          ),
        ),
      ),
    );
  }

 
  //  CHAT BUBBLE
 

  Widget bubble(String message, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,

      child: Container(
        margin: const EdgeInsets.only(bottom: 14),

        padding: const EdgeInsets.all(16),

        constraints: const BoxConstraints(maxWidth: 650),

        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2563EB) : Colors.white,

          borderRadius: BorderRadius.circular(18),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),

              blurRadius: 14,

              offset: const Offset(0, 6),
            ),
          ],
        ),

        child: Text(
          message,

          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF111827),

            height: 1.7,

            fontSize: 13,
          ),
        ),
      ),
    );
  }

 
  //  MAIN UI
 

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),

        borderRadius: BorderRadius.circular(24),

        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          
          //  HEADER
          
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),

                  borderRadius: BorderRadius.circular(14),
                ),

                child: const Icon(
                  Icons.smart_toy_outlined,

                  color: Color(0xFF2563EB),
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      "AI Retail Assistant",

                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 4),

                    Text(
                      "Business intelligence & forecasting support",

                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),

                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),

                  borderRadius: BorderRadius.circular(12),
                ),

                child: const Row(
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: Color(0xFF16A34A)),

                    SizedBox(width: 8),

                    Text(
                      "Online",

                      style: TextStyle(
                        fontSize: 12,

                        fontWeight: FontWeight.bold,

                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          
          //  QUICK PROMPTS
          
          Wrap(
            children: [
              promptChip("Explain demand trend"),

              promptChip("Day 5 forecast"),

              promptChip("Inventory risk"),

              promptChip("How can we increase sales?"),

              promptChip("Promotion impact"),

              promptChip("Weekly forecast"),
            ],
          ),

          const SizedBox(height: 20),

          
          // CHAT AREA
          
          Container(
            height: 450,

            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(20),

              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),

            child: ListView(
              children: [
                
                //  EMPTY STATE
                
                if (messages.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),

                    child: Column(
                      children: [
                        const Icon(
                          Icons.auto_awesome,

                          size: 52,

                          color: Color(0xFF2563EB),
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          "AI Assistant Ready",

                          style: TextStyle(
                            fontSize: 20,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          widget.isActive
                              ? "Ask questions about demand forecasting, inventory optimization, promotions, stock transfer recommendations, and retail business insights."
                              : "Generate a prediction first to activate AI business intelligence.",

                          textAlign: TextAlign.center,

                          style: TextStyle(
                            height: 1.7,

                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                
                //  CHAT MESSAGES
                
                ...messages.map((msg) {
                  return bubble(msg["message"], msg["role"] == "user");
                }),

                
                //  TYPING INDICATOR
                
                if (isTyping)
                  Align(
                    alignment: Alignment.centerLeft,

                    child: Container(
                      margin: const EdgeInsets.only(top: 10),

                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.white,

                        borderRadius: BorderRadius.circular(16),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),

                            blurRadius: 10,

                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),

                      child: Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,

                            child: CircularProgressIndicator(
                              strokeWidth: 2,

                              color: Colors.blue,
                            ),
                          ),

                          const SizedBox(width: 12),

                          const Text("AI is analyzing retail data..."),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          
          // 🔥 INPUT AREA
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,

                  onSubmitted: sendMessage,

                  decoration: InputDecoration(
                    hintText:
                        "Ask AI about inventory, forecasts, pricing, or retail strategies...",

                    filled: true,

                    fillColor: Colors.white,

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),

                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Container(
                height: 56,
                width: 56,

                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),

                  borderRadius: BorderRadius.circular(16),
                ),

                child: IconButton(
                  onPressed: () {
                    sendMessage(controller.text);
                  },

                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
