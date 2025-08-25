import 'package:flutter/material.dart';
import 'package:launchgo/config/environment.dart';
import 'package:launchgo/services/theme_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class VersionEnvironmentWidget extends StatefulWidget {
  final EdgeInsetsGeometry? padding;
  final TextAlign textAlign;
  final double fontSize;
  final bool showEnvironment;
  final bool centered;

  const VersionEnvironmentWidget({
    super.key,
    this.padding,
    this.textAlign = TextAlign.center,
    this.fontSize = 14,
    this.showEnvironment = true,
    this.centered = true,
  });

  @override
  State<VersionEnvironmentWidget> createState() => _VersionEnvironmentWidgetState();
}

class _VersionEnvironmentWidgetState extends State<VersionEnvironmentWidget> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  String get _versionText {
    // Only show environment suffix for stage, not for production
    final environment = widget.showEnvironment && EnvironmentConfig.isStage
        ? '-stage' 
        : '';
    return 'Version $_version.$_buildNumber$environment';
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    
    final textWidget = Text(
      _versionText,
      textAlign: widget.textAlign,
      style: TextStyle(
        color: themeService.textTertiaryColor,
        fontSize: widget.fontSize,
      ),
    );

    return Padding(
      padding: widget.padding ?? const EdgeInsets.all(20),
      child: widget.centered 
          ? Center(child: textWidget)
          : textWidget,
    );
  }
}