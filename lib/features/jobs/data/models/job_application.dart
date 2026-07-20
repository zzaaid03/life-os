/// Job application data model.
///
/// A tracked job application, populated from AI-derived inbox scans and
/// persisted in the `public.job_applications` table (migration 006).
library;

import 'package:equatable/equatable.dart';

/// A single tracked job application.
class JobApplication extends Equatable {
  /// Creates a [JobApplication].
  const JobApplication({
    required this.id,
    required this.company,
    required this.role,
    this.location,
    required this.status,
    this.summary,
    this.sourceEmailId,
    this.appliedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Parses a [JobApplication] from a `job_applications` row (snake_case).
  factory JobApplication.fromJson(Map<String, dynamic> json) {
    return JobApplication(
      id: json['id'] as String,
      company: json['company'] as String? ?? '',
      role: json['role'] as String? ?? '',
      location: json['location'] as String?,
      status: json['status'] as String? ?? 'applied',
      summary: json['summary'] as String?,
      sourceEmailId: json['source_email_id'] as String?,
      appliedAt: json['applied_at'] != null
          ? DateTime.parse(json['applied_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Row id.
  final String id;

  /// The company the application is with.
  final String company;

  /// The role applied for.
  final String role;

  /// Optional location.
  final String? location;

  /// Status: applied | viewed | interview | rejected | accepted.
  final String status;

  /// One-sentence human summary of the latest outcome.
  final String? summary;

  /// The Gmail message id this record was last derived from, if any.
  final String? sourceEmailId;

  /// When the application was submitted, if known.
  final DateTime? appliedAt;

  /// When the row was created.
  final DateTime createdAt;

  /// When the row was last updated.
  final DateTime updatedAt;

  /// Serializes to a `job_applications` row (snake_case).
  ///
  /// Timestamp columns are intentionally omitted so the database defaults /
  /// triggers manage `created_at` / `updated_at`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company': company,
      'role': role,
      'location': location,
      'status': status,
      'summary': summary,
      'source_email_id': sourceEmailId,
      'applied_at': appliedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    company,
    role,
    location,
    status,
    summary,
    sourceEmailId,
    appliedAt,
    createdAt,
    updatedAt,
  ];
}
