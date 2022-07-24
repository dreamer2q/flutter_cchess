part of 'theme_bloc.dart';

class ThemeState extends Equatable {
  const ThemeState({
    required this.theme,
  });

  final BoardTheme theme;

  @override
  List<Object> get props => [theme];

  ThemeState copyWith({
    BoardTheme? theme,
  }) {
    return ThemeState(
      theme: theme ?? this.theme,
    );
  }
}
