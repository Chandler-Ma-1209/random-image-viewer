import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';

void main() {
  runApp(const MyApp());
}

/// Root widget that sets up theming and routing
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Random Image Viewer',
      debugShowCheckedModeBanner: false,
      // Light theme with Material Design 3
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const RandomImageScreen(),
    );
  }
}

/// Main screen that displays random images with adaptive background colors
class RandomImageScreen extends StatefulWidget {
  const RandomImageScreen({super.key});

  @override
  State<RandomImageScreen> createState() => _RandomImageScreenState();
}

class _RandomImageScreenState extends State<RandomImageScreen>
    with SingleTickerProviderStateMixin {
  // API endpoint for fetching random image URLs
  static const String apiUrl =
      'https://november7-730026606190.europe-west1.run.app/image';

  // State variables
  String? _currentImageUrl;
  bool _isLoading = false;
  String? _errorMessage;
  Color _backgroundColor = Colors.grey.shade200;

  // Animation controllers for smooth fade-in effect
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Set up fade animation for smooth image transitions
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    // Fetch the first image on app start
    _fetchRandomImage();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Fetches a random image URL from the API
  Future<void> _fetchRandomImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageUrl = data['url'] as String?;

        if (imageUrl != null && imageUrl.isNotEmpty) {
          setState(() {
            _currentImageUrl = imageUrl;
            _isLoading = false;
          });
          _fadeController.forward(from: 0.0);
          _extractColors(imageUrl);
        } else {
          throw Exception('Invalid image URL received');
        }
      } else {
        throw Exception('Failed to load image: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load image. Please try again.';
      });
    }
  }

  /// Extracts dominant colors from the image to set adaptive background
  Future<void> _extractColors(String imageUrl) async {
    try {
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 20,
      );

      if (mounted) {
        setState(() {
          _backgroundColor =
              paletteGenerator.dominantColor?.color ??
              paletteGenerator.vibrantColor?.color ??
              paletteGenerator.mutedColor?.color ??
              Colors.grey.shade200;
        });
      }
    } catch (e) {
      // If color extraction fails, keep the current background color
      debugPrint('Color extraction failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine background color based on theme and image state
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultBgColor = isDarkMode
        ? Colors.grey.shade900
        : Colors.grey.shade200;
    final displayBgColor = _currentImageUrl != null
        ? _backgroundColor
        : defaultBgColor;

    return Scaffold(
      body: Semantics(
        label: 'Random Image Viewer',
        container: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          color: displayBgColor,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Image Container
                    Expanded(
                      child: Center(
                        child: Semantics(
                          label: _currentImageUrl != null
                              ? 'Random image from Unsplash'
                              : 'Image loading area',
                          hint: _isLoading
                              ? 'Loading new image'
                              : _errorMessage != null
                              ? 'Failed to load image'
                              : 'Tap Another button to load new image',
                          image: _currentImageUrl != null && !_isLoading,
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: _buildImageWidget(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Another Button
                    Semantics(
                      button: true,
                      enabled: !_isLoading,
                      label: 'Another button',
                      hint: _isLoading
                          ? 'Loading new image, please wait'
                          : 'Double tap to load a new random image',
                      onTapHint: 'Load new image',
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _fetchRandomImage,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Another'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the main image widget with appropriate state (loading, error, or image)
  Widget _buildImageWidget(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (_currentImageUrl == null || _isLoading) {
      return _buildLoadingWidget();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Semantics(
        label: 'Random image displayed',
        hint: 'Image from Unsplash',
        image: true,
        excludeSemantics: true,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: _currentImageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildLoadingWidget(),
              errorWidget: (context, url, error) => _buildErrorWidget(),
              fadeInDuration: const Duration(milliseconds: 300),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the loading state UI with spinner and accessibility support
  Widget _buildLoadingWidget() {
    return Semantics(
      label: 'Loading image',
      hint: 'Please wait while the image is being fetched',
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Loading spinner',
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading image',
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: 'Loading status',
                child: Text(
                  'Loading...',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the error state UI with error message and accessibility support
  Widget _buildErrorWidget() {
    return Semantics(
      label: 'Error occurred',
      hint:
          '${_errorMessage ?? "Failed to load image"}. Tap Another button to try again',
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'Error icon',
                  child: Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade400,
                    semanticLabel: 'Error loading image',
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Error message',
                  child: Text(
                    _errorMessage ?? 'Failed to load image',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
