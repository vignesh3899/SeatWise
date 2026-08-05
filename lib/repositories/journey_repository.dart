import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/failure.dart';
import '../core/result.dart';
import '../models/journey.dart';

/// Persists and reads the user's saved journeys from the `journeys` collection.
class JourneyRepository {
  JourneyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.journeysCollection);

  /// Live stream of the user's journeys, most recent first.
  Stream<List<Journey>> watchJourneys(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Journey.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<Result<Journey>> save(Journey journey) async {
    try {
      final ref = await _collection.add(journey.toJson());
      return Success(Journey.fromJson(ref.id, journey.toJson()));
    } catch (e) {
      return ResultFailure(DatabaseFailure('Could not save journey: $e'));
    }
  }

  Future<Result<void>> delete(String journeyId) async {
    try {
      await _collection.doc(journeyId).delete();
      return const Success(null);
    } catch (e) {
      return ResultFailure(DatabaseFailure('Could not delete journey: $e'));
    }
  }
}
