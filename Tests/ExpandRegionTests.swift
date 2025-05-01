import Testing
@_spi(Testing) import XCLineFramework

@Test func focusedScenario() {
    let initial = Buffer(testString: #""h|ello world""#)
    var result = initial
    result.expandSelections()
    #expect(result.rawDescription == #""|hello| world""#)

    result.expandSelections()
    #expect(result.rawDescription == #""|hello world|""#)

    result.expandSelections()
    #expect(result.rawDescription == #"|"hello world"|"#)
}

@Test func allCases() {
    // With space
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

    // Without space
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

    // Leading \"
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

    // trailing \"
    expect {
        " |hello\" "
        " h|ello\" "
        " |h|ello\" "
        " hel|l|o\" "
        " hell|o|\" "
        " hello|\" "
    } expandsTo: {
        " |hello|\" "
    }

    // " either side
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

    expect {
        #""|hello world""#
        #""h|ello world""#
        #""|h|ello world""#
        #""hel|l|o world""#
        #""hell|o| world""#
        #""hello| world""#
    } expandsTo: {
        #""|hello| world""#
        #""|hello world|""#
        #"|"hello world"|"#
    }

    expect {
        #" "|hello" "#
        #" "h|ello" "#
        #" "|h|ello" "#
        #" "hel|l|o" "#
        #" "hell|o|" "#
        #" "hello|" "#
    } expandsTo: {
        #" "|hello|" "#
        #" |"hello"| "#
    }

    // []
    expect {
        " [|hello] "
        " [h|ello] "
        " [|h|ello] "
        " [hel|l|o] "
        " [hell|o|] "
        " [hello|] "
    } expandsTo: {
        " [|hello|] "
        " |[hello]| "
    }
    // [,]
    expect {
        " [|hello, world] "
        " [h|ello, world] "
        " [|h|ello, world] "
        " [hel|l|o, world] "
        " [hell|o|, world] "
        " [hello|, world] "
    } expandsTo: {
        " [|hello|, world] "
        " [|hello, world|] "
        " |[hello, world]| "
    }

    expect {
        " [hello|,| world] "
        " [hello|, world|] "
        " [hello, |world|] "
        " [|hello,| world] "
    } expandsTo: {
        " [|hello, world|] "
        " |[hello, world]| "
    }

    expect {
        "[hello.|world|, test]"
        "[|hello|.world, test]"
        "[|hello.|world, test]"
        "[hello|.|world, test]"
    } expandsTo: {
        "[|hello.world|, test]"
        "[|hello.world, test|]"
        "|[hello.world, test]|"
    }

    expect {
        "[hello, |world|.test]"
        "[hello, world.|test|]"
        "[hello, |world.|test]"
        "[hello, world|.|test]"
    } expandsTo: {
        "[hello, |world.test|]"
        "[|hello, world.test|]"
        "|[hello, world.test]|"
    }

    expect {
        "[|[]]"
        "[[|]]"
        "[[]|]"
    } expandsTo: {
        "[|[]|]"
        "|[[]]|"
    }

    expect {
        "[|[], []]"
        "[[|], []]"
        "[[]|, []]"
    } expandsTo: {
        "[|[]|, []]"
        "[|[], []|]"
        "|[[], []]|"
    }
    expect {
        "[[], [|]]"
        "[[], |[]|]"
        "[|[], []|]"
        "|[[], []]|"
    }

    expect {
        "[[[]], [[|]], [[]]]"
        "[[[]], [|[]|], [[]]]"
        "[[[]], |[[]]|, [[]]]"
        "[|[[]], [[]], [[]]|]".skip()
        "|[[[]], [[]], [[]]]|"
    }

    expect {
        "[[\"hello\"], |[]|]"
        "[|[\"hello\"], []|]"
    }

    expect {
        " [|hello:| world] "
        " [hello|:| world] "
        " [hello|: world|] "
        " [hello: |world|] "
    } expandsTo: {
        " [|hello: world|] "
        " |[hello: world]| "
    }
    expect {
        "        \"|[\": \"]\","
        "        \"|[|\": \"]\",".skip()
        "        |\"[\"|: \"]\","
        "        |\"[\": \"]\"|,".skip()
        "        |\"[\": \"]\",|"
        "        |\"[\": \"]\",|"
    }

    expect {
        "(foo: hell|o.world)"
        "(foo: |hello|.world)"
        "(foo: |hello.world|)"
        "(|foo: hello.world|)"
        "|(foo: hello.world)|"
    }
    expect {
        "(foo: |hello|.world, bar: hello.world)"
        "(foo: |hello.world|, bar: hello.world)"
        "(|foo: hello.world|, bar: hello.world)"
        "(|foo: hello.world, bar: hello.world|)"
    }
    expect {
        "(fo|o: hello(bar: world))"
        "(|foo|: hello(bar: world))"
        "(|foo: hello(bar: world)|)"
    }
    expect {
        "(foo: he|llo(bar: world))"
        "(foo: |hello|(bar: world))"
        "(foo: |hello(bar: world)|)"
        "(|foo: hello(bar: world)|)"
    }
    expect {
        "(foo: hello(bar: worl|d))"
        "(foo: hello(bar: |world|))"
        "(foo: hello(|bar: world|))"
        "(foo: hello|(bar: world)|)"
        "(foo: |hello(bar: world)|)"
        "(|foo: hello(bar: world)|)"
    }
    expect {
        "this([is, \"a te|st for\"].myCode)"
        "this([is, \"a |test| for\"].myCode)"
        "this([is, \"|a test for|\"].myCode)"
    }

    expect {
        "this([is, \"a test fo|r\"].myCode)"
        "this([is, \"a test |for|\"].myCode)"
        "this([is, \"|a test for|\"].myCode)"
        "this([is, |\"a test for\"|].myCode)"
        "this([|is, \"a test for\"|].myCode)"
        "this(|[is, \"a test for\"]|.myCode)"
        "this(|[is, \"a test for\"].myCode|)"
        "this|([is, \"a test for\"].myCode)|"
        "|this([is, \"a test for\"].myCode)|"
    }

    expect {
        "this([i|s, \"a test for\"].myCode)"
        "this([|is|, \"a test for\"].myCode)"
        "this([|is, \"a test for\"|].myCode)"
    }
    expect {
        "foo(arg|1: String, arg2: String)"
        "foo(|arg1|: String, arg2: String)"
        "foo(|arg1: String|, arg2: String)"
        "foo(|arg1: String, arg2: String|)"
        "foo|(arg1: String, arg2: String)|"
    }
    expect {
        "foo(arg1: String, |arg2|: String)"
        "foo(arg1: String, |arg2: String|)"
        "foo(|arg1: String, arg2: String|)"
        "foo|(arg1: String, arg2: String)|"
    }

    expect {
        "foo(in arg1: String, at |arg2|: String)"
        "foo(in arg1: String, |at arg2: String|)"
        "foo(|in arg1: String, at arg2: String|)"
        "foo|(in arg1: String, at arg2: String)|"
    }

    expect {
        "String(chars[chars.index|(after: second)|..<chars.endIndex])"
        "String(chars[|chars.index(after: second)|..<chars.endIndex])"
        "String(chars[|chars.index(after: second)..<chars.endIndex|])".skip()
        "String(chars|[chars.index(after: second)..<chars.endIndex]|)"
    }

    expect {
        "func foo(|block: @escaping () -> Void) -> Bool"
        "func foo(b|lock: @escaping () -> Void) -> Bool"
        "func foo(b|l|ock: @escaping () -> Void) -> Bool"
        "func foo(block|: @escaping () -> Void) -> Bool"
    } expandsTo: {
        "func foo(|block|: @escaping () -> Void) -> Bool"
        "func foo(|block: @escaping () -> Void|) -> Bool"
        "func foo|(block: @escaping () -> Void)| -> Bool"
    }
    expect {
        "func foo(block: |@escaping () -> Void) -> Bool".skip()
        "func foo(block: @|escaping () -> Void) -> Bool"
        "func foo(block: @escaping| () -> Void) -> Bool".skip()
    } expandsTo: {
        "func foo(block: |@escaping| () -> Void) -> Bool"
        "func foo(block: |@escaping () -> Void|) -> Bool".skip()
        "func foo(|block: @escaping () -> Void|) -> Bool"
        "func foo|(block: @escaping () -> Void)| -> Bool"
    }
    expect {
        "func foo(block: @escaping |() -> Void) -> Bool".skip()
        "func foo(block: @escaping ()| -> Void) -> Bool".skip()
        "func foo(block: @escaping |()| -> Void) -> Bool".skip()
        "func foo(block: @escaping () -> |Void|) -> Bool".skip()
    } expandsTo: {
        "func foo(block: @escaping |() -> Void|) -> Bool"
        "func foo(block: |@escaping () -> Void|) -> Bool"
        "func foo(|block: @escaping () -> Void|) -> Bool"
        "func foo|(block: @escaping () -> Void)| -> Bool"
    }
    expect {
        "func foo(block: @escaping (|) -> Void) -> Bool"
    } expandsTo: {
        "func foo(block: @escaping |()| -> Void) -> Bool"
        "func foo(block: @escaping |() -> Void|) -> Bool".skip()
    }
    expect {
        "func foo(block: @escaping () -> |Void) -> Bool".skip()
        "func foo(block: @escaping () -> V|oid) -> Bool"
        "func foo(block: @escaping () -> Void|) -> Bool"
    } expandsTo: {
        "func foo(block: @escaping () -> |Void|) -> Bool"
        "func foo(block: @escaping |() -> Void|) -> Bool".skip()
    }
    expect {
        "func foo(block: @escaping () -> Void)| -> Bool".skip()
    } expandsTo: {
        "func foo|(block: @escaping () -> Void)| -> Bool"
    }
    expect {
        "func foo(block: @escaping () -> Void) -> |Bool".skip()
        "func foo(block: @escaping () -> Void) -> B|ool"
        "func foo(block: @escaping () -> Void) -> Bool|".skip()
    } expandsTo: {
        "func foo(block: @escaping () -> Void) -> |Bool|"
    }

    expect {
        "(|a|:b,c:d,e:f)"
        "(a|:|b,c:d,e:f)"
        "(a:|b|,c:d,e:f)"
    } expandsTo: {
        "(|a:b|,c:d,e:f)"
        "(|a:b,c:d,e:f|)"
        "|(a:b,c:d,e:f)|"
    }
    expect {
        "(a:b,|c|:d,e:f)"
        "(a:b,c|:|d,e:f)"
        "(a:b,c:|d|,e:f)"
    } expandsTo: {
        "(a:b,|c:d|,e:f)"
    }
    expect {
        "(a:b,c:d,|e|:f)"
        "(a:b,c:d,e:|f|)"
    } expandsTo: {
        "(a:b,c:d,|e:f|)"
    }
    expect {
        "(|a|: b, c: d, e: f)"
        "(a: |b|, c: d, e: f)"
    } expandsTo: {
        "(|a: b|, c: d, e: f)"
    }
    expect {
        "(a: b, |c|: d, e: f)"
        "(a: b, c: |d|, e: f)"
    } expandsTo: {
        "(a: b, |c: d|, e: f)"
    }
    expect {
        "(a: b, c: d, |e|: f)"
        "(a: b, c: d, e: |f|)"
    } expandsTo: {
        "(a: b, c: d, |e: f|)"
    }

    expect {
        "[|a:b,c:d,e:f]"
        "[a|:b,c:d,e:f]"
    } expandsTo: {
        "[|a|:b,c:d,e:f]"
    }
    expect {
        "[a:|b,c:d,e:f]"
        "[a:b|,c:d,e:f]"
    } expandsTo: {
        "[a:|b|,c:d,e:f]"
    }
    expect {
        "[a: |b, c: d, e: f]"
        "[a: b|, c: d, e: f]"
    } expandsTo: {
        "[a: |b|, c: d, e: f]"
    }

    expect {
        "[|a|:b,c:d,e:f]"
        "[a:|b|,c:d,e:f]"
    } expandsTo: {
        "[|a:b|,c:d,e:f]"
        "[|a:b,c:d,e:f|]"
        "|[a:b,c:d,e:f]|"
    }
    expect {
        "[a:b,|c|:d,e:f]"
        "[a:b,|c:|d,e:f]"
        "[a:b,c:|d|,e:f]"
    } expandsTo: {
        "[a:b,|c:d|,e:f]"
        "[|a:b,c:d,e:f|]"
        "|[a:b,c:d,e:f]|"
    }
    expect {
        "[a:b,c:d,|e|:f]"
        "[a:b,c:d,e:|f|]"
    } expandsTo: {
        "[a:b,c:d,|e:f|]"
        "[|a:b,c:d,e:f|]"
        "|[a:b,c:d,e:f]|"
    }

    expect {
        "[|a|: b, c: d, e: f]"
        "[a: |b|, c: d, e: f]"
    } expandsTo: {
        "[|a: b|, c: d, e: f]"
    }
    expect {
        "[a: b, |c|: d, e: f]"
        "[a: b, c: |d|, e: f]"
    } expandsTo: {
        "[a: b, |c: d|, e: f]"
    }
    expect {
        "[a: b, c: d, |e|: f]"
        "[a: b, c: d, e: |f|]"
    } expandsTo: {
        "[a: b, c: d, |e: f|]"
    }

    expect {
        "<|a|:b,c:d,e:f>"
        "<a:|b|,c:d,e:f>"
    } expandsTo: {
        "<|a:b|,c:d,e:f>"
    }
    expect {
        "<a:b,|c|:d,e:f>"
        "<a:b,c:|d|,e:f>"
    } expandsTo: {
        "<a:b,|c:d|,e:f>"
    }
    expect {
        "<a:b,c:d,|e|:f>"
        "<a:b,c:d,e:|f|>"
    } expandsTo: {
        "<a:b,c:d,|e:f|>"
    }

    expect {
        "<|a|: b, c: d, e: f>"
        "<a: |b|, c: d, e: f>"
    } expandsTo: {
        "<|a: b|, c: d, e: f>"
    }
    expect {
        "<a: b, |c|: d, e: f>"
        "<a: b, c: |d|, e: f>"
    } expandsTo: {
        "<a: b, |c: d|, e: f>"
    }
    expect {
        "<a: b, c: d, |e|: f>"
        "<a: b, c: d, e: |f|>"
    } expandsTo: {
        "<a: b, c: d, |e: f|>"
    }

    expect {
        "|Dictionary<String, Array<Int>>".skip()
        "Dict|ionary<String, Array<Int>>"
        "Dictionary|<String, Array<Int>>"
    } expandsTo: {
        "|Dictionary|<String, Array<Int>>"
        "|Dictionary<String, Array<Int>>|"
    }
    expect {
        "Dictionary<|String, Array<Int>>"
        "Dictionary<Str|ing, Array<Int>>"
        "Dictionary<String|, Array<Int>>"
    } expandsTo: {
        "Dictionary<|String|, Array<Int>>"
        "Dictionary<|String, Array<Int>|>"
        "Dictionary|<String, Array<Int>>|"
        "|Dictionary<String, Array<Int>>|"
    }
    expect {
        "Dictionary<String, |Array<Int>>".skip()
        "Dictionary<String, Ar|ray<Int>>"
        "Dictionary<String, Array|<Int>>"
    } expandsTo: {
        "Dictionary<String, |Array|<Int>>"
        "Dictionary<String, |Array<Int>|>"
        "Dictionary<|String, Array<Int>|>"
        "Dictionary|<String, Array<Int>>|"
        "|Dictionary<String, Array<Int>>|"
    }
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
    expect {
        "Dictionary<String, Array<Int>|>"
        "Dictionary<String, Array|<Int>|>".skip()
        "Dictionary<String, |Array<Int>|>"
    }
    expect {
        "Dictionary<String, Array<Int>>|"
        "Dictionary|<String, Array<Int>>|".skip()
        "|Dictionary<String, Array<Int>>|"
    }

    expect {
        "case (_?, nil|): return .orderedAscending"
        "case (_?, |nil|): return .orderedAscending"
        "case (|_?, nil|): return .orderedAscending"
        "case |(_?, nil)|: return .orderedAscending"
        "|case (_?, nil): return .orderedAscending|"
    }

    expect {
        "let new.line = |currentLine.expandRegion()".skip()
        "let new.line = current|Line.expandRegion()"
        "let new.line = |current|Line.expandRegion()".skip()
        "let new.line = current|Line|.expandRegion()"
        "let new.line = currentLine|.expandRegion()"
    } expandsTo: {
        "let new.line = |currentLine|.expandRegion()"
        "let new.line = |currentLine.expandRegion()|"
    }
    expect {
        "let ne|w.line = currentLine.expandRegion()"
        "let |new|.line = currentLine.expandRegion()"
        "let |new.line| = currentLine.expandRegion()".skip()
    }

    expect {
        "func foo(f: @escaping (H|ello) -> World) -> Boom"
        "func foo(f: @escaping (|Hello|) -> World) -> Boom"
        "func foo(f: @escaping |(Hello)| -> World) -> Boom"
        "func foo(f: |@escaping (Hello) -> World|) -> Boom".skip()
        "func foo(|f: @escaping (Hello) -> World|) -> Boom"
        "func foo|(f: @escaping (Hello) -> World)| -> Boom"
    }

    expect {
        "  var |myVar: String".skip()
        "  var my|Var: String"
        "  var |my|Var: String".skip()
        "  var my|Var|: String"
        "  var myVar|: String"
    } expandsTo: {
        "  var |myVar|: String"
        "  var |myVar: String|".skip()
    }

    expect {
        "  func |myFunc() async throws -> String".skip()
        "  func my|Func() async throws -> String"
        "  func |my|Func() async throws -> String".skip()
        "  func my|Func|() async throws -> String"
        "  func myFunc|() async throws -> String"
    } expandsTo: {
        "  func |myFunc|() async throws -> String"
        "  func |myFunc()| async throws -> String".skip()
    }

    expect {
        "  func myFunc|() async throws -> String"
        "  func |myFunc|() async throws -> String"
        "  func |myFunc()| async throws -> String".skip()
    }

    expect {
        "  func myFunc()| async throws -> String"
        "  func |myFunc|() async throws -> String".skip()
    }

    expect {
        #"let emoji = |initialCase.skip ? "bug" : result == expected ? " yep" : " nop""#.skip()
        #"let emoji = initial|Case.skip ? "bug" : result == expected ? " yep" : " nop""#
        #"let emoji = initialCase|.skip ? "bug" : result == expected ? " yep" : " nop""#
    } expandsTo: {
        #"let emoji = |initialCase|.skip ? "bug" : result == expected ? " yep" : " nop""#
        #"let emoji = |initialCase.skip| ? "bug" : result == expected ? " yep" : " nop""#.skip()
        #"let emoji = |initialCase.skip ? "bug" : result == expected ? " yep" : " nop"|"#.skip()
        #"|let emoji = initialCase.skip ? "bug" : result == expected ? " yep" : " nop"|"#
    }
    expect {
        #"let emoji = initialCase.skip ? "|bug" : result == expected ? " yep" : " nop""#
        #"let emoji = initialCase.skip ? "b|ug" : result == expected ? " yep" : " nop""#
        #"let emoji = initialCase.skip ? "bug|" : result == expected ? " yep" : " nop""#
    } expandsTo: {
        #"let emoji = initialCase.skip ? "|bug|" : result == expected ? " yep" : " nop""#
        #"let emoji = initialCase.skip ? |"bug"| : result == expected ? " yep" : " nop""#
        #"let emoji = initialCase.skip ? |"bug"| : result == expected ? " yep" : " nop""#.skip()
        #"let emoji = |initialCase.skip ? "bug" : result == expected ? " yep" : " nop"|"#.skip()
    }
    expect {
        #"let emoji = initialCase.skip ? "bug" : |result == expected ? " yep" : " nop""#.skip()
        #"let emoji = initialCase.skip ? "bug" : re|sult == expected ? " yep" : " nop""#
        #"let emoji = initialCase.skip ? "bug" : result| == expected ? " yep" : " nop""#.skip()
    } expandsTo: {
        #"let emoji = initialCase.skip ? "bug" : |result| == expected ? " yep" : " nop""#
        #"let emoji = initialCase.skip ? "bug" : |result == expected| ? " yep" : " nop""#.skip()
        #"let emoji = |initialCase.skip ? "bug" : result == expected ? " yep" : " nop"|"#.skip()
    }
    expect {
        #"let emoji = initialCase.skip ? "bug" : result |== expected ? " yep" : " nop""#.skip()
        #"let emoji = initialCase.skip ? "bug" : result =|= expected ? " yep" : " nop""#
        #"let emoji = initialCase.skip ? "bug" : result ==| expected ? " yep" : " nop""#.skip()
        #"let emoji = initialCase.skip ? "bug" : result =|=| expected ? " yep" : " nop""#.skip()
        #"let emoji = initialCase.skip ? "bug" : result |=|= expected ? " yep" : " nop""#.skip()
    } expandsTo: {
        #"let emoji = initialCase.skip ? "bug" : result |==| expected ? " yep" : " nop""#
        #"let emoji = initialCase.skip ? "bug" : |result == expected| ? " yep" : " nop""#.skip()
        #"let emoji = |initialCase.skip ? "bug" : result == expected ? " yep" : " nop"|"#.skip()
    }
    expect {
        #"let emoji = initialCase.skip ? "bug" : result == expected ? " |yep" : " nop""#
        #"let emoji = initialCase.skip ? "bug" : result == expected ? " y|ep" : " nop""#
        #"let emoji = initialCase.skip ? "bug" : result == expected ? " yep|" : " nop""#
    } expandsTo: {
        #"let emoji = initialCase.skip ? "bug" : result == expected ? " |yep|" : " nop""#
        #"let emoji = initialCase.skip ? "bug" : result == expected ? "| yep|" : " nop""#.skip()
        #"let emoji = initialCase.skip ? "bug" : result == expected ? |" yep"| : " nop""#
        #"let emoji = |initialCase.skip ? "bug" : result == expected ? " yep" : " nop"|"#.skip()
    }
    expect {
        #"let emoji = initialCase.skip ? "bug" : result == expected ? "| yep" : " nop""#
        #"let emoji = initialCase.skip ? "bug" : result == expected ? "| yep|" : " nop""#.skip()
    }
}

// MARK: -


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
        var result = initial
        result.expandSelections()
        let emoji = initialCase.skip ? "🐛" : result == expected ? " 😃" : " 👿"
        print("\(emoji) \(result.rawDescription)")
        if !initialCase.skip, result != expected {
//            Issue.record("`\(result.rawDescription)` -- (expected: `\(expected.rawDescription)`)", sourceLocation: initialCase.sourceLocation)
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
        var result = initial
        result.expandSelections()
        let emoji = lineTest.skip ? "🐛" : result == expected ? " 😃" : " 👿"
        print("\(emoji) \(result.rawDescription)")
        if !lineTest.skip, result != expected {
//            Issue.record("`\(result.rawDescription)` -- (expected: `\(expected.rawDescription)`)", sourceLocation: lineTest.sourceLocation)
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
    func skip(sourceLocation: SourceLocation = #_sourceLocation) -> TestInfo {
        TestInfo(string: self, skip: true, sourceLocation: sourceLocation)
    }
}
