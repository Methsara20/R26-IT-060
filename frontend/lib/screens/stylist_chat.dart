import 'package:flutter/material.dart';
import '../services/stylist_api_service.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'dart:ui';

class StylistChatSheet extends StatefulWidget {
  final String customerEmail;

  const StylistChatSheet({Key? key, required this.customerEmail}) : super(key: key);

  @override
  _StylistChatSheetState createState() => _StylistChatSheetState();
}

class _StylistChatSheetState extends State<StylistChatSheet> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  final List<String> _suggestedQuestions = [
    "What styles are trending right now? 🔥",
    "Can you recommend a summer outfit? ☀️",
    "How should I style a denim jacket? 🧥",
    "What size should I get for a slim fit? 📏",
  ];

  @override
  void initState() {
    super.initState();
    _messages.add({
      "sender": "ai",
      "text": "Hi there! ✨ I'm your Personal AI Stylist. I can help you with sizing, fit, or putting together the perfect outfit. What are you looking for today?"
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage([String? prefilledText]) async {
    final text = prefilledText ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final result = await StylistApiService.sendChatMessage(
        customerId: widget.customerEmail,
        message: text,
      );
      
      String responseText = result["response"] as String;
      // Backup cleanup for any rogue markdown symbols from the AI
      responseText = responseText.replaceAll('**', '').replaceAll('### ', '').replaceAll('## ', '');
      
      setState(() {
        _messages.add({"sender": "ai", "text": responseText});
      });
    } catch (e) {
      setState(() {
        _messages.add({"sender": "ai", "text": "Oops, something went wrong. Please try again."});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final isDark = AppState().isDarkMode;

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, spreadRadius: 10),
            ],
            border: Border.all(color: AppTheme.glassBorder(isDark)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: Stack(
              children: [
                // Subtle Background Glow
                Positioned(
                  top: -50,
                  left: -50,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.orbSecondary(isDark).withOpacity(0.15),
                      ),
                    ),
                  ),
                ),
                
                Column(
                  children: [
                    // Premium Header with Gradient
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] : [const Color(0xFFE2E8F0), const Color(0xFFF1F5F9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border(bottom: BorderSide(color: AppTheme.glassBorder(isDark))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlue(isDark).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.auto_awesome, color: AppTheme.accentBlue(isDark), size: 24),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "AI Stylist",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary(isDark),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    "Online • Ready to help",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary(isDark),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.textPrimary(isDark), size: 32),
                            onPressed: () => Navigator.pop(context),
                          )
                        ],
                      ),
                    ),
                    
                    // Chat Messages Area
                    Expanded(
                      child: Container(
                        color: Colors.transparent,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(24),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isUser = msg["sender"] == "user";
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Row(
                                mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isUser) ...[
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.accentBlue(isDark).withOpacity(0.2),
                                      child: Icon(Icons.auto_awesome, color: AppTheme.accentBlue(isDark), size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      decoration: BoxDecoration(
                                        gradient: isUser 
                                          ? LinearGradient(
                                              colors: [AppTheme.accentBlue(isDark), AppTheme.orbSecondary(isDark)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                        color: isUser ? null : AppTheme.glassCard(isDark),
                                        borderRadius: BorderRadius.circular(24).copyWith(
                                          bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(24),
                                          bottomLeft: !isUser ? const Radius.circular(4) : const Radius.circular(24),
                                        ),
                                        border: isUser ? null : Border.all(color: AppTheme.glassBorder(isDark)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isUser ? AppTheme.accentBlue(isDark).withOpacity(0.3) : Colors.black.withOpacity(0.04),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          )
                                        ],
                                      ),
                                      child: Text(
                                        msg["text"]!,
                                        style: TextStyle(
                                          color: isUser ? Colors.white : AppTheme.textPrimary(isDark),
                                          fontSize: 15,
                                          height: 1.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isUser) const SizedBox(width: 28), // padding for user messages
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    
                    // Thinking Indicator
                    if (_isLoading)
                      Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 64, bottom: 20),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textSecondary(isDark)),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Stylist is thinking...",
                              style: TextStyle(color: AppTheme.textSecondary(isDark), fontSize: 13, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                      
                    // Premium Input Area & Suggestions
                    ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: EdgeInsets.only(
                            top: 12,
                            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor(isDark).withOpacity(0.8),
                            border: Border(top: BorderSide(color: AppTheme.glassBorder(isDark))),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Suggested Questions Carousel
                              SizedBox(
                                height: 40,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  itemCount: _suggestedQuestions.length,
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onTap: () {
                                        if (!_isLoading) {
                                          _sendMessage(_suggestedQuestions[index]);
                                        }
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentBlue(isDark).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: AppTheme.accentBlue(isDark).withOpacity(0.3)),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _suggestedQuestions[index],
                                            style: TextStyle(
                                              color: AppTheme.accentBlue(isDark),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Text Input Row
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppTheme.glassInput(isDark),
                                          borderRadius: BorderRadius.circular(30),
                                          border: Border.all(color: AppTheme.glassBorder(isDark)),
                                        ),
                                        child: TextField(
                                          controller: _controller,
                                          style: TextStyle(fontSize: 15, color: AppTheme.textPrimary(isDark)),
                                          decoration: InputDecoration(
                                            hintText: "Ask for styling advice...",
                                            hintStyle: TextStyle(color: AppTheme.textSecondary(isDark)),
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                          ),
                                          onSubmitted: (_) => _sendMessage(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: _isLoading ? null : () => _sendMessage(),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [AppTheme.accentBlue(isDark), AppTheme.orbSecondary(isDark)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.accentBlue(isDark).withOpacity(0.4),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            )
                                          ],
                                        ),
                                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}
