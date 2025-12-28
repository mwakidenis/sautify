import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:sautifyv2/constants/ui_colors.dart';

class ThemeState extends Equatable {
  final List<Color> primaryColors;

  const ThemeState({
    this.primaryColors = const [],
  });

  factory ThemeState.initial() {
    return ThemeState(
      primaryColors: [bgcolor.withAlpha(200), bgcolor, Colors.black],
    );
  }

  ThemeState copyWith({
    List<Color>? primaryColors,
  }) {
    return ThemeState(
      primaryColors: primaryColors ?? this.primaryColors,
    );
  }

  @override
  List<Object?> get props => [primaryColors];
}
