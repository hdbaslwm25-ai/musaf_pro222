import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: EducationalLibraryPage(),
  ));
}

// ==========================================
// 1. قاعدة البيانات المصغرة لجميع المقاطع
// ==========================================
final List<Map<String, String>> allAvailableLessons = [
  {
    'title': 'الطريقة الصحيحة لاسعاف نوبة الصرع',
    'category': 'الكل',
    'level': 'سهل',
    'views': '2.4 ألف مشاهدة',
    'duration': '10:43',
    'image': 'https://img.youtube.com/vi/gynQdWDHbeI/mqdefault.jpg',
    'videoId': 'gynQdWDHbeI',
  },
  {
    'title': 'كيفية التعامل مع الجروح العميقة والنزيف',
    'category': 'الجروح والنزيف',
    'level': 'سهل',
    'views': '450 مشاهدة',
    'duration': '05:20',
    'image': 'https://img.youtube.com/vi/7YaZ2IyHdxk/mqdefault.jpg',
    'videoId': '7YaZ2IyHdxk',
  },
  {
    'title': 'الإسعافات الأولية للكسور والالتواءات',
    'category': 'الكسور والالتواءات',
    'level': 'متوسط',
    'views': '800 مشاهدة',
    'duration': '07:12',
    'image': 'https://img.youtube.com/vi/lY7DLGaz4ek/mqdefault.jpg',
    'videoId': 'lY7DLGaz4ek',
  },
  {
    'title': 'كيفية التعامل مع الحروق بدرجاتها',
    'category': 'الحروق',
    'level': 'متقدم',
    'views': '1.5 ألف مشاهدة',
    'duration': '06:30',
    'image': 'https://img.youtube.com/vi/QDMaHvh-RSA/mqdefault.jpg',
    'videoId': 'QDMaHvh-RSA',
  },
  {
    'title': 'الإسعافات الأولية لحالات الاختناق (الغصة)',
    'category': 'الكل',
    'level': 'متوسط',
    'views': '1.2 ألف مشاهدة',
    'duration': '08:15',
    'image': 'https://img.youtube.com/vi/_YxL-SEJwik/mqdefault.jpg',
    'videoId': '_YxL-SEJwik',
  },
];

// ==========================================
// 2. الصفحة الرئيسية للمكتبة
// ==========================================
class EducationalLibraryPage extends StatefulWidget {
  const EducationalLibraryPage({super.key});

  @override
  State<EducationalLibraryPage> createState() => _EducationalLibraryPageState();
}

class _EducationalLibraryPageState extends State<EducationalLibraryPage> {
  YoutubePlayerController? _mainController; 
  String _currentVideoId = '_YxL-SEJwik'; 
  String _currentCategoryName = 'الكل';

  final ScrollController _scrollController = ScrollController();
  
  // استخدمنا ValueNotifier للاستماع لقيمة التمرير بشكل منفصل دون عمل setState للشاشة كاملة
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);

  final Map<String, String> _categoryVideos = {
    'الكل': '_YxL-SEJwik',
    'الجروح والنزيف': '7YaZ2IyHdxk', 
    'الكسور والالتواءات': 'lY7DLGaz4ek', 
    'الحروق': 'QDMaHvh-RSA', 
    'التسمم واللدغات': '_YxL-SEJwik',
    'إسعافات الأطفال': '_YxL-SEJwik',
  };

  @override
  void initState() {
    super.initState();
    _initPlayer(_currentVideoId); 
    
    // ربط المتحكم بـ Notifier لتحديث قيم التمرير بسلاسة وبدون تعليق
    _scrollController.addListener(() {
      _scrollOffsetNotifier.value = _scrollController.offset;
    });
  }

  void _initPlayer(String videoId) {
    _mainController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        isLive: false,
        forceHD: false,
        enableCaption: false,
        disableDragSeek: false,
      ),
    );
  }

  void _onCategorySelected(String categoryName) {
    if (!mounted) return;
    setState(() {
      _currentCategoryName = categoryName;
    });

    final String? targetVideoId = _categoryVideos[categoryName];
    if (targetVideoId != null && targetVideoId != _currentVideoId) {
      _mainController?.dispose(); 
      setState(() {
        _currentVideoId = targetVideoId;
        _initPlayer(targetVideoId); 
      });
    }
  }

  void _onLessonSelected(String videoId) {
    if (videoId != _currentVideoId && mounted) {
      _mainController?.dispose();
      setState(() {
        _currentVideoId = videoId;
        _initPlayer(videoId);
      });
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openCustomFullScreen() async {
    if (_mainController == null) return;
    
    final currentPosition = _mainController!.value.position;
    _mainController!.pause();

    final Duration? newPosition = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CustomFullScreenPlayer(
          videoId: _currentVideoId,
          startAt: currentPosition,
        ),
      ),
    );

    if (newPosition != null && mounted) {
      _mainController!.seekTo(newPosition);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _mainController!.play();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'المكتبة التعليمية',
          style: TextStyle(
            color: Colors.black, 
            fontWeight: FontWeight.bold, 
            fontSize: screenWidth * 0.045 > 18 ? 18 : screenWidth * 0.045, 
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade300, height: 1.0),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(screenWidth * 0.04), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SearchBarWidget(),
              const SizedBox(height: 16),
              
              CategoriesListView(onCategoryTap: _onCategorySelected),
              const SizedBox(height: 20),
              
              Text(
                'فيديو مميز',
                style: TextStyle(
                  fontSize: screenWidth * 0.05 > 18 ? 18 : screenWidth * 0.05, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),

              // هنا قمنا بعزل تأثير الأنيميشن الخاص بالظل ليعمل بمفرده دون التأثير على مشغل الفيديو
              ValueListenableBuilder<double>(
                valueListenable: _scrollOffsetNotifier,
                builder: (context, offset, child) {
                  double blurRadius = 10.0 + (offset < 0 ? offset.abs() * 0.4 : 0);
                  double shadowOffset = 4.0 + (offset < 0 ? offset.abs() * 0.3 : 0);
                  double shadowOpacity = 0.05 + (offset < 0 ? (offset.abs() * 0.002).clamp(0.0, 0.15) : 0);

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    curve: Curves.easeOut,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(shadowOpacity),
                          blurRadius: blurRadius,
                          spreadRadius: offset < 0 ? offset.abs() * 0.1 : 0,
                          offset: Offset(0, shadowOffset),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                // مررنا المشغل كـ child ثابت لكي لا يتم حذفه وإعادة بنائه أثناء حركة التمرير
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _mainController != null 
                        ? YoutubePlayer(
                            key: ValueKey(_currentVideoId), 
                            controller: _mainController!,
                            showVideoProgressIndicator: true,
                            progressIndicatorColor: Colors.red,
                            bottomActions: [
                              CurrentPosition(),
                              ProgressBar(isExpanded: true, colors: const ProgressBarColors(playedColor: Colors.red)),
                              RemainingDuration(),
                              IconButton(
                                icon: const Icon(Icons.fullscreen, color: Colors.white),
                                onPressed: _openCustomFullScreen,
                              ),
                            ],
                          )
                        : const Center(child: CircularProgressIndicator(color: Colors.red)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'أحدث الدروس',
                    style: TextStyle(
                      fontSize: screenWidth * 0.05 > 18 ? 18 : screenWidth * 0.05, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AllLessonsPage(categoryName: _currentCategoryName),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: Text(
                      'عرض الكل', 
                      style: TextStyle(
                        color: Colors.red, 
                        fontSize: screenWidth * 0.038 > 14 ? 14 : screenWidth * 0.038,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              LatestLessonsList(onLessonTap: _onLessonSelected),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mainController?.dispose();
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose(); // تنظيف الـ Notifier لمنع تسريب الذاكرة
    super.dispose();
  }
}

// ==========================================
// 3. صفحة عرض جميع المقاطع للقسم 
// ==========================================
class AllLessonsPage extends StatelessWidget {
  final String categoryName;

  const AllLessonsPage({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    final List<Map<String, String>> filteredLessons = categoryName == 'الكل'
        ? allAvailableLessons
        : allAvailableLessons.where((lesson) => lesson['category'] == categoryName).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'جميع الدروس: $categoryName',
          style: TextStyle(
            color: Colors.black, 
            fontWeight: FontWeight.bold, 
            fontSize: screenWidth * 0.045 > 18 ? 18 : screenWidth * 0.045, 
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade300, height: 1.0),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: filteredLessons.isEmpty
            ? Center(
                child: Text(
                  'لا توجد مقاطع متاحة في هذا القسم حالياً',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              )
            : ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(screenWidth * 0.04),
                itemCount: filteredLessons.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return LessonCardWidget(
                    lesson: filteredLessons[index],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomFullScreenPlayer(
                            videoId: filteredLessons[index]['videoId']!,
                            startAt: Duration.zero,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

// ==========================================
// 4. كارد الدرس المتكرر 
// ==========================================
class LessonCardWidget extends StatelessWidget {
  final Map<String, String> lesson;
  final VoidCallback onTap;

  const LessonCardWidget({super.key, required this.lesson, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lesson['title']!,
                      style: TextStyle(
                        fontSize: screenWidth * 0.038 > 14 ? 14 : screenWidth * 0.038, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.black,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lesson['category']!, 
                      style: TextStyle(fontSize: screenWidth * 0.032 > 12 ? 12 : screenWidth * 0.032, color: Colors.grey.shade600)
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          lesson['level']!, 
                          style: TextStyle(fontSize: screenWidth * 0.03 > 11 ? 11 : screenWidth * 0.03, color: Colors.blue, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.circle, size: 4, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          lesson['views']!, 
                          style: TextStyle(fontSize: screenWidth * 0.03 > 11 ? 11 : screenWidth * 0.03, color: Colors.grey.shade600)
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                double imgWidth = screenWidth * 0.28 > 110 ? 110 : screenWidth * 0.28;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(lesson['image']!, width: imgWidth, height: imgWidth * 0.68, fit: BoxFit.cover),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          lesson['duration']!, 
                          style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.028 > 10 ? 10 : screenWidth * 0.028)
                        ),
                      ),
                    )
                  ],
                );
              }
            ),
          ],
        ),
      ),
    );
  }
}

// --- صفحة الفل سكرين المستقلة ---
class CustomFullScreenPlayer extends StatefulWidget {
  final String videoId;
  final Duration startAt;

  const CustomFullScreenPlayer({
    super.key,
    required this.videoId,
    required this.startAt,
  });

  @override
  State<CustomFullScreenPlayer> createState() => _CustomFullScreenPlayerState();
}

class _CustomFullScreenPlayerState extends State<CustomFullScreenPlayer> {
  late YoutubePlayerController _fullscreenController;

  @override
  void initState() {
    super.initState();
    _fullscreenController = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        startAt: widget.startAt.inSeconds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_fullscreenController.value.position),
        ),
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: YoutubePlayer(
            controller: _fullscreenController,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.red,
            bottomActions: [
              CurrentPosition(),
              ProgressBar(isExpanded: true, colors: const ProgressBarColors(playedColor: Colors.red)),
              RemainingDuration(),
              IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(_fullscreenController.value.position),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullscreenController.dispose();
    super.dispose();
  }
}

// --- شريط البحث ---
class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({super.key});
  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    return TextField(
      textAlign: TextAlign.right,
      style: TextStyle(fontSize: screenWidth * 0.038 > 14 ? 14 : screenWidth * 0.038),
      decoration: InputDecoration(
        hintText: 'ابحث عن دروس تعليمية...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: screenWidth * 0.035 > 13 ? 13 : screenWidth * 0.035),
        prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        filled: true,
        fillColor: const Color(0xFFFFF5F5),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade100, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),
      ),
    );
  }
}

// --- أزرار التصنيفات التفاعلية ---
class CategoriesListView extends StatefulWidget {
  final Function(String) onCategoryTap;

  const CategoriesListView({super.key, required this.onCategoryTap});
  
  @override
  State<CategoriesListView> createState() => _CategoriesListViewState();
}

class _CategoriesListViewState extends State<CategoriesListView> {
  int selectedIndex = 0;
  final List<String> categories = [
    'الكل', 
    'الجروح والنزيف', 
    'الكسور والالتواءات', 
    'الحروق', 
    'التسمم واللدغات', 
    'إسعافات الأطفال'
  ];

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    
    double fontSize = screenWidth * 0.032;
    if (fontSize > 12) fontSize = 12;
    if (fontSize < 11) fontSize = 11;

    return SizedBox(
      height: 32, 
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          bool isSelected = selectedIndex == index;
          return Padding(
            padding: const EdgeInsets.only(left: 6), 
            child: InkWell(
              onTap: () {
                setState(() => selectedIndex = index);
                widget.onCategoryTap(categories[index]); 
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE52427) : const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.red.shade100,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    categories[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: fontSize, 
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- قائمة الدروس المصغرة ---
class LatestLessonsList extends StatelessWidget {
  final Function(String) onLessonTap; 

  const LatestLessonsList({super.key, required this.onLessonTap});
  
  @override
  Widget build(BuildContext context) {
    final latestItems = allAvailableLessons.take(3).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: latestItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return LessonCardWidget(
          lesson: latestItems[index],
          onTap: () => onLessonTap(latestItems[index]['videoId']!),
        );
      },
    );
  }
}