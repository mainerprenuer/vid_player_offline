import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class VideoWidget extends StatefulWidget {
  final String videoUrl;
  const VideoWidget({super.key, required this.videoUrl});

  @override
  State<VideoWidget> createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _checkConnectionAndInitializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _checkConnectionAndInitializeVideo() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      _initializeVideoPlayer(widget.videoUrl);
    } else {
      Directory docDir = await getApplicationDocumentsDirectory();

      String subdirectoryName =
          widget.videoUrl.split('/').last.split('.').first;

      String workDir = '${docDir.path}/hls/$subdirectoryName';
      String localMp4VideoPath = '$workDir/output.mp4';
      print('Mp4 file path from local >>> $localMp4VideoPath');
      _initializeVideoPlayerFromFile(localMp4VideoPath);
    }
  }

  void _initializeVideoPlayer(String url) {
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        setState(() {});
        _controller?.play();
        // _controller!.setLooping(true);
      });
  }

  void _initializeVideoPlayerFromFile(String path) {
    _controller = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        setState(() {});
        _controller?.play();
        // _controller!.setLooping(true);
      });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _controller != null && _controller!.value.isInitialized
          ? AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            )
          : const CircularProgressIndicator(),
    );
  }
}
