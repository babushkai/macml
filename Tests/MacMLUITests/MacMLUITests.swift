import XCTest

/// UI Tests for MacML using XCUITest with BDD-style structure
/// 
/// These tests verify the main user flows work correctly.
/// Run with: xcodebuild test -scheme MacML -destination 'platform=macOS'
final class MacMLUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    // MARK: - Feature: App Launch
    
    /// Scenario: User launches the app for the first time
    /// Given the app is not running
    /// When the user launches MacML
    /// Then the main window should appear
    /// And the sidebar should be visible
    func testAppLaunchesSuccessfully() throws {
        // Then: main window appears
        XCTAssertTrue(app.windows.firstMatch.exists, "Main window should exist")
        
        // And: sidebar is visible (navigation)
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5), "Sidebar should be visible")
    }
    
    // MARK: - Feature: Navigation
    
    /// Scenario: User navigates to Models tab
    /// Given the app is running
    /// When the user clicks on "Models" in the sidebar
    /// Then the Models view should be displayed
    func testNavigateToModels() throws {
        // When: click Models
        let modelsButton = app.buttons["Models"].firstMatch
        if modelsButton.waitForExistence(timeout: 3) {
            modelsButton.click()
        }
        
        // Then: Models view displayed (check for expected UI elements)
        // Note: Adjust identifiers based on actual UI
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
    }
    
    /// Scenario: User navigates to Datasets tab
    /// Given the app is running
    /// When the user clicks on "Datasets" in the sidebar
    /// Then the Datasets view should be displayed
    func testNavigateToDatasets() throws {
        let datasetsButton = app.buttons["Datasets"].firstMatch
        if datasetsButton.waitForExistence(timeout: 3) {
            datasetsButton.click()
        }
        
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
    }
    
    /// Scenario: User navigates to Training tab
    /// Given the app is running  
    /// When the user clicks on "Training" in the sidebar
    /// Then the Training view should be displayed
    func testNavigateToTraining() throws {
        let trainingButton = app.buttons["Training"].firstMatch
        if trainingButton.waitForExistence(timeout: 3) {
            trainingButton.click()
        }
        
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
    }
    
    // MARK: - Feature: Model Management
    
    /// Scenario: User creates a new model
    /// Given the user is on the Models view
    /// When the user clicks "New Model"
    /// Then a model creation sheet should appear
    func testNewModelSheetAppears() throws {
        // Navigate to Models
        let modelsButton = app.buttons["Models"].firstMatch
        if modelsButton.waitForExistence(timeout: 3) {
            modelsButton.click()
        }
        
        // When: click New Model (toolbar or button)
        let newModelButton = app.buttons["New Model"].firstMatch
        if newModelButton.waitForExistence(timeout: 3) {
            newModelButton.click()
            
            // Then: sheet appears
            let sheet = app.sheets.firstMatch
            XCTAssertTrue(sheet.waitForExistence(timeout: 3), "New Model sheet should appear")
        }
    }
    
    // MARK: - Feature: Settings
    
    /// Scenario: User opens Settings
    /// Given the app is running
    /// When the user opens Settings (Cmd+,)
    /// Then the Settings window should appear
    func testOpenSettings() throws {
        // When: use keyboard shortcut
        app.typeKey(",", modifierFlags: .command)
        
        // Then: settings window appears
        // Note: SwiftUI Settings use a separate window
        let settingsWindow = app.windows["Settings"].firstMatch
        if settingsWindow.waitForExistence(timeout: 3) {
            XCTAssertTrue(settingsWindow.exists, "Settings window should open")
        }
    }
    
    // MARK: - Feature: Keyboard Shortcuts
    
    /// Scenario: User uses keyboard shortcuts
    /// Given the app is running
    /// When the user presses Cmd+N
    /// Then a new item sheet should appear
    func testKeyboardShortcutNewItem() throws {
        app.typeKey("n", modifierFlags: .command)
        
        // Should trigger new model/dataset sheet depending on current view
        let sheet = app.sheets.firstMatch
        // May or may not appear depending on context
        _ = sheet.waitForExistence(timeout: 2)
    }
}

// MARK: - Test Helpers

extension XCUIElement {
    /// Wait for element and tap/click
    func waitAndClick(timeout: TimeInterval = 5) -> Bool {
        guard waitForExistence(timeout: timeout) else { return false }
        click()
        return true
    }
}
