import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_form_body.dart';
import '../../../core/widgets/state_views.dart';
import '../data/review_repository.dart';

class ReviewFormScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ReviewFormScreen({super.key, required this.orderId});

  @override
  ConsumerState<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends ConsumerState<ReviewFormScreen> {
  final _feedback = TextEditingController();
  int _rating = 5;
  bool _seeded = false;
  bool _saving = false;

  Future<void> _submit({String? existingReviewId}) async {
    if (_feedback.text.trim().isEmpty) {
      showAppSnackBar(context, 'Please write some feedback.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(reviewRepositoryProvider);
      if (existingReviewId != null) {
        await repo.edit(reviewId: existingReviewId, rating: _rating, feedback: _feedback.text.trim());
      } else {
        await repo.submit(orderId: widget.orderId, rating: _rating, feedback: _feedback.text.trim());
      }
      if (mounted) {
        showAppSnackBar(context, 'Review saved. Thank you!');
        context.pop();
      }
    } on ReviewException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save review.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewAsync = ref.watch(reviewByOrderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Write a Review')),
      body: SafeArea(
        child: ResponsiveFormBody(
        child: reviewAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(reviewByOrderProvider(widget.orderId))),
          data: (existing) {
            if (existing != null && !_seeded) {
              _seeded = true;
              _rating = existing.rating;
              _feedback.text = existing.feedback;
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How was your experience?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 1; i <= 5; i++)
                          IconButton(
                            iconSize: 36,
                            tooltip: 'Rate $i out of 5',
                            onPressed: () => setState(() => _rating = i),
                            icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_border_rounded, color: AppColors.warning),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(controller: _feedback, label: 'Your feedback', maxLines: 5, validator: (v) => Validators.required(v, field: 'Feedback')),
                  const SizedBox(height: 24),
                  PrimaryButton(label: existing != null ? 'Update Review' : 'Submit Review', onPressed: () => _submit(existingReviewId: existing?.id), loading: _saving),
                ],
              ),
            );
          },
        ),
        ),
      ),
    );
  }
}
