class ChatMessage {
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isError: json['isError'] == true,
    );
  }

  ChatMessage.user(String content)
      : this(role: 'user', content: content);

  ChatMessage.assistant(String content)
      : this(role: 'assistant', content: content);

  ChatMessage.error(String content)
      : this(role: 'assistant', content: content, isError: true);
}
