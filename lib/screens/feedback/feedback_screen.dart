import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../models/journey_feedback.dart';
import '../../providers/providers.dart';

/// Collects feedback about a recommendation: whether it helped, which side the
/// traveller actually preferred, a star rating and an optional comment.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({
    super.key,
    required this.journeyId,
    required this.suggestedSide,
  });

  final String journeyId;
  final SeatSide suggestedSide;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  bool _wasHelpful = true;
  late SeatSide _actualSide = widget.suggestedSide;
  int _rating = 5;
  final _comment = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _submitting = true);

    final feedback = JourneyFeedback(
      id: '',
      userId: user.uid,
      journeyId: widget.journeyId,
      wasHelpful: _wasHelpful,
      actualSide: _actualSide,
      rating: _rating,
      comment: _comment.text.trim(),
      createdAt: DateTime.now(),
    );

    final result = await ref.read(feedbackRepositoryProvider).submit(feedback);
    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Thanks for the feedback!'
              : result.failureOrNull?.message ?? 'Could not send feedback.',
        ),
      ),
    );
    if (result.isSuccess) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Did the recommendation help?',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.thumb_up_outlined),
                label: Text('Helpful'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.thumb_down_outlined),
                label: Text('Not really'),
              ),
            ],
            selected: {_wasHelpful},
            onSelectionChanged: (s) => setState(() => _wasHelpful = s.first),
          ),
          const SizedBox(height: 24),
          Text('Which side was actually best?',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<SeatSide>(
            segments: const [
              ButtonSegment(value: SeatSide.left, label: Text('Left')),
              ButtonSegment(value: SeatSide.right, label: Text('Right')),
              ButtonSegment(value: SeatSide.either, label: Text('Either')),
            ],
            selected: {_actualSide},
            onSelectionChanged: (s) => setState(() => _actualSide = s.first),
          ),
          const SizedBox(height: 24),
          Text('Rate this recommendation', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return IconButton(
                iconSize: 36,
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _comment,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Anything else? (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send feedback'),
          ),
        ],
      ),
    );
  }
}
