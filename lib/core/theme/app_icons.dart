/// Design system icon tokens for Life OS.
///
/// Centralized icon references ensure consistency
/// and make future icon changes trivial.
library;

import 'package:flutter/material.dart';

abstract final class AppIcons {
  AppIcons._();

  // --- Navigation ---

  /// Home tab icon.
  static const IconData home = Icons.home_rounded;

  /// Home tab filled icon.
  static const IconData homeFilled = Icons.home_rounded;

  /// Timeline tab icon.
  static const IconData timeline = Icons.timeline_rounded;

  /// Life tab icon.
  static const IconData life = Icons.favorite_rounded;

  /// Life tab filled icon.
  static const IconData lifeFilled = Icons.favorite_rounded;

  /// Search tab icon.
  static const IconData search = Icons.search_rounded;

  /// Settings tab icon.
  static const IconData settings = Icons.settings_rounded;

  /// Settings tab filled icon.
  static const IconData settingsFilled = Icons.settings_rounded;

  // --- Actions ---

  /// Add / create action.
  static const IconData add = Icons.add_rounded;

  /// Edit action.
  static const IconData edit = Icons.edit_rounded;

  /// Delete action.
  static const IconData delete = Icons.delete_outline_rounded;

  /// Close / dismiss action.
  static const IconData close = Icons.close_rounded;

  /// Back navigation.
  static const IconData back = Icons.arrow_back_ios_new_rounded;

  /// Forward navigation.
  static const IconData forward = Icons.arrow_forward_ios_rounded;

  /// More options (overflow menu).
  static const IconData more = Icons.more_horiz_rounded;

  /// Check / confirm.
  static const IconData check = Icons.check_rounded;

  /// Share action.
  static const IconData share = Icons.ios_share_rounded;

  // --- Status ---

  /// Success indicator.
  static const IconData success = Icons.check_circle_outline_rounded;

  /// Error indicator.
  static const IconData error = Icons.error_outline_rounded;

  /// Warning indicator.
  static const IconData warning = Icons.warning_amber_rounded;

  /// Info indicator.
  static const IconData info = Icons.info_outline_rounded;

  // --- Auth ---

  /// Google logo / sign-in.
  static const IconData google = Icons.g_mobiledata_rounded;

  /// Email sign-in.
  static const IconData email = Icons.email_outlined;

  /// Password / lock.
  static const IconData lock = Icons.lock_outline_rounded;

  /// Visibility toggle.
  static const IconData visibility = Icons.visibility_outlined;

  /// Visibility off.
  static const IconData visibilityOff = Icons.visibility_off_outlined;

  // --- User ---

  /// Person / profile.
  static const IconData person = Icons.person_outline_rounded;

  /// Logout.
  static const IconData logout = Icons.logout_rounded;

  /// Notifications.
  static const IconData notifications = Icons.notifications_outlined;
}
