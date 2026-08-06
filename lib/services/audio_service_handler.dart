import 'package:audio_service/audio_service.dart';
import '../ffi/isolate_bridge.dart';

class CornigrumAudioHandler extends BaseAudioHandler {
  final CornigrumIsolateBridge bridge;

  CornigrumAudioHandler(this.bridge) {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.rewind,
        MediaControl.play,
        MediaControl.pause,
        MediaControl.fastForward,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [1, 2, 3],
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  void updateMetadata({
    required String title,
    required String artist,
    required String album,
    Duration? duration,
  }) {
    mediaItem.add(MediaItem(
      id: 'cornigrum_current_item',
      album: album,
      title: title,
      artist: artist,
      duration: duration,
    ));
  }

  @override
  Future<void> play() async {
    await bridge.play();
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: [MediaControl.pause, MediaControl.stop],
      processingState: AudioProcessingState.ready,
    ));
  }

  @override
  Future<void> pause() async {
    await bridge.pause();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [MediaControl.play, MediaControl.stop],
      processingState: AudioProcessingState.ready,
    ));
  }

  @override
  Future<void> stop() async {
    await bridge.stop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  @override
  Future<void> setSpeed(double speed) async {
    await bridge.setSpeed(speed);
  }
}
