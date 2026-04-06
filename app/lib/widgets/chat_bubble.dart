import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isError;
  final double fontSize;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isError = false,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color textColor;
    Alignment alignment;
    BorderRadius borderRadius;

    if (isUser) {
      alignment = Alignment.centerRight;
      bgColor = Theme.of(context).colorScheme.primary;
      textColor = Theme.of(context).colorScheme.onPrimary;
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(4),
      );
    } else if (isError) {
      alignment = Alignment.centerLeft;
      bgColor = isDark
          ? Colors.red.withOpacity(0.15)
          : Colors.red.withOpacity(0.1);
      textColor = isDark ? Colors.red.shade200 : Colors.red.shade800;
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(16),
      );
    } else {
      alignment = Alignment.centerLeft;
      bgColor = isDark
          ? const Color(0xFF2A2A2A)
          : const Color(0xFFF0F0F0);
      textColor = isDark ? Colors.grey.shade200 : Colors.black87;
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(16),
      );
    }

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: borderRadius,
        ),
        child: SelectableText(
          text,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.5,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
