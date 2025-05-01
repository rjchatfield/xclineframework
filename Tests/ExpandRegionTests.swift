import Testing
@_spi(Testing) import XCLineFramework

// MARK: - Basic String Cases

@Test func testBasicStringWithSpace() {
    expect(
        eachInitialCase: {
            " |hello " // I'm at the start of a word, I should select the word
            " h|ello " // I'm in the middle of a word, I should select the word
            " |h|ello " // I'm at the start of a word, I should select the word
            " hel|l|o " // I'm in the middle of a word, I should select the word
            " hell|o| " // I'm at the end of a word, I should select the word
            " hello| " // I'm at the end of a word, I should select the word
        },
        expandsTo: {
            " |hello| " // I have selected the entire word
        }
    )
}

@Test func testBasicStringWithoutSpace() {
    expect(
        eachInitialCase: {
            "|hello" // I'm at the start of a word, I should select the word
            "h|ello" // I'm in the middle of a word, I should select the word
            "|h|ello" // I'm at the start of a word, I should select the word
            "hel|l|o" // I'm in the middle of a word, I should select the word
            "hell|o|" // I'm at the end of a word, I should select the word
            "hello|" // I'm at the end of a word, I should select the word
        },
        expandsTo: {
            "|hello|" // I have selected the entire word
        }
    )
}

@Test func testStringWithLeadingQuote() {
    expect(
        eachInitialCase: {
            #" "|hello "# // I'm at the start of a word, I should select the word
            #" "h|ello "# // I'm in the middle of a word, I should select the word
            #" "|h|ello "# // I'm at the start of a word, I should select the word
            #" "hel|l|o "# // I'm in the middle of a word, I should select the word
            #" "hell|o| "# // I'm at the end of a word, I should select the word
            #" "hello| "# // I'm at the end of a word, I should select the word
        },
        expandsTo: {
            #" "|hello| "# // I have selected the entire word
        }
    )
}

@Test func testStringWithTrailingQuote() {
    expect(
        eachInitialCase: {
            #" |hello" "# // I'm at the start of a word, I should select the word
            #" h|ello" "# // I'm in the middle of a word, I should select the word
            #" |h|ello" "# // I'm at the start of a word, I should select the word
            #" hel|l|o" "# // I'm in the middle of a word, I should select the word
            #" hell|o|" "# // I'm at the end of a word, I should select the word
            #" hello|" "# // I'm at the end of a word, I should select the word
        },
        expandsTo: {
            #" |hello|" "# // I have selected the entire word
        }
    )
}

@Test func testStringWithQuotesOnBothSides() {
    expect(
        eachInitialCase: {
            #""|hello""# // I'm at the start of a word, I should select the word
            #""h|ello""# // I'm in the middle of a word, I should select the word
            #""|h|ello""# // I'm at the start of a word, I should select the word
            #""hel|l|o""# // I'm in the middle of a word, I should select the word
            #""hell|o|""# // I'm at the end of a word, I should select the word
            #""hello|""# // I'm at the end of a word, I should select the word
        },
        expandsTo: {
            #""|hello|""# // I am at the edges of a string, I should select the quotes too
        },
        thenExpandsStepByStepTo: {
            #"|"hello"|"# // I have selected the string and it's quotes
        }
    )
}

@Test func testStringWithQuotesAndSpace() {
    expect(
        eachInitialCase: {
            #""|hello world""# // I'm at the start of a word, I should select the word
            #""h|ello world""# // I'm in the middle of a word, I should select the word
            #""|h|ello world""# // I'm at the start of a word, I should select the word
            #""hel|l|o world""# // I'm in the middle of a word, I should select the word
            #""hell|o| world""# // I'm at the end of a word, I should select the word
            #""hello| world""# // I'm at the end of a word, I should select the word
        },
        expandsTo: {
            #""|hello| world""# // I have selected the entire word. I am in a string, so I should select everything within the quotes
        },
        thenExpandsStepByStepTo: {
            #""|hello world|""# // I am at the edges of a string, I should select the quotes too
            #"|"hello world"|"# // I have selected the string and it's quotes
        }
    )
}

// MARK: - Swift Syntax Cases - Arrays

@Test func testBasicArray() {
    expect(
        eachInitialCase: {
            "[1, 2, |3, 4]"
            "[1, 2, 3|, 4]"
        },
        expandsTo: {
            "[1, 2, |3|, 4]"
        },
        thenExpandsStepByStepTo: {
            "[|1, 2, 3, 4|]"
            "|[1, 2, 3, 4]|"
        }
    )
}

@Test func testNestedArrays() {
    expect(
        expandsStepByStep: {
            "[[1, |2|], [3, 4]]"
            "[[|1, 2|], [3, 4]]"
            "[|[1, 2]|, [3, 4]]"
            "[|[1, 2], [3, 4]|]"
            "|[[1, 2], [3, 4]]|"
        }
    )
}

// MARK: - Swift Syntax Cases - Dictionaries

@Test func testDictionary() {
    expect(
        expandsStepByStep: {
            #"["key": |value]"#
            #"["key": |value|]"#
            #"[|"key": value|]"#
            #"|["key": value]|"#
        }
    )
}

// MARK: - Swift Syntax Cases - Functions

@Test func testFunctionParameters() {
    expect(
        expandsStepByStep: {
            "func test(param1: |String)"
            "func test(param1: |String|)"
            "func test(|param1: String|)"
            "func test|(param1: String)|"
            "func |test(param1: String)|".notYetSupported()
        }
    )
}

@Test func testFunctionWithMultipleParameters() {
    expect(
        expandsStepByStep: {
            "foo(arg|1: String, arg2: String)"
            "foo(|arg1|: String, arg2: String)"
            "foo(|arg1: String|, arg2: String)"
            "foo(|arg1: String, arg2: String|)"
            "foo|(arg1: String, arg2: String)|"
        }
    )
}

@Test func testFunctionWithLabeledParameters() {
    expect(
        expandsStepByStep: {
            "foo(in arg1: String, at |arg2|: String)"
            "foo(in arg1: String, |at arg2: String|)"
            "foo(|in arg1: String, at arg2: String|)"
            "foo|(in arg1: String, at arg2: String)|"
        }
    )
}

// MARK: - Swift Syntax Cases - Generics

@Test func testGenericType() {
    expect(
        expandsStepByStep: {
            "let array: Array<|String>"
            "let array: Array<|String|>"
            "let array: Array|<String>|"
            "let array: |Array<String>|".notYetSupported()
        }
    )
}

@Test func testMultipleGenericParameters() {
    expect(
        expandsStepByStep: {
            "Dictionary<|String, Int>"
            "Dictionary<|String|, Int>"
            "Dictionary<|String, Int|>"
            "Dictionary|<String, Int>|"
            "|Dictionary<String, Int>|"
        }
    )
}

@Test func testComplexGenericType() {
    expect(
        eachInitialCase: {
            "Dictionary<String, Array<|Int>>"
            "Dictionary<String, Array<I|nt>>"
            "Dictionary<String, Array<Int|>>"
        },
        expandsTo: {
            "Dictionary<String, Array<|Int|>>"
        },
        thenExpandsStepByStepTo: {
            "Dictionary<String, Array|<Int>|>"
            "Dictionary<String, |Array<Int>|>"
            "Dictionary<|String, Array<Int>|>"
            "Dictionary|<String, Array<Int>>|"
            "|Dictionary<String, Array<Int>>|"
        }
    )
}

// MARK: - Swift Syntax Cases - Closures

@Test func testSimpleClosure() {
    expect(
        expandsStepByStep: {
            "{ |param in"
            "{ |param| in"
            "{ |param in|".notYetSupported()
        }
    )
}

@Test func testClosureWithMultipleParams() {
    expect(
        expandsStepByStep: {
            "{ param, |p2 in"
            "{ param, |p2| in"
            "{ |param, p2| in".notYetSupported()
            "{ |param, p2 in|".notYetSupported()
        }
    )
}

@Test func testClosureWithParentheses() {
    expect(
        expandsStepByStep: {
            "{ (param, |p2) in"
            "{ (param, |p2|) in"
            "{ (|param, p2|) in"
            "{ |(param, p2)| in"
            "{ |(param, p2) in|".notYetSupported()
        }
    )
}

@Test func testComplexClosure() {
    expect(
        expandsStepByStep: {
            "{ [weak self] (foo: (S|tring) -> Int) -> Bool in"
            "{ [weak self] (foo: (|String|) -> Int) -> Bool in"
            "{ [weak self] (foo: |(String)| -> Int) -> Bool in"
            "{ [weak self] (foo: |(String) -> Int|) -> Bool in".notYetSupported()
            "{ [weak self] (|foo: (String) -> Int|) -> Bool in"
            "{ [weak self] |(foo: (String) -> Int)| -> Bool in"
            "{ [weak self] |(foo: (String) -> Int) -> Bool| in".notYetSupported()
            "{ |[weak self] (foo: (String) -> Int) -> Bool in|".notYetSupported()
        }
    )
}

// MARK: - Swift Syntax Cases - Other

@Test func testProtocolConformance() {
    expect(
        expandsStepByStep: {
            "class MyClass: |Protocol1|"
            "class MyClass: |Protocol1, Protocol2|".notYetSupported()
        }
    )
}

@Test func testPropertyDeclaration() {
    expect(
        expandsStepByStep: {
            "var name: |String"
            "var name: |String|"
            "var |name: String|".notYetSupported()
            "|var name: String|"
        }
    )
}

@Test func testGuardStatement() {
    expect(
        expandsStepByStep: {
            "guard let |value = optional as? AnyObject"
            "guard let |value| = optional as? AnyObject"
            "guard |let value| = optional as? AnyObject".notYetSupported()
            "guard |let value = optional as? AnyObject|".notYetSupported()
        }
    )
}

@Test func testGuardStatementWithOptionalChaining() {
    expect(
        expandsStepByStep: {
            "guard let value = optional?.v|alue as? AnyObject,"
            "guard let value = optional?.|value| as? AnyObject,"
            "guard let value = optional|?.value| as? AnyObject,".notYetSupported()
            "guard let value = |optional?.value| as? AnyObject,".notYetSupported()
            "guard let value = |optional?.value as? AnyObject|,".notYetSupported()
            "guard |let value = optional?.value as? AnyObject|,".notYetSupported()
        }
    )
}

@Test func testIfLetStatement() {
    expect(
        expandsStepByStep: {
            "if let value = optional?.v|alue as? AnyObject,"
            "if let value = optional?.|value| as? AnyObject,"
            "if let value = optional|?.value| as? AnyObject,".notYetSupported()
            "if let value = |optional?.value| as? AnyObject,".notYetSupported()
            "if let value = |optional?.value as? AnyObject|,".notYetSupported()
            "if |let value = optional?.value as? AnyObject|,".notYetSupported()
        }
    )
}

@Test func testSwitchCase() {
    expect(
        expandsStepByStep: {
            "case .su|ccess: break"
            "case |.success|: break".notYetSupported()
            "|case .success: break|"
        }
    )
}

@Test func testEnumDeclaration() {
    expect(
        expandsStepByStep: {
            "case suc|cess(String)"
            "case |success|(String)"
            "case |success(String)|".notYetSupported()
            "|case success(String)|"
        }
    )
}

// MARK: - Helper Functions

private func expect(
    @LineTestResultBuilder expandsStepByStep expectations: () -> [TestInfo],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    var expectations = expectations()
    guard !expectations.isEmpty else {
        Issue.record("Missing expectations", sourceLocation: sourceLocation)
        return
    }
    let firstExpectation = expectations.removeFirst()
    expect(
        eachInitialCase: {},
        expandsTo: { firstExpectation },
        thenExpandsStepByStepTo: { expectations },
        sourceLocation: sourceLocation
    )
}

private func expect(
    @LineTestResultBuilder eachInitialCase initialCases: () -> [TestInfo],
    @LineTestResultBuilder expandsTo expectation1: () -> TestInfo,
    @LineTestResultBuilder thenExpandsStepByStepTo expectations2: () -> [TestInfo] = { [] },
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let initialCases = initialCases()
    let initialExpandsTo = expectation1()
    let thenExpandsStepByStep = expectations2()

    // Test all initial cases
    for initialCase in initialCases {
        print("")
        let initial = Buffer(testString: initialCase.string)
        let expected = Buffer(testString: initialExpandsTo.string)
        print(" 🤔\(initial.rawDescription) -> \(expected.rawDescription)")
        var mutableInitial = initial
        let result = mutableInitial.expandedSelection()
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
    var previousLineTest: TestInfo = initialExpandsTo
    for lineTest in thenExpandsStepByStep {
        defer { previousLineTest = lineTest }
        print("")
        let initial = Buffer(testString: previousLineTest.string)
        let expected = Buffer(testString: lineTest.string)
        print(" 🤔\(initial.rawDescription) -> \(expected.rawDescription)")
        var mutableInitial = initial
        let result = mutableInitial.expandedSelection()
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

    /// Useful for returning array in helper (ie. `thenExpandsStepByStepTo: { expectations }`)
    static func buildExpression(_ expression: [TestInfo]) -> [TestInfo] {
        expression
    }

    /// Useful for returning single not array (it. `expandsTo: () -> TestInfo`)
    static func buildBlock(_ component: TestInfo) -> TestInfo {
        component
    }

    /// Note: No complicated result builder features (eg. if/else, loops)
    static func buildBlock(_ components: TestInfo...) -> [TestInfo] {
        components
    }

    static func buildBlock(_ components: [TestInfo]) -> [TestInfo] {
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
