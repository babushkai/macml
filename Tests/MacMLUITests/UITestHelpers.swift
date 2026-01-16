import XCTest

// MARK: - BDD-Style Test Helpers

/// Protocol for BDD-style test scenarios
protocol UITestScenario {
    func given(_ description: String, action: () throws -> Void) rethrows
    func when(_ description: String, action: () throws -> Void) rethrows
    func then(_ description: String, action: () throws -> Void) rethrows
    func and(_ description: String, action: () throws -> Void) rethrows
}

extension XCTestCase: UITestScenario {
    func given(_ description: String, action: () throws -> Void) rethrows {
        try action()
    }
    
    func when(_ description: String, action: () throws -> Void) rethrows {
        try action()
    }
    
    func then(_ description: String, action: () throws -> Void) rethrows {
        try action()
    }
    
    func and(_ description: String, action: () throws -> Void) rethrows {
        try action()
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    /// Wait for element to exist and be hittable
    func waitForHittable(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    /// Clear text field and type new text
    func clearAndType(_ text: String) {
        guard waitForExistence(timeout: 3) else { return }
        click()
        
        // Select all and delete
        typeKey("a", modifierFlags: .command)
        typeKey(.delete, modifierFlags: [])
        
        // Type new text
        typeText(text)
    }
}

// MARK: - App Navigation Helpers

extension XCUIApplication {
    /// Navigate to a sidebar item by name
    func navigateTo(_ item: String) -> Bool {
        let button = buttons[item].firstMatch
        if button.waitForExistence(timeout: 3) {
            button.click()
            return true
        }
        
        // Try outline/list items
        let outlineItem = outlines.buttons[item].firstMatch
        if outlineItem.waitForExistence(timeout: 3) {
            outlineItem.click()
            return true
        }
        
        return false
    }
    
    /// Check if a view is currently displayed
    func isViewDisplayed(_ identifier: String) -> Bool {
        let element = otherElements[identifier].firstMatch
        return element.waitForExistence(timeout: 3)
    }
    
    /// Open settings window
    func openSettings() {
        typeKey(",", modifierFlags: .command)
    }
    
    /// Close current sheet
    func closeSheet() {
        typeKey(.escape, modifierFlags: [])
    }
}

// MARK: - Accessibility Identifiers

/// Central place for UI accessibility identifiers
/// These should match identifiers set in SwiftUI views
enum AccessibilityID {
    // Sidebar
    static let sidebar = "Sidebar"
    static let modelsTab = "Models"
    static let datasetsTab = "Datasets"
    static let trainingTab = "Training"
    static let inferenceTab = "Inference"
    static let settingsTab = "Settings"
    
    // Buttons
    static let newModelButton = "New Model"
    static let newDatasetButton = "New Dataset"
    static let startTrainingButton = "Start Training"
    
    // Views
    static let modelsView = "ModelsView"
    static let datasetsView = "DatasetsView"
    static let trainingView = "TrainingView"
    static let inferenceView = "InferenceView"
}
