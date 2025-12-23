import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_oknob/flutter_oldschool_knob.dart';
import 'package:just_audio/just_audio.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:sautifyv2/services/audio_player_service.dart';
import 'package:sautifyv2/services/settings_service.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final _audioService = AudioPlayerService();
  final _settings = SettingsService();
  AndroidEqualizerParameters? _parameters;
  bool _isLoading = true;
  bool _isEnabled = false;
  final double _value = 0.5;

  @override
  void initState() {
    super.initState();
    _initEqualizer();
  }

  Future<void> _initEqualizer() async {
    if (!Platform.isAndroid) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      _parameters = await _audioService.equalizer.parameters;
      _isEnabled = _settings.equalizerEnabled;
      // Ensure equalizer state matches settings
      await _audioService.equalizer.setEnabled(_isEnabled);
    } catch (e) {
      debugPrint('Error initializing equalizer: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

    if (!Platform.isAndroid) {
      return Scaffold(
        backgroundColor: scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Equalizer'),
          backgroundColor: scaffoldBackgroundColor,
          foregroundColor: textColor,
        ),
        body: Center(
          child: Text(
            'Equalizer is only available on Android',
            style: TextStyle(color: textColor),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Equalizer'),
        backgroundColor: scaffoldBackgroundColor,
        foregroundColor: textColor,
        actions: [
          Switch(
            value: _isEnabled,
            onChanged: (value) async {
              setState(() => _isEnabled = value);
              await _settings.setEqualizerEnabled(value);
              await _audioService.equalizer.setEnabled(value);
            },
            activeThumbColor: primaryColor,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: LoadingIndicatorM3E(
                containerColor: primaryColor.withAlpha(100),
                variant: LoadingIndicatorM3EVariant.contained,
                color: primaryColor,
              ),
            )
          : _parameters == null
          ? Center(
              child: Text(
                'Equalizer not available',
                style: TextStyle(color: textColor),
              ),
            )
          : _buildBands(),
    );
  }

  Widget _buildBands() {
    final bands = _parameters!.bands;
    final minDecibels = _parameters!.minDecibels;
    final maxDecibels = _parameters!.maxDecibels;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final cardColor = Theme.of(context).cardColor;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: bands.map((band) {
                final freq = band.centerFrequency;
                final freqLabel = freq < 1000
                    ? '${freq.toInt()} Hz'
                    : '${(freq / 1000).toStringAsFixed(1)} kHz';

                // Get current gain from settings or default to 0
                final currentGain = _settings.equalizerBands[band.index] ?? 0.0;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                          ),
                          child: Slider(
                            value: currentGain.clamp(-15.0, 15.0),
                            min: -15.0,
                            max: 15.0,
                            activeColor: _isEnabled
                                ? primaryColor
                                : Colors.grey,
                            inactiveColor: cardColor,
                            onChanged: _isEnabled
                                ? (value) async {
                                    setState(() {
                                      _settings.equalizerBands[band.index] =
                                          value;
                                    });
                                    await band.setGain(
                                      value.clamp(minDecibels, maxDecibels),
                                    );
                                    _settings.setEqualizerBand(
                                      band.index,
                                      value,
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      freqLabel,
                      style: TextStyle(
                        color: _isEnabled ? textColor : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currentGain.toStringAsFixed(1)} dB',
                      style: TextStyle(
                        color: _isEnabled
                            ? textColor.withAlpha(150)
                            : Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          // Reset button
          TextButton(
            onPressed: _isEnabled
                ? () async {
                    for (final band in bands) {
                      await band.setGain(0.0);
                      await _settings.setEqualizerBand(band.index, 0.0);
                    }
                    setState(() {});
                  }
                : null,
            child: Text(
              'Reset to Flat',
              style: TextStyle(color: _isEnabled ? primaryColor : Colors.grey),
            ),
          ),
          //     const Divider(color: Colors.grey),
          const SizedBox(height: 10),
          _buildSpeedAndPitchControl(),
          const SizedBox(height: 10),
          _buildSkipSilenceControl(),
          const SizedBox(height: 10),
          _buildLoudnessEnhancerControl(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSkipSilenceControl() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Skip Silence', style: TextStyle(color: textColor)),
          Switch(
            value: _settings.skipSilenceEnabled,
            onChanged: (value) async {
              setState(() {
                _settings.skipSilenceEnabled = value;
              });
              await _audioService.player.setSkipSilenceEnabled(value);
              await _settings.setSkipSilenceEnabled(value);
            },
            activeThumbColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildLoudnessEnhancerControl() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Loudness Enhancer', style: TextStyle(color: textColor)),
              Switch(
                value: _settings.loudnessEnhancerEnabled,
                onChanged: (value) async {
                  setState(() {
                    _settings.loudnessEnhancerEnabled = value;
                  });
                  await _audioService.loudnessEnhancer.setEnabled(value);
                  await _settings.setLoudnessEnhancerEnabled(value);
                },
                activeThumbColor: primaryColor,
              ),
            ],
          ),
        ),
        if (_settings.loudnessEnhancerEnabled)
          Column(
            children: [
              const SizedBox(height: 10),
              SizedBox(
                width: 140,
                height: 170,
                child: FlutterOKnob(
                  minValue: -10.0,
                  maxValue: 20.0,
                  size: 140,
                  knobvalue: _settings.loudnessEnhancerTargetGain,
                  showKnobLabels: false,
                  maxRotationAngle: 180,
                  sensitivity: 0.6,
                  onChanged: (value) async {
                    final clamped = value.clamp(0.0, 20.0);
                    final rounded = double.parse(clamped.toStringAsFixed(1));
                    setState(() {
                      _settings.loudnessEnhancerTargetGain = rounded;
                    });
                    await _audioService.loudnessEnhancer.setTargetGain(rounded);
                    await _settings.setLoudnessEnhancerTargetGain(rounded);
                  },
                  knobLabel: Text(
                    'Gain',
                    style: TextStyle(color: textColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gain: ${_settings.loudnessEnhancerTargetGain.toStringAsFixed(1)} dB',
                style: TextStyle(color: textColor),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSpeedAndPitchControl() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Speed Control
          Column(
            children: [
              SizedBox(
                width: 140,
                height: 170,
                child: FlutterOKnob(
                  minValue: 0.5,
                  maxValue: 2.0,
                  size: 140,
                  markerColor: primaryColor,
                  knobvalue: _settings.defaultPlaybackSpeed,
                  showKnobLabels: false,
                  maxRotationAngle: 180,
                  sensitivity: 0.6,
                  onChanged: (value) async {
                    var clamped = value.clamp(0.5, 2.0);
                    final rounded = double.parse(clamped.toStringAsFixed(2));
                    setState(() {
                      _settings.defaultPlaybackSpeed = rounded;
                    });
                    await _audioService.player.setSpeed(rounded);
                    await _settings.setDefaultPlaybackSpeed(rounded);
                  },
                  knobLabel: Text('Speed', style: TextStyle(color: textColor)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Speed: ${_settings.defaultPlaybackSpeed.toStringAsFixed(2)}x',
                style: TextStyle(color: textColor),
              ),
            ],
          ),
          // Pitch Control
          Column(
            children: [
              SizedBox(
                width: 140,
                height: 170,
                child: FlutterOKnob(
                  minValue: 0.5,
                  maxValue: 2.0,
                  markerColor: primaryColor,
                  size: 140,
                  knobvalue: _settings.pitch,
                  showKnobLabels: false,
                  maxRotationAngle: 180,
                  sensitivity: 0.6,
                  onChanged: (value) async {
                    var clamped = value.clamp(0.5, 2.0);
                    final rounded = double.parse(clamped.toStringAsFixed(2));
                    setState(() {
                      _settings.pitch = rounded;
                    });
                    await _audioService.player.setPitch(rounded);
                    await _settings.setPitch(rounded);
                  },
                  knobLabel: Text('Pitch', style: TextStyle(color: textColor)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pitch: ${_settings.pitch.toStringAsFixed(2)}x',
                style: TextStyle(color: textColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
