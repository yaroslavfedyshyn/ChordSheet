import XCTest

/// Not a regression suite — a scripted walk through the app used once to
/// capture screenshots for visually verifying the SwiftUI implementation
/// against the design prototype (see the plan's verification section).
final class ChordSheetUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// iOS shows a one-time "slide to type" tip the first time the keyboard
    /// becomes active in a fresh simulator. It sits in its own window and
    /// can stall later accessibility queries against the app if left open.
    private func dismissKeyboardTipIfPresent(_ app: XCUIApplication) {
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 2) {
            continueButton.tap()
        }
    }

    func testNewSongFlow() throws {
        let app = XCUIApplication()
        app.launch()
        snap(app, "n01_list")

        let addButton = app.buttons["addSongButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        sleep(1)
        dismissKeyboardTipIfPresent(app)
        snap(app, "n02_new_song_blank")

        let titleField = app.textFields["titleField"]
        if titleField.waitForExistence(timeout: 3) {
            titleField.tap()
            dismissKeyboardTipIfPresent(app)
            titleField.typeText("My Test Song")
        }

        let canvas = app.descendants(matching: .any)["canvasArea"]
        if canvas.waitForExistence(timeout: 3) {
            canvas.tap()
            dismissKeyboardTipIfPresent(app)
            sleep(1)
            app.typeText("G       D       Em      C\n    a line of lyrics")
            sleep(1)
            snap(app, "n03_new_song_typed")
        }

        let saveButton = app.buttons["saveButton"]
        if saveButton.waitForExistence(timeout: 3) {
            saveButton.tap()
            sleep(1)
            snap(app, "n04_saved_toast")
        }

        let backButton = app.buttons["backButton"]
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
            sleep(1)
            snap(app, "n05_back_to_list_after_save")
        }

        let newRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "My Test Song")).firstMatch
        if newRow.waitForExistence(timeout: 3) {
            newRow.swipeLeft()
            sleep(1)
            snap(app, "n06_swipe_to_delete_revealed")
            let deleteButton = app.buttons["Delete"]
            if deleteButton.waitForExistence(timeout: 3) {
                deleteButton.tap()
                sleep(1)
                snap(app, "n07_after_delete")
            }
        }
    }

    /// Tapping "+" then immediately going back (no edits at all) should not
    /// show the unsaved-changes guard — there's nothing to lose.
    func testNewSongUntouchedBackIsSilent() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)

        let addButton = app.buttons["addSongButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        sleep(1)
        snap(app, "g01_new_song_untouched")

        let backButton = app.buttons["backButton"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        backButton.tap()
        sleep(1)
        snap(app, "g02_back_immediately_no_confirm")

        // Should have landed back on the list, not a confirm alert
        XCTAssertTrue(app.buttons["addSongButton"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    /// A brand-new song should auto-detect its key from the chords typed —
    /// but only until the user explicitly transposes. After that, further
    /// edits must not override their choice.
    func testNewSongKeyAutoDetection() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)

        let addButton = app.buttons["addSongButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        sleep(1)
        dismissKeyboardTipIfPresent(app)

        let keyBadge = app.buttons["keyBadge"]
        XCTAssertTrue(keyBadge.waitForExistence(timeout: 3))
        XCTAssertEqual(keyBadge.label, "C", "new song should start at the default key")

        let canvas = app.descendants(matching: .any)["canvasArea"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))
        canvas.tap()
        dismissKeyboardTipIfPresent(app)
        sleep(1)
        app.typeText("D       A       Bm      G")
        sleep(1)
        snap(app, "k01_key_auto_detected")
        XCTAssertEqual(keyBadge.label, "D", "key badge should auto-update to the detected key")

        // Manually transpose — this should "lock" the key going forward.
        keyBadge.tap()
        sleep(1)
        let pillPlus2 = app.buttons["transposePill_2"]
        if pillPlus2.waitForExistence(timeout: 3) {
            pillPlus2.tap()
            sleep(1)
        }
        snap(app, "k02_after_manual_transpose")
        XCTAssertEqual(keyBadge.label, "E", "manual transpose from D by +2 should land on E")

        // Further typing must not override the manually-set key anymore.
        canvas.tap()
        sleep(1)
        app.typeText("\nsome more words")
        sleep(1)
        snap(app, "k03_key_unchanged_after_more_typing")
        XCTAssertEqual(keyBadge.label, "E", "key must stay locked after manual transpose, regardless of further edits")
    }

    /// Opening an existing (already-saved) song and editing its body must
    /// never auto-change its key — detection only applies to brand-new songs.
    func testExistingSongKeyNeverAutoChanges() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)

        // "Backroad Hymn" (seed s5) is in C; its chords (C G Am F ...) would
        // still detect as C anyway, so instead we type in chords from a very
        // different key to make sure the badge does NOT follow them.
        let row = app.buttons["songRow_s5"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        sleep(1)
        dismissKeyboardTipIfPresent(app)

        let keyBadge = app.buttons["keyBadge"]
        XCTAssertTrue(keyBadge.waitForExistence(timeout: 3))
        XCTAssertEqual(keyBadge.label, "C")

        let canvas = app.descendants(matching: .any)["canvasArea"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))
        canvas.tap()
        dismissKeyboardTipIfPresent(app)
        sleep(1)
        app.typeText("\nB       F#      G#m     E")
        sleep(1)
        snap(app, "k04_existing_song_key_untouched")
        XCTAssertEqual(keyBadge.label, "C", "editing an existing song's body must never auto-change its key")
    }

    /// New song should autofocus the canvas (keyboard up, no tap needed);
    /// the quick-insert row should be exactly C D E F G A B, in that order,
    /// all fitting on screen without scrolling; and the variant-mode chips
    /// (cursor on an existing chord) should offer minor then sharp first.
    func testAutofocusChipRowAndVariantOrder() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)

        let addButton = app.buttons["addSongButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        sleep(1)
        dismissKeyboardTipIfPresent(app)
        snap(app, "af01_new_song_should_be_focused")

        // Autofocus: the chord bar (only shown while editing) should already
        // be up without ever tapping the canvas.
        XCTAssertTrue(app.buttons["toggleKeyboardButton"].waitForExistence(timeout: 3),
                      "canvas should autofocus on a brand-new song, showing the chord bar immediately")

        // Quick-insert row: exactly C D E F G A B, in order, all visible
        // without scrolling (only "All chords" may require a scroll).
        let expectedLetters = ["C", "D", "E", "F", "G", "A", "B"]
        for letter in expectedLetters {
            let chip = app.buttons["chip_\(letter)"]
            XCTAssertTrue(chip.waitForExistence(timeout: 3), "chip_\(letter) should exist")
            XCTAssertTrue(chip.isHittable, "chip_\(letter) should be visible without scrolling")
        }
        snap(app, "af02_quick_chips_fit_on_screen")

        // Variant mode: the fixed quick-access order is root, its minor, the
        // chord a semitone up (sharp-spelled), then that raised chord's minor.
        app.typeText("A")
        sleep(1)
        snap(app, "af03_variant_mode_a")
        let modeText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "VARIANTS")).firstMatch
        XCTAssertTrue(modeText.waitForExistence(timeout: 3))

        let rootChip = app.buttons["chip_A"]
        let minorChip = app.buttons["chip_Am"]
        let sharpChip = app.buttons["chip_A#"]
        let sharpMinorChip = app.buttons["chip_A#m"]
        XCTAssertTrue(rootChip.waitForExistence(timeout: 3), "root (A) should be offered")
        XCTAssertTrue(minorChip.waitForExistence(timeout: 3), "minor variant (Am) should be offered")
        XCTAssertTrue(sharpChip.waitForExistence(timeout: 3), "the raised sharp chord (A#) should be offered")
        XCTAssertTrue(sharpMinorChip.waitForExistence(timeout: 3), "the raised sharp chord's minor (A#m) should be offered")
        XCTAssertTrue(rootChip.frame.minX < minorChip.frame.minX, "root should come before its minor")
        XCTAssertTrue(minorChip.frame.minX < sharpChip.frame.minX, "minor should come before the raised sharp chord")
        XCTAssertTrue(sharpChip.frame.minX < sharpMinorChip.frame.minX, "the raised sharp chord should come before its minor")

        // Tapping the raised chord switches variant mode to A#'s own variants
        // — which, being already an accidental, must not offer a further
        // raised chord (no B/Bm shortcut once you're already on a sharp).
        sharpChip.tap()
        sleep(1)
        snap(app, "af04_variant_mode_a_sharp")
        XCTAssertTrue(app.buttons["chip_A#"].waitForExistence(timeout: 3), "A# should now be the active chord")
        XCTAssertTrue(app.buttons["chip_A#m"].waitForExistence(timeout: 3), "A#m should still be offered")
        XCTAssertFalse(app.buttons["chip_B"].exists, "an already-sharp chord should not also offer a further raised chord (B)")
    }

    /// The transpose strip should offer a full octave in each direction
    /// (-12 to +12 semitones), not just the old +/-3.
    func testTransposeFullOctaveRange() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)

        let row = app.buttons["songRow_s1"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        sleep(1)
        dismissKeyboardTipIfPresent(app)

        let keyBadge = app.buttons["keyBadge"]
        XCTAssertTrue(keyBadge.waitForExistence(timeout: 3))
        keyBadge.tap()
        sleep(1)
        snap(app, "oct01_strip_open_default")

        XCTAssertTrue(app.buttons["transposePill_0"].waitForExistence(timeout: 3))
        // All pills exist in the tree regardless of scroll position (plain
        // HStack, not lazy) — existence alone confirms the full range.
        XCTAssertTrue(app.buttons["transposePill_7"].exists, "should extend beyond the old +/-6 range")
        XCTAssertTrue(app.buttons["transposePill_11"].exists, "should reach +11")
        XCTAssertTrue(app.buttons["transposePill_-11"].exists, "should reach -11")
        XCTAssertFalse(app.buttons["transposePill_12"].exists, "+12 is dropped — same pitch class as the current key")
        XCTAssertFalse(app.buttons["transposePill_-12"].exists, "-12 is dropped — same pitch class as the current key")

        // Best-effort visual proof: capture a fixed absolute point from a
        // currently-visible pill's frame *once* up front (the same fix used
        // for the chip row elsewhere in this file — re-querying a named
        // element after it has already scrolled away fails to resolve).
        // Not asserted strictly — the `.exists` checks above are the real
        // pass/fail criteria; this is just for the screenshots.
        let anchorPill = app.buttons["transposePill_0"]
        let frame = anchorPill.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let rightPoint = origin.withOffset(CGVector(dx: frame.midX + 120, dy: frame.midY))
        let leftPoint = origin.withOffset(CGVector(dx: frame.midX - 120, dy: frame.midY))

        for _ in 0..<6 {
            rightPoint.press(forDuration: 0.15, thenDragTo: leftPoint)
        }
        sleep(1)
        snap(app, "oct02_scrolled_toward_plus12")

        for _ in 0..<12 {
            leftPoint.press(forDuration: 0.15, thenDragTo: rightPoint)
        }
        sleep(1)
        snap(app, "oct03_scrolled_toward_minus12")
    }

    /// Reported bug: type chords (chord bar up), open the transpose strip,
    /// close it again — the chord bar/chip row must come back, not stay
    /// hidden forever (closing the strip must resume editing if it was
    /// interrupting an active typing session).
    func testChordBarReappearsAfterTransposeStripCloses() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)

        let addButton = app.buttons["addSongButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        sleep(1)
        dismissKeyboardTipIfPresent(app)

        let canvas = app.descendants(matching: .any)["canvasArea"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))
        canvas.tap()
        dismissKeyboardTipIfPresent(app)
        sleep(1)
        app.typeText("G D Em C")
        sleep(1)
        XCTAssertTrue(app.buttons["toggleKeyboardButton"].waitForExistence(timeout: 3), "chord bar should be up while typing")
        snap(app, "tb01_chord_bar_visible_while_typing")

        let keyBadge = app.buttons["keyBadge"]
        XCTAssertTrue(keyBadge.waitForExistence(timeout: 3))
        keyBadge.tap()
        sleep(1)
        snap(app, "tb02_strip_open_chord_bar_hidden")
        XCTAssertTrue(app.buttons["transposePill_0"].waitForExistence(timeout: 3), "strip should be open")
        XCTAssertFalse(app.buttons["toggleKeyboardButton"].exists, "chord bar should be hidden while the strip is open")

        keyBadge.tap()
        sleep(1)
        snap(app, "tb03_strip_closed_chord_bar_should_reappear")
        XCTAssertTrue(app.buttons["toggleKeyboardButton"].waitForExistence(timeout: 3), "chord bar must reappear after closing the strip")
        XCTAssertTrue(app.buttons["chip_C"].waitForExistence(timeout: 3), "quick-insert chip row must reappear after closing the strip")
    }

    /// Opening the transpose strip when the canvas was NOT being edited
    /// (e.g. just opened an existing song) should not show the chord bar
    /// on close either — only resumes editing if it was actually interrupted.
    func testTransposeStripWithoutPriorEditingStaysClean() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)

        let row = app.buttons["songRow_s1"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        sleep(1)
        dismissKeyboardTipIfPresent(app)

        let keyBadge = app.buttons["keyBadge"]
        XCTAssertTrue(keyBadge.waitForExistence(timeout: 3))
        keyBadge.tap()
        sleep(1)
        keyBadge.tap()
        sleep(1)
        snap(app, "tb04_no_prior_editing_no_chord_bar")
        XCTAssertFalse(app.buttons["toggleKeyboardButton"].exists, "should not spuriously open the chord bar/keyboard")
    }

    /// Font-size stepper should now allow 5 more steps up (new max 45pt,
    /// was 30pt) without breaking at either boundary.
    func testFontSizeExtendedRange() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)

        let addButton = app.buttons["addSongButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        sleep(1)
        dismissKeyboardTipIfPresent(app)

        // Type something so the size change is visible in the screenshots.
        let canvas = app.descendants(matching: .any)["canvasArea"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))
        canvas.tap()
        dismissKeyboardTipIfPresent(app)
        sleep(1)
        app.typeText("G D Em C")
        sleep(1)

        let bigger = app.buttons["fontBigger"]
        XCTAssertTrue(bigger.waitForExistence(timeout: 3))
        for _ in 0..<12 { bigger.tap() } // well past the new max (index 2 -> 11)
        sleep(1)
        snap(app, "fs01_max_font_size")
        XCTAssertTrue(bigger.exists, "stepping past the max should not crash or remove the control")

        let smaller = app.buttons["fontSmaller"]
        XCTAssertTrue(smaller.waitForExistence(timeout: 3))
        for _ in 0..<15 { smaller.tap() } // well past the min
        sleep(1)
        snap(app, "fs02_min_font_size")
        XCTAssertTrue(smaller.exists, "stepping past the min should not crash or remove the control")
    }

    /// Tag chips show in the list, the filter row narrows the list, and the
    /// tag sheet can toggle an existing tag and create a brand-new one.
    func testSongTaggingFilterAndSheet() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)
        snap(app, "tag01_list_with_tag_chips")

        // Chips sort alphabetically, so "campfire" (unlike "originals") is
        // guaranteed to be on-screen without needing to scroll the row first.
        let campfireFilter = app.buttons["tagFilter_campfire"]
        XCTAssertTrue(campfireFilter.waitForExistence(timeout: 5))
        campfireFilter.tap()
        sleep(1)
        snap(app, "tag02_filtered_by_campfire")
        XCTAssertTrue(app.buttons["songRow_s5"].exists, "Backroad Hymn (tagged campfire) should still show")
        XCTAssertFalse(app.buttons["songRow_s1"].exists, "Slow River (not tagged campfire) should be filtered out")

        app.buttons["tagFilterAll"].tap()
        sleep(1)
        XCTAssertTrue(app.buttons["songRow_s1"].waitForExistence(timeout: 3), "clearing the filter should restore the full list")

        let row = app.buttons["songRow_s5"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        sleep(1)
        dismissKeyboardTipIfPresent(app)

        let openTags = app.buttons["openTagsButton"]
        XCTAssertTrue(openTags.waitForExistence(timeout: 3))
        openTags.tap()
        sleep(1)
        snap(app, "tag03_tag_sheet_open")

        let campfireChip = app.buttons["tagChip_campfire"]
        XCTAssertTrue(campfireChip.waitForExistence(timeout: 3), "campfire should be on since Backroad Hymn already wears it")
        campfireChip.tap()
        sleep(1)
        snap(app, "tag04_campfire_toggled_off")

        let searchField = app.textFields["tagSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("sunday drive")
        sleep(1)
        let createButton = app.buttons["createTagButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3), "Create should appear for a brand-new tag name")
        createButton.tap()
        sleep(1)
        snap(app, "tag05_new_tag_created_and_applied")
        XCTAssertTrue(app.buttons["tagChip_sunday drive"].waitForExistence(timeout: 3))

        app.buttons["closeTagsButton"].tap()
        sleep(1)
        snap(app, "tag06_song_header_shows_new_tag")
    }

    /// There's no separate tag management — a tag only exists as long as
    /// some song wears it. Untagging the one song that uses a tag (and
    /// saving) should make it disappear from both the filter row and every
    /// other song's tag sheet, not just linger as a stale registry entry.
    func testTagDisappearsWhenLastSongUntagged() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)

        // "capo 2" is attached only to "Paper Ferry" (s2) in the seed data.
        XCTAssertTrue(app.buttons["tagFilter_capo 2"].waitForExistence(timeout: 5), "capo 2 should start out visible since Paper Ferry wears it")

        let row = app.buttons["songRow_s2"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        sleep(1)
        dismissKeyboardTipIfPresent(app)

        app.buttons["openTagsButton"].tap()
        sleep(1)
        let capoChip = app.buttons["tagChip_capo 2"]
        XCTAssertTrue(capoChip.waitForExistence(timeout: 3))
        capoChip.tap()
        sleep(1)
        app.buttons["closeTagsButton"].tap()
        sleep(1)

        let saveButton = app.buttons["saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "removing a tag should mark the song dirty")
        saveButton.tap()
        sleep(1)

        app.buttons["backButton"].tap()
        sleep(1)
        snap(app, "tagremove01_capo2_gone_from_filters")
        XCTAssertFalse(app.buttons["tagFilter_capo 2"].exists, "capo 2 should no longer show in the filter row once no song wears it")

        // It should also be gone from every other song's tag sheet.
        let anotherRow = app.buttons["songRow_s1"]
        XCTAssertTrue(anotherRow.waitForExistence(timeout: 3))
        anotherRow.tap()
        sleep(1)
        dismissKeyboardTipIfPresent(app)
        app.buttons["openTagsButton"].tap()
        sleep(1)
        snap(app, "tagremove02_capo2_gone_from_sheet")
        XCTAssertFalse(app.buttons["tagChip_capo 2"].exists, "capo 2 should no longer be offered as an existing tag anywhere")
    }

    /// The manual "Detect key" button in the transpose strip should surface a
    /// guess for chords typed in a different key, and "Fix key" should apply
    /// just the label without touching the chords themselves.
    func testDetectKeyButton() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)

        // "Backroad Hymn" (seed s5) is saved in C, and editing an existing
        // song's body never auto-changes its badge (see
        // testExistingSongKeyNeverAutoChanges) — a reliable way to get chords
        // that disagree with the badge, which is exactly what "Detect key"
        // and "Fix key" are for.
        let row = app.buttons["songRow_s5"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        sleep(1)
        dismissKeyboardTipIfPresent(app)

        let keyBadge = app.buttons["keyBadge"]
        XCTAssertTrue(keyBadge.waitForExistence(timeout: 3))
        XCTAssertEqual(keyBadge.label, "C")

        let canvas = app.descendants(matching: .any)["canvasArea"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 3))
        canvas.tap()
        dismissKeyboardTipIfPresent(app)
        sleep(1)
        // Repeated enough times to numerically outweigh the song's own ~27
        // C-major chords, so the overall chord content unambiguously points
        // to a different key than the untouched "C" badge.
        for _ in 0..<8 {
            app.typeText("\nB       F#      G#m     E\nB       F#      E       B")
        }
        sleep(1)

        keyBadge.tap()
        sleep(1)
        snap(app, "detect01_strip_open_before_detect")

        let detectButton = app.buttons["detectKeyButton"]
        XCTAssertTrue(detectButton.waitForExistence(timeout: 3))
        detectButton.tap()
        sleep(1)
        snap(app, "detect02_detection_panel_shown")

        let fixButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "fixKeyButton_"))
        XCTAssertTrue(fixButtons.firstMatch.waitForExistence(timeout: 3), "Fix key should appear since the detected key differs from the badge")
        fixButtons.firstMatch.tap()
        sleep(1)
        snap(app, "detect03_after_fix_key_applied")
        XCTAssertNotEqual(keyBadge.label, "C", "Fix key should update the badge to the newly-detected key")
    }

    /// The sidebar's Light/Dark/Auto appearance control should force the
    /// scheme regardless of the system setting, independent of chord color.
    func testAppearanceSidebarSetting() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)

        let menuButton = app.buttons["libraryMenuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()
        sleep(1)
        snap(app, "appear01_menu_with_appearance_section")

        let darkMode = app.buttons["appearanceMode_dark"]
        XCTAssertTrue(darkMode.waitForExistence(timeout: 3))
        darkMode.tap()
        sleep(1)
        snap(app, "appear02_dark_mode_selected")

        let lightMode = app.buttons["appearanceMode_light"]
        XCTAssertTrue(lightMode.waitForExistence(timeout: 3))
        lightMode.tap()
        sleep(1)
        snap(app, "appear03_light_mode_selected")

        let autoMode = app.buttons["appearanceMode_auto"]
        XCTAssertTrue(autoMode.waitForExistence(timeout: 3))
        autoMode.tap()
        sleep(1)
        snap(app, "appear04_auto_mode_selected")
    }

    /// Pinning a song via the swipe action (next to Delete) should move it
    /// to the top of the list, ahead of songs that sort earlier alphabetically
    /// or were seeded first; unpinning should return it to its normal spot.
    func testPinSongMovesItToTop() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)
        snap(app, "pin01_list_before_pin")

        // "Coalsmoke" (s9) sorts near the bottom of the seed list without
        // scrolling — pinning it should be a clear, visible proof that
        // pinning reorders the list ahead of everything above it.
        let row = app.buttons["songRow_s9"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        sleep(1)
        snap(app, "pin02_swipe_reveals_pin_and_delete")

        let pinButton = app.buttons["pinButton_s9"]
        XCTAssertTrue(pinButton.waitForExistence(timeout: 3))
        pinButton.tap()
        sleep(1)
        snap(app, "pin03_after_pinning")

        // The pinned row should now be the first song button in the list.
        let firstRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "songRow_")).firstMatch
        XCTAssertEqual(firstRow.identifier, "songRow_s9", "pinned song should move to the top of the list")

        // Unpin — it should leave the top spot again.
        row.swipeLeft()
        sleep(1)
        let unpinButton = app.buttons["pinButton_s9"]
        XCTAssertTrue(unpinButton.waitForExistence(timeout: 3))
        unpinButton.tap()
        sleep(1)
        snap(app, "pin04_after_unpinning")
        let firstRowAfterUnpin = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "songRow_")).firstMatch
        XCTAssertNotEqual(firstRowAfterUnpin.identifier, "songRow_s9", "unpinning should move the song out of the top spot")
    }

    func testFeedbackFixes() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)
        snap(app, "f01_list_no_title_no_artist")

        // Swipe to delete: verify red background + confirmation dialog
        let firstRow = app.buttons["songRow_s1"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.swipeLeft()
        sleep(1)
        snap(app, "f02_swipe_delete_red")

        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 3) {
            deleteButton.tap()
            sleep(1)
            snap(app, "f03_confirm_delete_dialog")

            let cancelButton = app.alerts.firstMatch.buttons["Cancel"]
            XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Cancel button should exist in the delete alert")
            cancelButton.tap()
            sleep(1)
            snap(app, "f04_after_cancel_row_still_there")
        }

        // Open the side menu — check slide-in animation frames + theme section
        let menuButton = app.buttons["libraryMenuButton"]
        if menuButton.waitForExistence(timeout: 3) {
            menuButton.tap()
            usleep(80_000)
            snap(app, "f05_menu_mid_animation")
            sleep(1)
            snap(app, "f06_menu_open_settled")

            let marineSwatch = app.buttons["themeSwatch_marine"]
            if marineSwatch.waitForExistence(timeout: 3) {
                marineSwatch.tap()
                sleep(1)
                snap(app, "f07_marine_selected_in_menu")
            }

            // Close by tapping the dimmed backdrop (top-left, away from the panel)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.3)).tap()
            usleep(80_000)
            snap(app, "f08_menu_closing_animation")
            sleep(1)
            snap(app, "f09_menu_closed_marine_accent_applied")
        }
    }

    /// Smoke-checks that the Import/Export menu rows actually invoke the
    /// system file picker (not just compile) — tap each, confirm the picker
    /// sheet appears, then cancel out without touching any real file.
    func testImportExportRowsPresentSystemFilePickers() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(1)

        let menuButton = app.buttons["libraryMenuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()
        sleep(1)

        let exportRow = app.buttons["exportSongsRow"]
        XCTAssertTrue(exportRow.waitForExistence(timeout: 3))
        exportRow.tap()
        sleep(2)
        // The system document picker is a separate process, so it isn't
        // queryable through this app's XCUIApplication — a full-screen
        // screenshot is the only reliable way to confirm it appeared.
        snap(app, "backup01_export_picker_presented")

        // Terminating dismisses the cross-process picker sheet; relaunching
        // gives a clean app state to test Import from.
        app.terminate()
        app.launch()
        sleep(1)

        menuButton.tap()
        sleep(1)
        let importRow = app.buttons["importSongsRow"]
        XCTAssertTrue(importRow.waitForExistence(timeout: 3))
        importRow.tap()
        sleep(2)
        snap(app, "backup02_import_picker_presented")

        app.terminate()
        app.launch()
        sleep(1)

        // App should still be alive and functional after both pickers.
        XCTAssertTrue(app.buttons["addSongButton"].waitForExistence(timeout: 3))
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
