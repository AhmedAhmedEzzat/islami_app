import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sakina/core/state/radio_cubit.dart';

/// Just enough of a player for the radio: it records what it was asked to
/// load and lets a test drop the stream.
class _FakePlayer implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast();
  final errors = StreamController<PlayerException>.broadcast();
  final loaded = <String>[];
  bool failNextLoad = false;
  bool stopped = false;

  @override
  bool playing = false;

  @override
  Stream<PlayerState> get playerStateStream => states.stream;

  @override
  Stream<PlayerException> get errorStream => errors.stream;

  @override
  Future<Duration?> setUrl(String url, {Map<String, String>? headers, Duration? initialPosition, bool preload = true, dynamic tag}) async {
    if (failNextLoad) {
      failNextLoad = false;
      throw PlayerException(0, 'no connection', null);
    }
    loaded.add(url);
    return null;
  }

  @override
  Future<void> play() async {
    playing = true;
    states.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> pause() async {
    playing = false;
    states.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> stop() async {
    playing = false;
    stopped = true;
    states.add(PlayerState(false, ProcessingState.idle));
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}

  void drop() => errors.add(PlayerException(1, 'connection lost', null));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late _FakePlayer player;
  late RadioCubit radio;

  setUp(() {
    RadioCubit.reconnectDelay = Duration.zero;
    player = _FakePlayer();
    radio = RadioCubit(player: player);
  });
  tearDown(() => radio.close());

  test('a dropped stream is reconnected once, without a word', () async {
    await radio.toggle(0);
    await _settle();
    expect(radio.state.isPlayingAt(0), isTrue);

    player.drop();
    await _settle();
    expect(player.loaded, hasLength(2));
    expect(player.loaded.last, player.loaded.first);
    expect(radio.state.isPlayingAt(0), isTrue);
    expect(radio.state.errorKey, isNull);
  });

  test('a stream that drops again is given up on, and says so', () async {
    await radio.toggle(0);
    await _settle();
    player.drop();
    await _settle();
    player.drop();
    await _settle();

    expect(player.loaded, hasLength(2));
    expect(player.stopped, isTrue);
    expect(radio.state.currentIndex, isNull);
    expect(radio.state.isPlaying, isFalse);
    expect(radio.state.errorKey, 'stream_unreachable');
  });

  test('a reconnect that fails clears the station', () async {
    await radio.toggle(0);
    await _settle();
    player.failNextLoad = true;
    player.drop();
    await _settle();

    expect(radio.state.currentIndex, isNull);
    expect(radio.state.errorKey, 'stream_unreachable');
  });

  test('choosing another station gets a reconnect of its own', () async {
    await radio.toggle(0);
    await _settle();
    player.drop();
    await _settle();

    await radio.toggle(1);
    await _settle();
    player.drop();
    await _settle();
    expect(radio.state.isPlayingAt(1), isTrue);
    expect(radio.state.errorKey, isNull);
  });

  test('a stream stopped while waiting to reconnect stays stopped', () async {
    RadioCubit.reconnectDelay = const Duration(milliseconds: 10);
    await radio.toggle(0);
    await _settle();
    player.drop();
    await Future<void>.delayed(Duration.zero);
    await radio.stop();
    await _settle();

    expect(player.loaded, hasLength(1));
    expect(radio.state.currentIndex, isNull);
    expect(radio.state.errorKey, isNull);
  });
}
