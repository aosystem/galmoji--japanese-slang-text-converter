import 'package:just_audio/just_audio.dart';

import 'package:galmoji/const_value.dart';

class AudioPlay {
  static final List<AudioPlayer> _player01 = List.generate(6, (_) => AudioPlayer());
  int _player01Ptr = 0;

  static final AudioPlayer _warmUpPlayer = AudioPlayer();

  double _soundVolume = 0.0;

  AudioPlay() {
    constructor();
  }
  void constructor() async {
    for (int i = 0; i < _player01.length; i++) {
      await _player01[i].setVolume(0);
      await _player01[i].setAsset(ConstValue.audioHiyokos[i % ConstValue.audioHiyokos.length]);
    }
    await _warmUpPlayer.setAsset(ConstValue.audioZero);
    await _warmUpPlayer.load();
    playZero();
  }
  void dispose() {
    for (int i = 0; i < _player01.length; i++) {
      _player01[i].dispose();
    }
    _warmUpPlayer.dispose();
  }
  set soundVolume(double vol) {
    _soundVolume = vol;
  }
  void playZero() async {
    await _warmUpPlayer.play();
    await _warmUpPlayer.pause();
    await _warmUpPlayer.seek(Duration.zero);
  }
  void play01() async {
    if (_soundVolume == 0) {
      return;
    }
    _player01Ptr += 1;
    if (_player01Ptr >= _player01.length) {
      _player01Ptr = 0;
    }
    await _player01[_player01Ptr].setVolume(_soundVolume);
    await _player01[_player01Ptr].seek(Duration.zero);
    await _player01[_player01Ptr].play();
  }

}
