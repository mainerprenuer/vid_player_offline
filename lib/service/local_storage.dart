import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player_test/service/api.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/session_state.dart';

Future<void> cacheHLSStream(String url) async {
  print('M3U8 file url from server $url');
  print('Getting m3u8 file from server and saving to temporary directory...');
  Directory docDir = await getApplicationDocumentsDirectory();
  File? m3u8File = await getM3U8FileFromBrowser(url: url);

  List<String> varientPaths = await parseM3U8File(m3u8File!);
  print('parsed the m3u8 file from server to get all the varients...');
  print('varientPaths >>> $varientPaths');

  String varient = varientPaths.last.split('https').last;
  String varientUrl = 'https$varient';
  print('Getting the base url to use and download the segments...');
  String baseUrl = url.split('/HLS/').first;
  String segmentUrl = '$baseUrl/HLS/';
  print('segmentUrl >>> $segmentUrl');

  String subdirectoryName = url.split('/').last.split('.').first;
  String workDir = '${docDir.path}/hls/$subdirectoryName';
  createDirectoryIfNotExists(workDir);
  print('Create directory to save all downloaded segments...');

  final segmentsPath = await downloadM3U8File(url: varientUrl, wordir: workDir);
  final segments = await parseM3U8File(segmentsPath!);
  print('Downloaded a varient got the path to the segments...');
  print('segments >>> $segments');

  List<String> segmentsPaths = [];
  for (String segment in segments) {
    final segmentFile =
        await downloadM3U8File(url: segmentUrl + segment, wordir: workDir);
    segmentsPaths.add(segmentFile!.path);
    print(
        'Downloaded segment and save to local storage at ${segmentFile.path}...');
  }
  String outputFilePath = '$workDir/output.mp4';

  print('All segments paths >>> $segmentsPaths');

  await convertSegmentsToMp4(
    segmentsPaths: segmentsPaths,
    outputFilePath: outputFilePath,
    workDir: workDir,
  );

  print('Merged and converted the segments into a MP4 file...');
}

Future<List<String>> parseM3U8File(File m3u8File) async {
  List<String> playListPaths = [];
  String content = await m3u8File.readAsString();

  HlsPlaylistParser parser = HlsPlaylistParser.create();
  HlsPlaylist playlist =
      await parser.parseString(Uri.parse(m3u8File.path), content);

  if (playlist is HlsMasterPlaylist) {
    for (Variant varient in playlist.variants) {
      print('varient.url >>> ${varient.url.toString()}');
      playListPaths.add(varient.url.toString());
    }
  } else if (playlist is HlsMediaPlaylist) {
    for (Segment segment in playlist.segments) {
      print('segment.url >>> ${segment.url}');
      playListPaths.add(segment.url.toString());
    }
  }
  return playListPaths;
}

Future<void> convertSegmentsToMp4(
    {required List<String> segmentsPaths,
    required String outputFilePath,
    required String workDir}) async {
  // Build the input list for ffmpeg_kit_flutter
  List<String> inputList = [];
  for (String segment in segmentsPaths) {
    inputList.add('-i');
    inputList.add('$workDir/${segment.split('/').last}');
  }

  // Build the ffmpeg_kit_flutter command as a single string
  String command = '-y ${inputList.join(' ')} -h264 -c copy $outputFilePath';

  // Execute the ffmpeg_kit_flutter command
  final result = await FFmpegKit.executeAsync(command);
  final state = await result.getState();
  if (state == SessionState.completed) {
    if (kDebugMode) {
      print('Conversion to MP4 completed successfully.');
      final logs = await result.getAllLogsAsString();
      print('Error during conversion: $logs');
    }
  }
  if (kDebugMode) {
    print('output $outputFilePath');
  }
}

void createFileIfNotExists(String filePath) {
  File file = File(filePath);

  if (!file.existsSync()) {
    file.createSync(recursive: true);
  }
}

void createDirectoryIfNotExists(String directoryPath) {
  Directory directory = Directory(directoryPath);

  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
}
