import 'package:flutter/material.dart';

class ResponsiveHelper {
  final BuildContext context;
  late double _screenWidth;
  late double _screenHeight;
  late bool _isTablet;
  late bool _isPhone;
  late double _scaleFactor;

  ResponsiveHelper(this.context) {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _isTablet = _screenWidth > 600;
    _isPhone = _screenWidth <= 600;
    
    // Calculate scale factor based on screen width
    // Base width: 360 (standard phone), 768 (tablet)
    if (_isPhone) {
      _scaleFactor = _screenWidth / 360;
    } else {
      _scaleFactor = _screenWidth / 768;
    }
  }

  // Get responsive width
  double getWidth(double percentage) {
    return _screenWidth * (percentage / 100);
  }

  // Get responsive height
  double getHeight(double percentage) {
    return _screenHeight * (percentage / 100);
  }

  // Get responsive font size with better scaling
  double getFontSize(double baseSize) {
    // Clamp the scale factor to avoid too small or too large text
    final clampedScale = _scaleFactor.clamp(0.8, 1.3);
    return baseSize * clampedScale;
  }

  // Check if device is tablet
  bool get isTablet => _isTablet;

  // Check if device is phone
  bool get isPhone => _isPhone;

  // Get minimum touch target size (48dp minimum, 56dp ideal)
  double get minTouchTarget => _isPhone ? 48.0 : 56.0;

  // Get responsive padding with better scaling
  double getPadding(double baseSize) {
    final clampedScale = _scaleFactor.clamp(0.7, 1.2);
    return baseSize * clampedScale;
  }

  // Get responsive margin
  double getMargin(double baseSize) {
    final clampedScale = _scaleFactor.clamp(0.7, 1.2);
    return baseSize * clampedScale;
  }

  // Get number of grid columns based on screen size
  int getGridColumns() {
    if (_screenWidth > 1200) return 6;
    if (_screenWidth > 900) return 4;
    if (_screenWidth > 600) return 3;
    if (_screenWidth > 400) return 2;
    return 2;
  }

  // Get card aspect ratio based on screen size
  double getCardAspectRatio() {
    if (_isTablet) return 1.5;
    return 1.2;
  }

  // Métodos de compatibilidad con código existente
  double wp(double percentage) => getWidth(percentage);
  double hp(double percentage) => getHeight(percentage);
  double sp(double baseSize) => getFontSize(baseSize);
  double width(double percentage) => getWidth(percentage);
  double height(double percentage) => getHeight(percentage);
}
