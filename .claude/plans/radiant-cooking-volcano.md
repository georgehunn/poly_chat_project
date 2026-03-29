# Plan: Add "Done" Button to Settings Page

## Context
The SettingsView currently has no way for users to manually dismiss the settings sheet - it uses auto-save on change but there's no explicit dismissal mechanism. This is a UI bug that needs to be fixed.

## Requirements
1. Add a "Done" button that:
   - Saves all pending settings changes
   - Closes/dismisses the settings page

## Approach

### Current Implementation
- SettingsView uses auto-save pattern: onChange/onSubmit triggers saveSettings() immediately
- Settings are saved to UserDefaults only (not secure storage) - this is a known issue
- Settings sheet is presented as `.sheet(isPresented: $showingSettings)` in ContentView

### Implementation Plan

**File: `open_chat/Views/SettingsView.swift`**

1. Add `@Environment(\.presentationMode) var presentationMode` property
2. Add "Done" button in the navigation bar (trailing position)
3. The Done button action:
   - Call `saveSettings()` to ensure all changes are saved
   - Call `presentationMode.wrappedValue.dismiss()` to close the sheet

Code to add (lines ~77-85):
```swift
.navigationBarTitle("Settings")
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button("Done") {
            saveSettings()
            presentationMode.wrappedValue.dismiss()
        }
    }
}
```

## Pros
- **Consistent** with existing pattern (InfoView uses same approach)
- **Minimal code change** (~5 lines)
- **Familiar UX** - "Done" is a standard iOS pattern for closing configuration sheets
- **Safe** - saves before dismiss, no data loss risk

## Cons
- **Redundant save**: Since auto-save already saves on change, this saves twice when closing (not a functional issue, just redundant I/O)
- **No cancel option**: Users expecting to discard changes won't have that option (but auto-save means changes are always live anyway)

## Complexity & Size Estimates
- **Complexity**: Low - simple UI addition following existing patterns
- **Lines changed**: ~5 lines added to SettingsView.swift
- **Files modified**: 1 (SettingsView.swift only)
- **Testing effort**: Low - verify button appears and closes sheet

## Verification
1. Run the app
2. Tap settings gear icon to open settings
3. Verify "Done" button appears in top-right of navigation bar
4. Change a setting (e.g., toggle dark mode)
5. Tap "Done" button
6. Verify sheet closes and setting is saved (check next time app opens)
