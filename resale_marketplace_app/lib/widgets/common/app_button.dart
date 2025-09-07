import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum ButtonType { primary, secondary, outline, text, danger }
enum ButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: _buildButton(context, isDisabled),
    );
  }

  Widget _buildButton(BuildContext context, bool isDisabled) {
    switch (type) {
      case ButtonType.primary:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: _getButtonStyle(context, isDisabled),
          child: _buildButtonContent(),
        );
      case ButtonType.secondary:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: _getButtonStyle(context, isDisabled),
          child: _buildButtonContent(),
        );
      case ButtonType.outline:
        return OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: _getOutlineButtonStyle(context, isDisabled),
          child: _buildButtonContent(),
        );
      case ButtonType.text:
        return TextButton(
          onPressed: isDisabled ? null : onPressed,
          style: _getTextButtonStyle(context, isDisabled),
          child: _buildButtonContent(),
        );
      case ButtonType.danger:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: _getDangerButtonStyle(context, isDisabled),
          child: _buildButtonContent(),
        );
    }
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        height: _getIconSize(),
        width: _getIconSize(),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            type == ButtonType.outline || type == ButtonType.text
                ? AppTheme.primaryColor
                : Colors.white,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _getIconSize()),
          SizedBox(width: AppTheme.spacingSm),
          Text(text),
        ],
      );
    }

    return Text(text);
  }

  ButtonStyle _getButtonStyle(BuildContext context, bool isDisabled) {
    Color backgroundColor;
    Color foregroundColor;

    switch (type) {
      case ButtonType.primary:
        backgroundColor = isDisabled ? AppTheme.textDisabled : AppTheme.primaryColor;
        foregroundColor = Colors.white;
        break;
      case ButtonType.secondary:
        backgroundColor = isDisabled ? AppTheme.textDisabled : AppTheme.secondaryColor;
        foregroundColor = Colors.white;
        break;
      default:
        backgroundColor = AppTheme.primaryColor;
        foregroundColor = Colors.white;
    }

    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      padding: padding ?? _getPadding(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      textStyle: _getTextStyle(),
    );
  }

  ButtonStyle _getOutlineButtonStyle(BuildContext context, bool isDisabled) {
    return OutlinedButton.styleFrom(
      foregroundColor: isDisabled ? AppTheme.textDisabled : AppTheme.primaryColor,
      padding: padding ?? _getPadding(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      side: BorderSide(
        color: isDisabled ? AppTheme.textDisabled : AppTheme.primaryColor,
      ),
      textStyle: _getTextStyle(),
    );
  }

  ButtonStyle _getTextButtonStyle(BuildContext context, bool isDisabled) {
    return TextButton.styleFrom(
      foregroundColor: isDisabled ? AppTheme.textDisabled : AppTheme.primaryColor,
      padding: padding ?? _getPadding(),
      textStyle: _getTextStyle(),
    );
  }

  ButtonStyle _getDangerButtonStyle(BuildContext context, bool isDisabled) {
    return ElevatedButton.styleFrom(
      backgroundColor: isDisabled ? AppTheme.textDisabled : AppTheme.errorColor,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: padding ?? _getPadding(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      textStyle: _getTextStyle(),
    );
  }

  EdgeInsetsGeometry _getPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        );
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLg,
          vertical: AppTheme.spacingMd,
        );
      case ButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingXl,
          vertical: AppTheme.spacingLg,
        );
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case ButtonSize.small:
        return const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      case ButtonSize.medium:
        return const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
      case ButtonSize.large:
        return const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 18;
      case ButtonSize.large:
        return 20;
    }
  }
}

// 특수 버튼들
class AppFloatingActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final bool mini;

  const AppFloatingActionButton({
    Key? key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.mini = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      mini: mini,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      child: Icon(icon),
    );
  }
}

class AppIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? color;
  final double? size;

  const AppIconButton({
    Key? key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.color,
    this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      color: color ?? AppTheme.textSecondary,
      iconSize: size ?? 24,
    );
  }
}