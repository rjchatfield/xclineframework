import Testing
@_spi(Testing) import XCLineFramework

// MARK: - Basic String Cases

@Test func testBasicStringWithSpace() {
    expect {
        " |hello "
        " h|ello "
        " |h|ello "
        " hel|l|o "
        " hell|o| "
        " hello| "
    } expandsTo: {
        " |hello| "
    }
}

@Test func testBasicStringWithoutSpace() {
    expect {
        "|hello"
        "h|ello"
        "|h|ello"
        "hel|l|o"
        "hell|o|"
        "hello|"
    } expandsTo: {
        "|hello|"
    }
}

@Test func testStringWithLeadingQuote() {
    expect {
        #" "|hello "#
        #" "h|ello "#
        #" "|h|ello "#
        #" "hel|l|o "#
        #" "hell|o| "#
        #" "hello| "#
    } expandsTo: {
        #" "|hello| "#
    }
}

@Test func testStringWithTrailingQuote() {
    expect {
        #" |hello" "#
        #" h|ello" "#
        #" |h|ello" "#
        #" hel|l|o" "#
        #" hell|o|" "#
        #" hello|" "#
    } expandsTo: {
        #" |hello|" "#
    }
}

@Test func testStringWithQuotesOnBothSides() {
    expect {
        #""|hello""#
        #""h|ello""#
        #""|h|ello""#
        #""hel|l|o""#
        #""hell|o|""#
        #""hello|""#
    } expandsTo: {
        #""|hello|""#
        #"|"hello"|"#
    }
}

@Test func testStringWithQuotesAndSpace() {
    expect {
        #""|hello world""#
        #""h|ello world""#
        #""|h|ello world""#
        #""hel|l|o world""#
        #""hell|o| world""#.notYetSupported()
        #""hello| world""#.notYetSupported()
    } expandsTo: {
        #""|hello| world""#
        #""|hello world|""#
        #"|"hello world"|"#
    }
}

// MARK: - Swift Syntax Cases - Arrays

@Test func testBasicArray() {
    expect {
        "[1, 2, |3|, 4]"
        "[|1, 2, 3, 4|]"
        "|[1, 2, 3, 4]|"
    }
}

@Test func testNestedArrays() {
    expect {
        "[[1, |2|], [3, 4]]"
        "[[|1, 2|], [3, 4]]"
        "[|[1, 2]|, [3, 4]]"
        "[|[1, 2], [3, 4]|]"
        "|[[1, 2], [3, 4]]|"
    }
}

// MARK: - Swift Syntax Cases - Dictionaries

@Test func testDictionary() {
    expect {
        #"["key": |value]"#
        #"["key": |value|]"#
        #"[|"key": value|]"#
        #"|["key": value]|"#
    }
}

// MARK: - Swift Syntax Cases - Functions

@Test func testFunctionParameters() {
    expect {
        "func test(param1: |String)"
        "func test(param1: |String|)"
        "func test(|param1: String|)"
        "func test|(param1: String)|"
        "func |test(param1: String)|".notYetSupported()
    }
}

@Test func testFunctionWithMultipleParameters() {
    expect {
        "foo(arg|1: String, arg2: String)"
        "foo(|arg1|: String, arg2: String)"
        "foo(|arg1: String|, arg2: String)"
        "foo(|arg1: String, arg2: String|)"
        "foo|(arg1: String, arg2: String)|"
    }
}

@Test func testFunctionWithLabeledParameters() {
    expect {
        "foo(in arg1: String, at |arg2|: String)"
        "foo(in arg1: String, |at arg2: String|)"
        "foo(|in arg1: String, at arg2: String|)"
        "foo|(in arg1: String, at arg2: String)|"
    }
}

// MARK: - Swift Syntax Cases - Generics

@Test func testGenericType() {
    expect {
        "let array: Array<|String>"
        "let array: Array<|String|>"
        "let array: Array|<String>|"
        "let array: |Array<String>|".notYetSupported()
    }
}

@Test func testMultipleGenericParameters() {
    expect {
        "Dictionary<|String, Int>"
        "Dictionary<|String|, Int>"
        "Dictionary<|String, Int|>"
        "Dictionary|<String, Int>|"
        "|Dictionary<String, Int>|"
    }
}

@Test func testComplexGenericType() {
    expect {
        "Dictionary<String, Array<|Int>>"
        "Dictionary<String, Array<I|nt>>"
        "Dictionary<String, Array<Int|>>"
    } expandsTo: {
        "Dictionary<String, Array<|Int|>>"
        "Dictionary<String, Array|<Int>|>"
        "Dictionary<String, |Array<Int>|>"
        "Dictionary<|String, Array<Int>|>"
        "Dictionary|<String, Array<Int>>|"
        "|Dictionary<String, Array<Int>>|"
    }
}

// MARK: - Swift Syntax Cases - Closures

@Test func testSimpleClosure() {
    expect {
        "{ |param in"
        "{ |param| in".notYetSupported()
        "{ |param in|".notYetSupported()
    }
}

@Test func testClosureWithMultipleParams() {
    expect {
        "{ param, |p2 in"
        "{ param, |p2| in".notYetSupported()
        "{ |param, p2| in".notYetSupported()
        "{ |param, p2 in|".notYetSupported()
    }
}

@Test func testClosureWithParentheses() {
    expect {
        "{ (param, |p2) in"
        "{ (param, |p2|) in"
        "{ (|param, p2|) in"
        "{ |(param, p2)| in"
        "{ |(param, p2) in|".notYetSupported()
    }
}

@Test func testComplexClosure() {
    expect {
        "{ [weak self] (foo: (S|tring) -> Int) -> Bool in"
        "{ [weak self] (foo: (|String|) -> Int) -> Bool in"
        "{ [weak self] (foo: |(String)| -> Int) -> Bool in"
        "{ [weak self] (foo: |(String) -> Int|) -> Bool in".notYetSupported()
        "{ [weak self] (|foo: (String) -> Int|) -> Bool in"
        "{ [weak self] |(foo: (String) -> Int)| -> Bool in"
        "{ [weak self] |(foo: (String) -> Int) -> Bool| in".notYetSupported()
        "{ |[weak self] (foo: (String) -> Int) -> Bool in|".notYetSupported()
    }
}

// MARK: - Swift Syntax Cases - Other

@Test func testProtocolConformance() {
    expect {
        "class MyClass: |Protocol1|"
        "class MyClass: |Protocol1, Protocol2|".notYetSupported()
    }
}

@Test func testPropertyDeclaration() {
    expect {
        "var name: |String"
        "var name: |String|".notYetSupported()
        "var |name: String|".notYetSupported()
        "|var name: String|"
    }
}

@Test func testGuardStatement() {
    expect {
        "guard let |value = optional as? AnyObject"
        "guard let |value| = optional as? AnyObject".notYetSupported()
        "guard |let value| = optional as? AnyObject".notYetSupported()
        "guard |let value = optional as? AnyObject|".notYetSupported()
    }
}

@Test func testGuardStatementWithOptionalChaining() {
    expect {
        "guard let value = optional?.v|alue as? AnyObject,"
        "guard let value = optional?.|value| as? AnyObject,"
        "guard let value = optional|?.value| as? AnyObject,".notYetSupported()
        "guard let value = |optional?.value| as? AnyObject,".notYetSupported()
        "guard let value = |optional?.value as? AnyObject|,".notYetSupported()
        "guard |let value = optional?.value as? AnyObject|,".notYetSupported()
    }
}

@Test func testIfLetStatement() {
    expect {
        "if let value = optional?.v|alue as? AnyObject,"
        "if let value = optional?.|value| as? AnyObject,"
        "if let value = optional|?.value| as? AnyObject,".notYetSupported()
        "if let value = |optional?.value| as? AnyObject,".notYetSupported()
        "if let value = |optional?.value as? AnyObject|,".notYetSupported()
        "if |let value = optional?.value as? AnyObject|,".notYetSupported()
    }
}

@Test func testSwitchCase() {
    expect {
        "case .su|ccess: break"
        "case |.success|: break".notYetSupported()
        "|case .success: break|"
    }
}

@Test func testEnumDeclaration() {
    expect {
        "case suc|cess(String)"
        "case |success|(String)"
        "case |success(String)|".notYetSupported()
        "|case success(String)|"
    }
}

// MARK: - Helper Functions

/// DSL for test scenarios
/// - Parameters:
///   - initialCases: All of these strings should expand to the first string in `expandsTo:`. Failures will show up inline.
///   - expectations: All of these strings should expand one after another. Failures will show up inline.
private func expect(
    @LineTestResultBuilder initialCases: () -> [TestInfo] = { [] },
    @LineTestResultBuilder expandsTo expectations: () -> [TestInfo],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let expectations = expectations()
    let initialCases = initialCases()

    // Test all initial cases
    guard let firstExpectedString = expectations.first?.string else {
        Issue.record("Missing expectations", sourceLocation: sourceLocation)
        return
    }

    for initialCase in initialCases {
        print("")
        let initial = Buffer(testString: initialCase.string)
        let expected = Buffer(testString: firstExpectedString)
        print(" 🤔\(initial.rawDescription) -> \(expected.rawDescription)")
        let result = initial.classicExpandedRegion()
        let emoji = initialCase.skip ? "🐛" : result == expected ? " 😃" : " 👿"
        print("\(emoji) \(result.rawDescription)")
        if !initialCase.skip, result != expected {
            Issue.record(
                "Unexpected selection! Initial selection was `\(initial.rawDescription)`, expected selection was \(expected.rawDescription), but got `\(result.rawDescription)`",
                sourceLocation: initialCase.sourceLocation
            )
        }
        if initialCase.skip, result == expected {
            Issue.record("🎉 BUG SQUASHED! 🐛 Remove `.skip()`", sourceLocation: initialCase.sourceLocation)
        }
    }

    // Test all remaining cases
    var previousLineTest: TestInfo?
    for lineTest in expectations {
        defer { previousLineTest = lineTest }
        guard let previousLineTest else { continue }
        print("")
        let initial = Buffer(testString: previousLineTest.string)
        let expected = Buffer(testString: lineTest.string)
        print(" 🤔\(initial.rawDescription) -> \(expected.rawDescription)")
        let result = initial.classicExpandedRegion()
        let emoji = lineTest.skip ? "🐛" : result == expected ? " 😃" : " 👿"
        print("\(emoji) \(result.rawDescription)")
        if !lineTest.skip, result != expected {
            Issue.record(
                "Unexpected selection! Initial selection was `\(initial.rawDescription)`, expected selection was \(expected.rawDescription), but got `\(result.rawDescription)`",
                sourceLocation: lineTest.sourceLocation
            )
        }
        if lineTest.skip, result == expected {
            Issue.record("🎉 BUG SQUASHED! 🐛 Remove `.skip()`", sourceLocation: lineTest.sourceLocation)
        }
    }
}

// MARK: -

private struct TestInfo {
    let string: String
    let skip: Bool
    let sourceLocation: SourceLocation
}

// MARK: -

@resultBuilder
private enum LineTestResultBuilder {
    /// Capture source location
    static func buildExpression(_ expression: String, sourceLocation: SourceLocation = #_sourceLocation) -> TestInfo {
        TestInfo(string: expression, skip: false, sourceLocation: sourceLocation)
    }

    /// Useful for `.skip()`
    static func buildExpression(_ expression: TestInfo) -> TestInfo {
        expression
    }

    /// Note: No complicated result builder features (eg. if/else, loops)
    static func buildBlock(_ components: TestInfo...) -> [TestInfo] {
        components
    }
}

// MARK: -

private extension String {
    /// Will not fail tests if doesn't match.
    /// However, will fail tests if this begins to pass #progress
    func notYetSupported(sourceLocation: SourceLocation = #_sourceLocation) -> TestInfo {
        TestInfo(string: self, skip: true, sourceLocation: sourceLocation)
    }
}
