import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CardDiv extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String ID;
    final double price;


  final String companyId;
  final VoidCallback? onTap;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;

  const CardDiv({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.description,

    required this.companyId,
    this.onTap,
    required this.ID,
    required this.isBookmarked,
    required this.onBookmarkToggle, required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth * 0.85; // Reduced width
        final cardHeight = cardWidth * 0.75; // Adjusted aspect ratio

return Card(
  clipBehavior: Clip.hardEdge,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12), // Smaller border radius
  ),
  elevation: 3, // Reduced shadow
  shadowColor: Colors.black26,
  child: InkWell(
    borderRadius: BorderRadius.circular(12),
    splashColor: Colors.tealAccent.withAlpha(30),
    onTap: onTap ?? () => debugPrint('Card tapped.'),
    child: Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.tealAccent.shade100, Colors.tealAccent.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 55, // 55% for image
                child: _buildImage(),
              ),
              Expanded(
                flex: 45, // 45% for content
                child: _buildContent(context),
              ),
            ],
          ),
          _buildBookmarkButton(),
        ],
      ),
    ),
  ),
);
      },
    );
  }

  Widget _buildImage() {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: loadingProgress.cumulativeBytesLoaded /
                (loadingProgress.expectedTotalBytes ?? 1),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[200],
        child: Center(
          child: Icon(Icons.broken_image, color: Colors.grey[400]),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 8), // Reduced padding
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 40), // Title height limit
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600, // Semi-bold instead of bold
                    height: 1.2, // Line height
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            
          ),
          Text(
              description,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600, // Semi-bold instead of bold
                    height: 1.2, // Line height
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          _buildLocationRow(),
         // _buildManagerText(),
        ],
      ),
    );
  }

  Widget _buildLocationRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.attach_money, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            price.toString(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }



  Widget _buildBookmarkButton() {
    return Positioned(
      top: 6,
      right: 6,
      child: Material(
        type: MaterialType.transparency,
        child: IconButton(
          iconSize: 20, // Smaller icon
          padding: EdgeInsets.zero,
          icon: Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
            color: isBookmarked ? Colors.blue[800] : Colors.white70,
          ),
          onPressed: onBookmarkToggle,
        ),
      ),
    );
  }
}