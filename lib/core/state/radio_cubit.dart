import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/radio_channel.dart';
import 'radio_state.dart';

/// Live Quran radio playback.
///
/// Before this existed the play button only swapped an icon; nothing was ever
/// played. One player is reused for every station, so starting a new station
/// implicitly stops the previous one.
class RadioCubit extends Cubit<RadioState> {
  RadioCubit({AudioPlayer? player})
    : _player = player ?? AudioPlayer(),
      super(const RadioState()) {
    _sub = _player.playerStateStream.listen((playerState) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isPlaying: playerState.playing,
          isBuffering:
              playerState.processingState == ProcessingState.loading ||
              playerState.processingState == ProcessingState.buffering,
        ),
      );
    });
  }

  final AudioPlayer _player;
  StreamSubscription<PlayerState>? _sub;

  /// Called before a station starts, so Quran recitation can be stopped first.
  /// Set from `main()` once both cubits exist — injecting the cubits into each
  /// other would be a construction cycle.
  Future<void> Function()? onBeforePlay;

  /// Starts [index], or pauses it when it is already the active station.
  Future<void> toggle(int index) async {
    emit(state.copyWith(clearError: true));

    if (state.currentIndex == index) {
      _player.playing ? await _player.pause() : await _player.play();
      return;
    }

    await onBeforePlay?.call();
    if (isClosed) return;

    emit(state.copyWith(currentIndex: index, isBuffering: true));

    try {
      await _player.setUrl(RadioChannel.channels[index].streamUrl);
      await _player.setVolume(1);
      if (isClosed) return;
      emit(state.copyWith(isMuted: false));
      // Not awaited: for a live stream `play()` only completes when playback
      // ends, so awaiting would hang this call forever.
      unawaited(_player.play());
    } catch (e) {
      debugPrint('Radio stream failed for index $index: $e');
      if (isClosed) return;
      emit(
        state.copyWith(
          clearIndex: true,
          isBuffering: false,
          errorKey: 'stream_unreachable',
        ),
      );
    }
  }

  Future<void> toggleMute() async {
    if (state.currentIndex == null) return;
    final muted = !state.isMuted;
    await _player.setVolume(muted ? 0 : 1);
    if (isClosed) return;
    emit(state.copyWith(isMuted: muted));
  }

  /// Called when Quran recitation starts, so the two never talk over each other.
  Future<void> stop() async {
    await _player.stop();
    if (isClosed) return;
    emit(const RadioState());
  }

  void clearError() => emit(state.copyWith(clearError: true));

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await _player.dispose();
    return super.close();
  }
}
