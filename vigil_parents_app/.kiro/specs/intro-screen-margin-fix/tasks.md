# Implementation Plan

- [ ] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Title and Body Left Margin Alignment
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the title/body misalignment
  - **Scoped PBT Approach**: For this deterministic UI bug, scope the property to the concrete failing case(s) - verify all onboarding pages show titleWidget at 0px left margin while bodyWidget has 16px left margin
  - Write widget test that renders IntroView and measures the left margin of titleWidget (expects 16px after fix) and bodyWidget (expects 16px)
  - The test should verify that both title and body have matching 16px left margins (from Bug Condition in design)
  - Test assertions should match the Expected Behavior: titleWidget SHALL have 16px left padding matching bodyWidget's 16px left margin
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists with titleWidget at 0px instead of 16px)
  - Document counterexamples found: "titleWidget renders at 0px left margin while bodyWidget renders at 16px left margin, creating visible misalignment"
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3_

- [ ] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Title Element Behavior
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for non-buggy elements:
    - bodyPadding remains `EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0)`
    - Title text style uses fontSize 32 and fontWeight bold
    - Navigation controls (Skip, Done, Next, Back) render at current positions
    - Login and Sign up buttons render at current positions
    - Page transitions and animations work as expected
  - Write widget tests capturing observed behavior patterns from Preservation Requirements:
    - Test 1: Verify bodyPadding configuration remains unchanged
    - Test 2: Verify title TextStyle properties (fontSize: 32, fontWeight: bold)
    - Test 3: Verify titlePadding remains `EdgeInsets.only(bottom: 16)`
    - Test 4: Verify PageDecoration properties remain unchanged
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 3. Fix for intro screen title/body margin alignment

  - [ ] 3.1 Implement the fix
    - Open file: `lib/features/introduction/presentation/view/intro_view.dart`
    - Locate the titleWidget definition within the pages mapping (approximately line 85-94)
    - Wrap the Text widget inside the titleWidget's Align widget with a Padding widget
    - Add padding: `const EdgeInsets.only(left: 16.0)`
    - The Text widget should now be: `Padding(padding: const EdgeInsets.only(left: 16.0), child: Text(...))`
    - Verify the bodyPadding remains unchanged: `EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0)`
    - _Bug_Condition: isBugCondition(input) where input.titleWidget.padding.left = 0 AND input.pageDecoration.bodyPadding.left = 16 AND both widgets have Alignment.centerLeft_
    - _Expected_Behavior: titleWidget SHALL have 16px left padding causing title text to align horizontally with body text at the same 16px left margin (expectedBehavior from design)_
    - _Preservation: bodyPadding, text styles, navigation controls, buttons, animations, and all vertical spacing SHALL remain unchanged (Preservation Requirements from design)_
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4, 3.5_

  - [ ] 3.2 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Title and Body Left Margin Alignment
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed - titleWidget now has 16px left padding matching bodyWidget)
    - _Requirements: 2.1, 2.2, 2.3_

  - [ ] 3.3 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Title Element Behavior
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions - all non-title elements unchanged)
    - Confirm all tests still pass after fix (no regressions in bodyPadding, text styles, navigation, buttons, animations, or layout)

- [ ] 4. Checkpoint - Ensure all tests pass
  - Run all widget tests and verify they pass
  - Manually test the introduction screen on a device or simulator
  - Verify visual alignment: title and body text should start at the same horizontal position (16px from left edge)
  - Verify preservation: all navigation controls, buttons, animations, and styling work as before
  - Document completion and ensure no questions arise
