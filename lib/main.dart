import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const TawasolApp());
}

class TawasolApp extends StatelessWidget {
  const TawasolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تواصل',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A192F),
        primaryColor: const Color(0xFF0077B6),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00B4D8),
          surface: Color(0xFF102A43),
          onSurface: Colors.white,
        ),
      ),
      home: const ConnectionSetupScreen(),
    );
  }
}

// الشاشة الرئيسية لإعداد الاتصال المحلي (مضيف أو متصل)
class ConnectionSetupScreen extends StatefulWidget {
  const ConnectionSetupScreen({super.key});

  @override
  State<ConnectionSetupScreen> createState() => _ConnectionSetupScreenState();
}

class _ConnectionSetupScreenState extends State<ConnectionSetupScreen> {
  final TextEditingController _ipController = TextEditingController();
  String _localIp = 'جاري جلب العنوان...';
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _fetchLocalIp();
  }

  // جلب عنوان IP الشبكة المحلية للجهاز تلقائياً بدون حزم خارجية
  Future<void> _fetchLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            setState(() => _localIp = addr.address);
            return;
          }
        }
      }
      setState(() => _localIp = 'غير متصل بشبكة محلية');
    } catch (_) {
      setState(() => _localIp = 'تعذر جلب العنوان');
    }
  }

  // خيار 1: إنشاء غرفة (سيرفر محلي)
  Future<void> _startHostRoom() async {
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, 4040);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocalChatScreen(
            isHost: true,
            serverSocket: server,
            hostIp: _localIp,
          ),
        ),
      );
    } catch (e) {
      _showError('تعذر فتح الغرفة: تأكد من تفعيل الواي فاي أو نقطة الاتصال.');
    }
  }

  // خيار 2: الانضمام لغرفة (عميل يتصل بالسيرفر)
  Future<void> _joinRoom() async {
    final targetIp = _ipController.text.trim();
    if (targetIp.isEmpty) {
      _showError('يرجى إدخال عنوان IP الخاص بالجهاز المضيف.');
      return;
    }

    setState(() => _isConnecting = true);
    try {
      final socket = await Socket.connect(
        targetIp,
        4040,
        timeout: const Duration(seconds: 5),
      );
      setState(() => _isConnecting = false);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocalChatScreen(
            isHost: false,
            clientSocket: socket,
            hostIp: targetIp,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isConnecting = false);
      _showError('فشل الاتصال بالجهاز ($targetIp). تأكد من الاتصال بنفس الشبكة.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تواصل - الشبكة المحلية',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF102A43),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة عرض عنوان IP الخاص بجهازك
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF102A43),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0077B6)),
              ),
              child: Column(
                children: [
                  const Text(
                    'عنوان IP المحلي لجهازك:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _localIp,
                        style: const TextStyle(
                          color: Color(0xFF00B4D8),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white70),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _localIp));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ العنوان')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white70),
                        onPressed: _fetchLocalIp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // القسم الأول: إنشاء محادثة (المضيف)
            const Text(
              '1. بدء محادثة جديدة (المضيف)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'افتح غرفة وانتظر اتصال الطرف الآخر بك عبر عنوان IP الظاهر أعلاه.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0077B6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.wifi_tethering_rounded),
              label: const Text('إنشاء غرفة محادثة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: _startHostRoom,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Divider(color: Colors.white24),
            ),

            // القسم الثاني: الانضمام لمحادثة (المتصل)
            const Text(
              '2. الانضمام إلى محادثة قائمة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'أدخل عنوان IP الخاص بالجهاز المضيف للاتصال به مباشرة:',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'مثال: 192.168.43.1',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF102A43),
                prefixIcon: const Icon(Icons.lan_rounded, color: Color(0xFF00B4D8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B4D8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(
                _isConnecting ? 'جاري الاتصال...' : 'اتصال بالمحادثة',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _isConnecting ? null : _joinRoom,
            ),
          ],
        ),
      ),
    );
  }
}

// نموذج الرسالة
class Message {
  final String text;
  final bool isMe;
  final String time;

  Message({
    required this.text,
    required this.isMe,
    required this.time,
  });
}

// شاشة المحادثة المباشرة عبر الواي فاي المحلي
class LocalChatScreen extends StatefulWidget {
  final bool isHost;
  final ServerSocket? serverSocket;
  final Socket? clientSocket;
  final String hostIp;

  const LocalChatScreen({
    super.key,
    required this.isHost,
    this.serverSocket,
    this.clientSocket,
    required this.hostIp,
  });

  @override
  State<LocalChatScreen> createState() => _LocalChatScreenState();
}

class _LocalChatScreenState extends State<LocalChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  Socket? _activeSocket;
  String _connectionStatus = '';

  @override
  void initState() {
    super.initState();
    if (widget.isHost) {
      _connectionStatus = 'بانتظار انضمام الطرف الآخر على IP: ${widget.hostIp}';
      widget.serverSocket?.listen((Socket client) {
        setState(() {
          _activeSocket = client;
          _connectionStatus = 'متصل الآن (${client.remoteAddress.address})';
        });
        _listenToSocket(client);
      });
    } else {
      _activeSocket = widget.clientSocket;
      _connectionStatus = 'متصل بالمضيف (${widget.hostIp})';
      if (_activeSocket != null) {
        _listenToSocket(_activeSocket!);
      }
    }
  }

  void _listenToSocket(Socket socket) {
    socket.listen(
      (Uint8List data) {
        final receivedText = utf8.decode(data).trim();
        if (receivedText.isNotEmpty && mounted) {
          setState(() {
            _messages.add(
              Message(
                text: receivedText,
                isMe: false,
                time: _getCurrentTime(),
              ),
            );
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _connectionStatus = 'انقطع الاتصال بالطرف الآخر');
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _connectionStatus = 'حدث خطأ في الاتصال');
        }
      },
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'م' : 'ص';
    return '$hour:$minute $period';
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_activeSocket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد جهاز متصل حالياً لاستلام الرسالة!')),
      );
      return;
    }

    try {
      _activeSocket!.write('$text\n');
      setState(() {
        _messages.add(
          Message(
            text: text,
            isMe: true,
            time: _getCurrentTime(),
          ),
        );
      });
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الرسالة، تحقق من الاتصال.')),
      );
    }
  }

  @override
  void dispose() {
    _activeSocket?.close();
    widget.serverSocket?.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'محادثة محلية',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
            Text(
              _connectionStatus,
              style: const TextStyle(color: Color(0xFF00B4D8), fontSize: 11),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF102A43),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'المحادثة جاهزة، اكتب رسالتك الأولى...',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Align(
                        alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: msg.isMe ? const Color(0xFF0077B6) : const Color(0xFF1B3B5F),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg.text,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    msg.time,
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                  if (msg.isMe) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.done_all_rounded,
                                      size: 14,
                                      color: Color(0xFF00B4D8),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF102A43),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF0A192F),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF00B4D8),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}