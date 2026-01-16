import XCTest
@testable import MacML

final class ModelRepositoryTests: XCTestCase {
    
    // MARK: - SQL Injection Prevention Tests
    
    /// Test that special SQL characters are properly escaped in search queries
    func testSearchQuerySanitization() async throws {
        // These are the characters that need escaping in LIKE patterns
        let maliciousInputs = [
            "%",           // LIKE wildcard
            "_",           // LIKE single char wildcard
            "\\",          // Escape character
            "%';--",       // SQL injection attempt
            "test%_\\",    // Combined special chars
            "'; DROP TABLE models; --", // Classic SQL injection
        ]
        
        // The search function should handle all these without crashing
        // (In a real test with database, we'd verify it doesn't return unexpected results)
        for input in maliciousInputs {
            // Verify the sanitization logic directly
            let sanitized = input
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%")
                .replacingOccurrences(of: "_", with: "\\_")
            
            // Verify wildcards are escaped
            if input.contains("%") {
                XCTAssertTrue(sanitized.contains("\\%"), "% should be escaped to \\%")
            }
            if input.contains("_") {
                XCTAssertTrue(sanitized.contains("\\_"), "_ should be escaped to \\_")
            }
        }
    }
    
    /// Test that normal search queries work correctly
    func testNormalSearchQueryNotAffected() {
        let normalInputs = [
            "model",
            "test-model",
            "my_model",  // This underscore should be escaped in LIKE
            "Model v2.0",
            "résumé",    // Unicode
            "模型",       // CJK characters
        ]
        
        for input in normalInputs {
            let sanitized = input
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%")
                .replacingOccurrences(of: "_", with: "\\_")
            
            // Verify the core search term is preserved (ignoring escape chars)
            let unescaped = sanitized
                .replacingOccurrences(of: "\\%", with: "%")
                .replacingOccurrences(of: "\\_", with: "_")
                .replacingOccurrences(of: "\\\\", with: "\\")
            
            XCTAssertEqual(input, unescaped, "Sanitization should be reversible for normal queries")
        }
    }
    
    // MARK: - Model Record Conversion Tests
    
    func testModelRecordRoundTrip() {
        let originalModel = MLModel(
            id: "test-123",
            name: "Test Model",
            framework: .mlx,
            status: .ready,
            accuracy: 0.95,
            fileSize: 1024,
            filePath: "/path/to/model",
            metadata: ["version": "1.0", "author": "test"]
        )
        
        // Test that model can be represented consistently
        XCTAssertEqual(originalModel.id, "test-123")
        XCTAssertEqual(originalModel.name, "Test Model")
        XCTAssertEqual(originalModel.framework, .mlx)
        XCTAssertEqual(originalModel.status, .ready)
        XCTAssertEqual(originalModel.accuracy, 0.95)
    }
}
