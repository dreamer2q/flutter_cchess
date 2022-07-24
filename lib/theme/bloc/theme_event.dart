part of 'theme_bloc.dart';

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();
}

class ThemeUpdated extends ThemeEvent {
  const ThemeUpdated(this.theme);

  final BoardTheme theme;

  @override
  List<Object?> get props => [theme];
}
