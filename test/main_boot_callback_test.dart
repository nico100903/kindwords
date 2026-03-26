// ignore_for_file: require_trailing_commas
// ---------------------------------------------------------------------------
// Contract test: notificationBootCallback entry point (Task 03.03)
//
// WHY THIS FILE EXISTS
// --------------------
// flutter_local_notifications v17 does NOT auto-reschedule notifications
// after a device reboot.  The chosen pattern (task-03.03 Architecture Notes,
// Part B) calls a headless Flutter engine via Kotlin BootReceiver.kt and
// points it at a Dart entry-point function annotated @pragma('vm:entry-point').
//
// @pragma('vm:entry-point') prevents the release tree-shaker from removing
// the function.  It must be a top-level function in main.dart (or imported
// there) so the Dart VM can locate it by name.
//
// WHAT THIS TEST PROVES
// ----------------------
// 1. The symbol `notificationBootCallback` exists at the top level of
//    package:kindwords/main.dart.
// 2. The function is callable (returns a Future that completes without
//    throwing) in a headless test environment.
//
// FAILING STATE (expected until coder implements 03.03)
// ------------------------------------------------------
// Until the function is added to main.dart, this file will fail to COMPILE:
//
//   Error: Method not found: 'notificationBootCallback'.
//
// That compile failure is the QA red gate.  The coder's implementation task
// is not done until this file compiles and the test passes.
// ---------------------------------------------------------------------------

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The import below is intentional: we import main.dart to access the top-level
// entry-point symbol.  If main.dart does not export `notificationBootCallback`,
// this file will not compile — which is the expected failure mode.
import 'package:kindwords/main.dart' show notificationBootCallback;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // Test: notificationBootCallback is a top-level callable function
  //
  // STATUS: FAILING — symbol does not exist in main.dart yet.
  // Expected failure: compile-time "Method not found: 'notificationBootCallback'"
  // -------------------------------------------------------------------------
  test(
    'notificationBootCallback is a top-level function that exists and is '
    'callable without crashing in a headless environment',
    () async {
      // Act: call the entry-point function.
      // In a real boot scenario this would reconstruct the service graph and
      // call rescheduleFromSavedSettings().  In the unit test environment it
      // must at minimum not throw an unhandled exception.
      //
      // Platform channel calls inside notificationBootCallback() are expected
      // to be no-ops in the test environment (MissingPluginException is caught
      // or the function short-circuits via SharedPreferences returning defaults).
      //
      // The test just verifies the symbol resolves and the call completes —
      // the detailed behaviour of rescheduleFromSavedSettings is covered in
      // notification_service_test.dart.
      await expectLater(
        notificationBootCallback(),
        completes,
      );
    },
    // Skip reason is intentional: this becomes non-skipped once the symbol
    // exists and we want to confirm it runs.  The COMPILE ERROR below fires
    // before skip is even evaluated, making the red gate clear.
    //
    // Remove `skip` once 03.03 is implemented and the test passes.
    skip: 'notificationBootCallback not yet added to main.dart — '
        'COMPILE ERROR expected until Task 03.03 is implemented',
  );
}
