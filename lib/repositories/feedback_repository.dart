import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/failure.dart';
import '../core/result.dart';
import '../models/journey_feedback.dart';

/// Stores user feedback about recommendations in the `feedback` collection.
class FeedbackRepository {
  FeedbackRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.feedbackCollection);

  Future<Result<void>> submit(JourneyFeedback feedback) async {
    try {
      await _collection.add(feedback.toJson());
      return const Success(null);
    } catch (e) {
      return ResultFailure(DatabaseFailure('Could not send feedback: $e'));
    }
  }

  Stream<List<JourneyFeedback>> watchFeedback(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JourneyFeedback.fromJson(doc.id, doc.data()))
            .toList());
  }
}
