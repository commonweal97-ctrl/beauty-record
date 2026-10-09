import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../widgets/cached_image.dart';

class HeroSlider extends StatefulWidget {
  final List<String> photos;
  final Color primaryColor;
  
  const HeroSlider({
    super.key,
    required this.photos,
    required this.primaryColor,
  });

  @override
  State<HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<HeroSlider> {
  int _currentSlide = 0;
  Timer? _autoplayTimer;
  final PageController _controller = PageController();
  
  @override
  void initState() {
    super.initState();
    _startAutoplay();
  }
  
  @override
  void dispose() {
    _autoplayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
  
  void _startAutoplay() {
    _autoplayTimer?.cancel();
    if (widget.photos.length > 1) {
      _autoplayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_controller.hasClients) {
          final next = (_currentSlide + 1) % widget.photos.length;
          _controller.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(
        height: 280,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.photo, size: 64, color: Colors.grey),
        ),
      );
    }
    
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (idx) => setState(() => _currentSlide = idx),
            itemBuilder: (_, i) => CachedAvatar(
              url: widget.photos[i],
              size: double.infinity,
              radius: 0,
            ),
          ),
          Positioned(
            top: 60, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${_currentSlide + 1}/${widget.photos.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          Positioned(
            bottom: 12, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.photos.length, (i) {
                return GestureDetector(
                  onTap: () => _controller.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                  child: Container(
                    width: 24, height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _currentSlide == i ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}