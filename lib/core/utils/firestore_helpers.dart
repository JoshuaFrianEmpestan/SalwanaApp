import 'package:cloud_firestore/cloud_firestore.dart';

/// Safe Timestamp <-> DateTime conversion. Firestore returns [Timestamp]
/// objects, but freshly-written local data (before the round trip) may
/// still hold a raw [DateTime], and a field may simply be absent.
DateTime? tsToDate(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

DateTime tsToDateOrNow(Object? value) => tsToDate(value) ?? DateTime.now();

num asNum(Object? value, [num fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? fallback;
}

double asDouble(Object? value, [double fallback = 0]) => asNum(value, fallback).toDouble();

int asInt(Object? value, [int fallback = 0]) => asNum(value, fallback).toInt();
