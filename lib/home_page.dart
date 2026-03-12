import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:galmoji/parse_locale_tag.dart';
import 'package:galmoji/theme_color.dart';
import 'package:galmoji/theme_mode_number.dart';
import 'package:galmoji/const_value.dart';
import 'package:galmoji/setting_page.dart';
import 'package:galmoji/ad_manager.dart';
import 'package:galmoji/ad_banner_widget.dart';
import 'package:galmoji/model.dart';
import 'package:galmoji/audio_play.dart';
import 'package:galmoji/l10n/app_localizations.dart';
import 'package:galmoji/loading_screen.dart';
import 'package:galmoji/main.dart';

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});
  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> with SingleTickerProviderStateMixin {
  late AdManager _adManager;
  late ThemeColor _themeColor;
  bool _isReady = false;
  bool _isFirst = true;
  late AudioPlay _audioPlay;
  bool _areImagesPrecached = false;
  final TextEditingController _textEditingController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  int _backImageNumber = 0;
  int _lastBackImageNumber = 0;
  bool _convertKana = true;
  bool _convertAlphabet = false;
  late Random _random;
  String _inputText = '';
  String _convertedText = '';

  @override
  void initState() {
    super.initState();
    _initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_areImagesPrecached && Model.showBackImage) {
      for (var imagePath in ConstValue.imageBackGrounds) {
        precacheImage(AssetImage(imagePath), context);
      }
      _areImagesPrecached = true;
    }
  }

  void _initState() async {
    _adManager = AdManager();
    _audioPlay = AudioPlay();
    _audioPlay.playZero();
    int randomSeed = (DateTime.now()).millisecondsSinceEpoch;
    _random = Random(randomSeed);
    _backImageNumber = _random.nextInt(ConstValue.imageBackGrounds.length);
    _lastBackImageNumber = _backImageNumber;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _audioPlay.soundVolume = Model.soundVolume;
    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  void dispose() {
    _adManager.dispose();
    _textEditingController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _backImageChange() {
    if (!Model.showBackImage || _animationController.isAnimating) {
      return;
    }
    final int second = (DateTime.now()).millisecondsSinceEpoch ~/ 1000 ~/ 3;
    int newImageNumber = second % ConstValue.imageBackGrounds.length;
    if (newImageNumber == _backImageNumber) {
      newImageNumber = (newImageNumber + 1) % ConstValue.imageBackGrounds.length;
    }
    setState(() {
      _backImageNumber = newImageNumber;
    });
    _animationController.forward(from: 0.0).then((_) {
      setState(() {
        _lastBackImageNumber = _backImageNumber;
      });
      _animationController.reset();
    });
  }

  void _conversion() {
    if (!_isReady) {
      return;
    }
    final text = _inputText;
    final buffer = StringBuffer();
    final Map<String, List<String>> conversionMap = {};
    if (_convertKana) {
      conversionMap.addAll(ConstValue.galCharKana);
    }
    if (_convertAlphabet) {
      conversionMap.addAll(ConstValue.galCharAlphabet);
    }
    if (conversionMap.isEmpty) {
      setState(() {
        _convertedText = text;
      });
      return;
    }
    final sortedKeys = conversionMap.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    int i = 0;
    while (i < text.length) {
      String? matchedKey;
      for (final key in sortedKeys) {
        if (text.startsWith(key, i)) {
          matchedKey = key;
          break;
        }
      }
      if (matchedKey != null) {
        final List<String> values = conversionMap[matchedKey]!;
        final String to = values[_random.nextInt(values.length)];
        buffer.write(to);
        i += matchedKey.length;
      } else {
        buffer.write(text[i]);
        i += 1;
      }
    }
    setState(() {
      _convertedText = buffer.toString();
    });
  }

  void _onInputChanged(String text) {
    _inputText = text;
    _conversion();
  }

  void _onKanaChanged(bool value) {
    _audioPlay.play01();
    _backImageChange();
    setState(() {
      _convertKana = value;
    _conversion();
    });
  }

  void _onAlphabetChanged(bool value) {
    _audioPlay.play01();
    _backImageChange();
    setState(() {
      _convertAlphabet = value;
      _conversion();
    });
  }

  void _onRegenerate() {
    _audioPlay.play01();
    _conversion();
    _backImageChange();
  }

  void _onCopy(AppLocalizations l) {
    _audioPlay.play01();
    if (_convertedText.isNotEmpty) {
      FocusScope.of(context).unfocus();
      Clipboard.setData(ClipboardData(text: _convertedText));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.copied),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onShare() {
    _audioPlay.play01();
    if (_convertedText.isNotEmpty) {
      SharePlus.instance.share(ShareParams(text: _convertedText));
    }
  }

  Future<void> _openSetting() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingPage()),
    );
    if (!mounted) {
      return;
    }
    if (updated == true) {
      final mainState = context.findAncestorStateOfType<MainAppState>();
      if (mainState != null) {
        mainState
          ..themeMode = ThemeModeNumber.numberToThemeMode(Model.themeNumber)
          ..locale = parseLocaleTag(Model.languageCode)
          ..setState(() {});
      }
      _audioPlay.soundVolume = Model.soundVolume;
      _isFirst = true;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return Scaffold(
        body: LoadingScreen(),
      );
    }
    if (_isFirst) {
      _isFirst = false;
      _themeColor = ThemeColor(themeNumber: Model.themeNumber, context: context);
    }
    final AppLocalizations l = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: _themeColor.mainBackColor,
      ),
      child: Stack(
        children: [
          if (Model.showBackImage)
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(ConstValue.imageBackGrounds[_lastBackImageNumber]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (Model.showBackImage)
            FadeTransition(
              opacity: _opacityAnimation,
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(ConstValue.imageBackGrounds[_backImageNumber]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              foregroundColor: _themeColor.mainForeColor,
              backgroundColor: Colors.transparent,
              title: Text(l.appTitle, style: const TextStyle(fontSize: 15.0)),
              centerTitle: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _openSetting,
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              child: Column(children:[
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Column(children:[
                          _textFieldInput(l),
                          const SizedBox(height: 8),
                          Row(children: [
                            _toggleKana(l),
                            const SizedBox(width: 8),
                            _toggleAlphabet(l),
                          ]),
                          const SizedBox(height: 8),
                          _textFieldResult(),
                          const SizedBox(height: 4),
                          Row(children: [
                            _regenerationButton(l),
                            const SizedBox(width: 8),
                            _copyClipboardButton(l),
                            const SizedBox(width: 8),
                            _shareButton(l),
                          ]),
                        ]),
                      )
                    )
                  )
                ),
              ])
            ),
            bottomNavigationBar: AdBannerWidget(adManager: _adManager)
          )
        ],
      )
    );
  }

  Widget _textFieldInput(AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
        color: _themeColor.mainButtonBackColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          height: 200,
          child: TextField(
            expands: true,
            controller: _textEditingController,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            onChanged: _onInputChanged,
            decoration: InputDecoration(
              labelText: l.inputText,
              border: OutlineInputBorder(),
            )
          )
        )
      )
    );
  }

  Widget _toggleKana(AppLocalizations l) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: _themeColor.mainButtonBackColor,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 1, left: 8, right: 8, bottom: 1),
          child: Row(children: <Widget>[
            Expanded(
              child: Text(l.convertKana, style: TextStyle(fontSize: 12)),
            ),
            Switch(
              value: _convertKana,
              onChanged: _onKanaChanged,
            ),
          ]),
        )
      )
    );
  }

  Widget _toggleAlphabet(AppLocalizations l) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: _themeColor.mainButtonBackColor,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 1, left: 8, right: 8, bottom: 1),
          child: Row(children: <Widget>[
            Expanded(
              child: Text(l.convertAlphabet, style: TextStyle(fontSize: 12)),
            ),
            Switch(
              value: _convertAlphabet,
              onChanged: _onAlphabetChanged,
            ),
          ]),
        )
      )
    );
  }

  Widget _textFieldResult() {
    return Container(
      decoration: BoxDecoration(
        color: _themeColor.mainButtonBackColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SelectableText(
          _convertedText,
          style: const TextStyle(fontSize: 16),
          minLines: 1,
          maxLines: 10,
        )
      )
    );
  }

  Widget _regenerationButton(AppLocalizations l) {
    return Expanded(
      child: TextButton(
        onPressed: _onRegenerate,
        style: TextButton.styleFrom(
          backgroundColor: _themeColor.mainButtonBackColor,
          textStyle: TextStyle(fontSize: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(l.regenerate),
      ),
    );
  }

  Widget _copyClipboardButton(AppLocalizations l) {
    return Expanded(
      child: TextButton(
        onPressed: () => _onCopy(l),
        style: TextButton.styleFrom(
          backgroundColor: _themeColor.mainButtonBackColor,
          textStyle: TextStyle(fontSize: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(l.copy),
      ),
    );
  }

  Widget _shareButton(AppLocalizations l) {
    return Expanded(
      child: TextButton(
        onPressed: _onShare,
        style: TextButton.styleFrom(
          backgroundColor: _themeColor.mainButtonBackColor,
          textStyle: TextStyle(fontSize: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(l.send),
      ),
    );
  }

}
