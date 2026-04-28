import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quizzly/core/theme/app_colors.dart';
import 'package:quizzly/features/quiz/data/models/quiz_models.dart';
import 'package:quizzly/features/quiz/presentation/widgets/quiz_widgets.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول لعرض المفضلة', style: GoogleFonts.cairo())),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'الأسئلة المفضلة',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_user.uid)
            .collection('favorites')
            .orderBy('savedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ أثناء جلب البيانات', style: GoogleFonts.cairo()));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'قائمة المفضلة فارغة حالياً',
                    style: GoogleFonts.cairo(fontSize: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final questionMap = data['questionData'] as Map<String, dynamic>;
              final question = QuizQuestion.fromMap(questionMap, data['questionId']);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: QuestionCard(
                  question: question,
                  selectedOptionId: null,
                  answerState: AnswerState.unanswered,
                  showCorrect: true, // Favorites usually show answers for review
                  isFavorite: true,
                  onFavoriteToggle: () {
                    // Remove from favorites
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(_user.uid)
                        .collection('favorites')
                        .doc(data['questionId'])
                        .delete();
                  },
                  onOptionSelected: (_) {},
                ),
              );
            },
          );
        },
      ),
    );
  }
}
