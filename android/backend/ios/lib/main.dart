import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const ZawarUniversalDownloaderApp());
}

class ZawarUniversalDownloaderApp extends StatelessWidget {
  const ZawarUniversalDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zawar Downloader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const DownloaderScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _pathController = TextEditingController();
  
  bool _isFetching = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  
  String _videoTitle = "";
  String _directDownloadUrl = "";
  String _videoExtension = "";
  String _sourceSite = "";

  // This will be replaced by your Render.com URL later!
  final String _pythonApiBaseUrl = 'https://YOUR_RENDER_URL.onrender.com/api/extract';

  @override
  void initState() {
    super.initState();
    _initDefaultPath();
  }

  Future<void> _initDefaultPath() async {
    if (Platform.isAndroid) {
      _pathController.text = "/storage/emulated/0/Download";
    } else {
      final dir = await getDownloadsDirectory();
      _pathController.text = dir?.path ?? "";
    }
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      var manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) return true;
      var storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;
      return false;
    }
    return true;
  }

  Future<void> _fetchVideoDetails() async {
    if (_urlController.text.isEmpty) return;

    setState(() {
      _isFetching = true;
      _videoTitle = "";
      _directDownloadUrl = "";
    });

    try {
      final uri = Uri.parse('$_pythonApiBaseUrl?url=${Uri.encodeComponent(_urlController.text)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _videoTitle = data['title'];
            _directDownloadUrl = data['direct_url'];
            _videoExtension = data['ext'];
            _sourceSite = data['extractor'];
            _isFetching = false;
          });
        }
      } else {
        throw Exception('Server Error: Make sure your Python server is running.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('API Error: $e')));
      }
    }
  }

  Future<void> _startDownload() async {
    if (_directDownloadUrl.isEmpty) return;

    bool hasPermission = await _requestPermissions();
    if (!hasPermission) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage Permission Required.')));
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      String safeTitle = _videoTitle.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      if (safeTitle.isEmpty) safeTitle = "Video_${DateTime.now().millisecondsSinceEpoch}";
      
      File file = File('${_pathController.text}/$safeTitle.$_videoExtension');
      var request = http.Request('GET', Uri.parse(_directDownloadUrl));
      var response = await http.Client().send(request);
      
      var totalBytes = response.contentLength ?? 0;
      var bytesDownloaded = 0;
      var fileStream = file.openWrite();

      await for (var chunk in response.stream) {
        bytesDownloaded += chunk.length;
        fileStream.add(chunk);
        if (totalBytes != 0) {
          setState(() {
            _downloadProgress = bytesDownloaded / totalBytes;
          });
        }
      }
      await fileStream.flush();
      await fileStream.close();

      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download Complete!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _clearFields() {
    setState(() {
      _urlController.clear();
      _isDownloading = false;
      _downloadProgress = 0.0;
      _videoTitle = "";
      _directDownloadUrl = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zawar Downloader', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50), 
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Developed By Zawar Baig', style: TextStyle(color: Colors.black, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('URL: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: TextField(controller: _urlController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste FB, Insta, YT link here', contentPadding: EdgeInsets.symmetric(horizontal: 10)))),
                const SizedBox(width: 5),
                ElevatedButton(onPressed: _isFetching ? null : _fetchVideoDetails, child: _isFetching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Fetch')),
                const SizedBox(width: 5),
                ElevatedButton(onPressed: _clearFields, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Clear', style: TextStyle(color: Colors.white))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Save: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: TextField(controller: _pathController, decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)))),
              ],
            ),
            const SizedBox(height: 20),
            if (_videoTitle.isNotEmpty) ...[
              Text(_videoTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Text('Source: $_sourceSite', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey[300]),
                    columns: const [
                      DataColumn(label: Text('Format', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Quality', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: [
                      DataRow(cells: [
                        DataCell(Text(_videoExtension.toUpperCase(), style: const TextStyle(color: Colors.blue))),
                        const DataCell(Text('Best Available', style: TextStyle(color: Colors.blue))),
                        DataCell(
                          TextButton.icon(
                            onPressed: _isDownloading ? null : _startDownload,
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Download'),
                          ),
                        ),
                      ])
                    ],
                  ),
                ),
              ),
            ] else if (!_isFetching)
              const Expanded(child: Center(child: Text('Paste a link from Facebook, Instagram, or YouTube to begin.'))),

            if (_isDownloading) ...[
              const SizedBox(height: 10),
              Text('Downloading... ${(_downloadProgress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              LinearProgressIndicator(value: _downloadProgress, backgroundColor: Colors.grey[300], valueColor: const AlwaysStoppedAnimation<Color>(Colors.green), minHeight: 10),
            ],
          ],
        ),
      ),
    );
  }
}
