import XCTest
@testable import XCLineFramework

final class ExpandRegionTests: XCTestCase {
    
    /// For Linux tests
    static var allTests : [(String, (XCLineTests) -> () throws -> Void)] {
        return [
            ("testWordInHello", testWordInHello),
            ("testWordInQuotes", testWordInQuotes),
            ("testWordInArray", testWordInArray),
            ("testDictionary", testDictionary),
            ("testFunc", testFunc),
            ("testPairs_params", testPairs_params),
            ("testPairs_dict", testPairs_dict),
            ("testPairs_generics", testPairs_generics),
            ("testCase", testCase),
            ("testAssign", testAssign),
        ]
    }
    
    func testWordInHello() {
        // With space
        assert(" |hello "  => " |hello| ")
        assert(" h|ello "  => " |hello| ")
        assert(" |h|ello " => " |hello| ")
        assert(" hel|l|o " => " |hello| ")
        assert(" hell|o| " => " |hello| ")
        assert(" hello| "  => " |hello| ")
        
        // Without space
        assert("|hello"  => "|hello|")
        assert("h|ello"  => "|hello|")
        assert("|h|ello" => "|hello|")
        assert("hel|l|o" => "|hello|")
        assert("hell|o|" => "|hello|")
        assert("hello|"  => "|hello|")
    }
    
    func testWordInQuotes() {
        // Leading \"
        assert(" \"|hello "  => " \"|hello| ")
        assert(" \"h|ello "  => " \"|hello| ")
        assert(" \"|h|ello " => " \"|hello| ")
        assert(" \"hel|l|o " => " \"|hello| ")
        assert(" \"hell|o| " => " \"|hello| ")
        assert(" \"hello| "  => " \"|hello| ")
        // trailing \"
        assert(" |hello\" "  => " |hello|\" ")
        assert(" h|ello\" "  => " |hello|\" ")
        assert(" |h|ello\" " => " |hello|\" ")
        assert(" hel|l|o\" " => " |hello|\" ")
        assert(" hell|o|\" " => " |hello|\" ")
        assert(" hello|\" "  => " |hello|\" ")
        // " either side
        assert(" \"|hello\" "   => " \"|hello|\" ")
        assert(" \"h|ello\" "   => " \"|hello|\" ")
        assert(" \"|h|ello\" "  => " \"|hello|\" ")
        assert(" \"hel|l|o\" "  => " \"|hello|\" ")
        assert(" \"hell|o|\" "  => " \"|hello|\" ")
        assert(" \"hello|\" "   => " \"|hello|\" ")
    }
    
    func testWordInArray() {
        // []
        assert(" [|hello] "  => " [|hello|] ")
        assert(" [h|ello] "  => " [|hello|] ")
        assert(" [|h|ello] " => " [|hello|] ")
        assert(" [hel|l|o] " => " [|hello|] ")
        assert(" [hell|o|] " => " [|hello|] ")
        assert(" [hello|] "  => " [|hello|] ")
        // [,]
        assert(" [|hello, world] "  => " [|hello|, world] ")
        assert(" [h|ello, world] "  => " [|hello|, world] ")
        assert(" [|h|ello, world] " => " [|hello|, world] ")
        assert(" [hel|l|o, world] " => " [|hello|, world] ")
        assert(" [hell|o|, world] " => " [|hello|, world] ")
        assert(" [hello|, world] "  => " [|hello|, world] ")
    }
    
    func testArray() {
        assert(" [hello|,| world] " => " [|hello, world|] ")
        assert(" [hello|, world|] " => " [|hello, world|] ")
        assert(" [hello, |world|] " => " [|hello, world|] ")
        assert(" [|hello,| world] " => " [|hello, world|] ")
        
        assert("[hello.|world|, test]" => "[|hello.world|, test]")
        assert("[|hello|.world, test]" => "[|hello.world|, test]")
        assert("[|hello.|world, test]" => "[|hello.world|, test]")
        assert("[hello|.|world, test]" => "[|hello.world|, test]")
        
        assert("[hello, |world|.test]" => "[hello, |world.test|]")
        assert("[hello, world.|test|]" => "[hello, |world.test|]")
        assert("[hello, |world.|test]" => "[hello, |world.test|]")
        assert("[hello, world|.|test]" => "[hello, |world.test|]")
        
        expect(thatThis: "[[|]]")
            .expands(to: "[|[]|]")
            .expands(to: "|[[]]|")
        
        expect(thatThis: "[[|], []]")
            .expands(to: "[|[]|, []]")
            .expands(to: "[|[], []|]")
        expect(thatThis: "[[], [|]]")
            .expands(to: "[[], |[]|]")
            .expands(to: "[|[], []|]")
        
        _expect(thatThis: "[[[]], [[|]], [[]]]")
            .expands(to: "[[[]], [|[]|], [[]]]")
            .expands(to: "[[[]], |[[]]|, [[]]]")
            .expands(to: "|[[[]], [[]], [[]]]|")
        
        assert("[[\"hello\"], |[]|]" => "[|[\"hello\"], []|]")
    }
    
    func testDictionary() {
        assert(" [|hello:| world] " => " [|hello: world|] ")
        assert(" [hello|:| world] " => " [|hello: world|] ")
        assert(" [hello|: world|] " => " [|hello: world|] ")
        assert(" [hello: |world|] " => " [|hello: world|] ")
        _expect(thatThis: "        \"|[\": \"]\",")
            .expands(to: "        \"|[|\": \"]\",")
            .expands(to: "        |\"[\"|: \"]\",")
            .expands(to: "        |\"[\": \"]\"|,")
            .expands(to: "        |\"[\": \"]\",|")
            .expands(to: "        |\"[\": \"]\",|")
    }
    
    func testFunc() {
        expect(thatThis: "(foo: hell|o.world)")
            .expands(to: "(foo: |hello|.world)")
            .expands(to: "(foo: |hello.world|)")
            .expands(to: "(|foo: hello.world|)")
        
        expect(thatThis: "(foo: |hello|.world, bar: hello.world)")
            .expands(to: "(foo: |hello.world|, bar: hello.world)")
            .expands(to: "(|foo: hello.world|, bar: hello.world)")
            .expands(to: "(|foo: hello.world, bar: hello.world|)")
        
        expect(thatThis: "(fo|o: hello(bar: world))")
            .expands(to: "(|foo|: hello(bar: world))")
            .expands(to: "(|foo: hello(bar: world)|)")
        
        expect(thatThis: "(foo: he|llo(bar: world))")
            .expands(to: "(foo: |hello|(bar: world))")
            .expands(to: "(foo: |hello(bar: world)|)")
            .expands(to: "(|foo: hello(bar: world)|)")
        
        expect(thatThis: "(foo: hello(bar: worl|d))")
            .expands(to: "(foo: hello(bar: |world|))")
            .expands(to: "(foo: hello(|bar: world|))")
            .expands(to: "(foo: hello|(bar: world)|)")
            .expands(to: "(foo: |hello(bar: world)|)")
            .expands(to: "(|foo: hello(bar: world)|)")
        expect(thatThis: "this([is, \"a te|st for\"].myCode)")
            .expands(to: "this([is, \"a |test| for\"].myCode)")
            .expands(to: "this([is, \"|a test for|\"].myCode)")
        
        expect(thatThis: "this([is, \"a test fo|r\"].myCode)")
            .expands(to: "this([is, \"a test |for|\"].myCode)")
            .expands(to: "this([is, \"|a test for|\"].myCode)")
            .expands(to: "this([is, |\"a test for\"|].myCode)")
            .expands(to: "this([|is, \"a test for\"|].myCode)")
            .expands(to: "this(|[is, \"a test for\"]|.myCode)")
            .expands(to: "this(|[is, \"a test for\"].myCode|)")
            .expands(to: "this|([is, \"a test for\"].myCode)|")
            .expands(to: "|this([is, \"a test for\"].myCode)|")
        
        expect(thatThis: "this([i|s, \"a test for\"].myCode)")
            .expands(to: "this([|is|, \"a test for\"].myCode)")
            .expands(to: "this([|is, \"a test for\"|].myCode)")
        expect(thatThis: "foo(arg|1: String, arg2: String)")
            .expands(to: "foo(|arg1|: String, arg2: String)")
            .expands(to: "foo(|arg1: String|, arg2: String)")
            .expands(to: "foo(|arg1: String, arg2: String|)")
            .expands(to: "foo|(arg1: String, arg2: String)|")
        expect(thatThis: "foo(arg1: String, |arg2|: String)")
            .expands(to: "foo(arg1: String, |arg2: String|)")
            .expands(to: "foo(|arg1: String, arg2: String|)")
            .expands(to: "foo|(arg1: String, arg2: String)|")
        
        expect(thatThis: "foo(in arg1: String, at |arg2|: String)")
            .expands(to: "foo(in arg1: String, |at arg2: String|)")
            .expands(to: "foo(|in arg1: String, at arg2: String|)")
            .expands(to: "foo|(in arg1: String, at arg2: String)|")
        
        _expect(thatThis: "String(chars[chars.index|(after: second)|..<chars.endIndex])")
            .expands(to: "String(chars[|chars.index(after: second)|..<chars.endIndex])")
            .expands(to: "String(chars[|chars.index(after: second)..<chars.endIndex|])")
            .expands(to: "String(chars|[chars.index(after: second)..<chars.endIndex]|)")
    }
    
    func testPairs_params() {
        assert("(|a|:b,c:d,e:f)" => "(|a:b|,c:d,e:f)")
        assert("(a:|b|,c:d,e:f)" => "(|a:b|,c:d,e:f)")
        assert("(a:b,|c|:d,e:f)" => "(a:b,|c:d|,e:f)")
        assert("(a:b,c:|d|,e:f)" => "(a:b,|c:d|,e:f)")
        assert("(a:b,c:d,|e|:f)" => "(a:b,c:d,|e:f|)")
        assert("(a:b,c:d,e:|f|)" => "(a:b,c:d,|e:f|)")
        
        assert("(|a|: b, c: d, e: f)" => "(|a: b|, c: d, e: f)")
        assert("(a: |b|, c: d, e: f)" => "(|a: b|, c: d, e: f)")
        assert("(a: b, |c|: d, e: f)" => "(a: b, |c: d|, e: f)")
        assert("(a: b, c: |d|, e: f)" => "(a: b, |c: d|, e: f)")
        assert("(a: b, c: d, |e|: f)" => "(a: b, c: d, |e: f|)")
        assert("(a: b, c: d, e: |f|)" => "(a: b, c: d, |e: f|)")
    }
    
    func testPairs_dict() {
        assert("[|a|:b,c:d,e:f]" => "[|a:b|,c:d,e:f]")
        assert("[a:|b|,c:d,e:f]" => "[|a:b|,c:d,e:f]")
        assert("[a:b,|c|:d,e:f]" => "[a:b,|c:d|,e:f]")
        assert("[a:b,c:|d|,e:f]" => "[a:b,|c:d|,e:f]")
        assert("[a:b,c:d,|e|:f]" => "[a:b,c:d,|e:f|]")
        assert("[a:b,c:d,e:|f|]" => "[a:b,c:d,|e:f|]")
        
        assert("[|a|: b, c: d, e: f]" => "[|a: b|, c: d, e: f]")
        assert("[a: |b|, c: d, e: f]" => "[|a: b|, c: d, e: f]")
        assert("[a: b, |c|: d, e: f]" => "[a: b, |c: d|, e: f]")
        assert("[a: b, c: |d|, e: f]" => "[a: b, |c: d|, e: f]")
        assert("[a: b, c: d, |e|: f]" => "[a: b, c: d, |e: f|]")
        assert("[a: b, c: d, e: |f|]" => "[a: b, c: d, |e: f|]")
    }
    
    func testPairs_generics() {
        assert("<|a|:b,c:d,e:f>" => "<|a:b|,c:d,e:f>")
        assert("<a:|b|,c:d,e:f>" => "<|a:b|,c:d,e:f>")
        assert("<a:b,|c|:d,e:f>" => "<a:b,|c:d|,e:f>")
        assert("<a:b,c:|d|,e:f>" => "<a:b,|c:d|,e:f>")
        assert("<a:b,c:d,|e|:f>" => "<a:b,c:d,|e:f|>")
        assert("<a:b,c:d,e:|f|>" => "<a:b,c:d,|e:f|>")
        
        assert("<|a|: b, c: d, e: f>" => "<|a: b|, c: d, e: f>")
        assert("<a: |b|, c: d, e: f>" => "<|a: b|, c: d, e: f>")
        assert("<a: b, |c|: d, e: f>" => "<a: b, |c: d|, e: f>")
        assert("<a: b, c: |d|, e: f>" => "<a: b, |c: d|, e: f>")
        assert("<a: b, c: d, |e|: f>" => "<a: b, c: d, |e: f|>")
        assert("<a: b, c: d, e: |f|>" => "<a: b, c: d, |e: f|>")
    }
    
    func testCase() {
        expect(thatThis: "case (_?, nil|): return .orderedAscending")
            .expands(to: "case (_?, |nil|): return .orderedAscending")
            .expands(to: "case (|_?, nil|): return .orderedAscending")
            .expands(to: "case |(_?, nil)|: return .orderedAscending")
            .expands(to: "|case (_?, nil): return .orderedAscending|")
    }
    
    func testAssign() {
        _expect(thatThis: "let new.line = cu|rrentLine.expandRegion()")
            .expands(to: "let new.line = |currentLine|.expandRegion()")
            .expands(to: "let new.line = |currentLine.expandRegion()|")

        _expect(thatThis: "let ne|w.line = currentLine.expandRegion()")
            .expands(to: "let |new|.line = currentLine.expandRegion()")
            .expands(to: "let |new.line| = currentLine.expandRegion()")
    }
    
}

extension XCLineTests {
    
    @discardableResult
    func assert(_ touple:(initialString: String, expectedString: String), file: String = #file, line: UInt = #line) -> LineTestBuilder {
        let initial = raw(touple.initialString)
        let expected = raw(touple.expectedString)
        let result = Line(raw: initial).expandRegion().raw
        let emoji = result == expected ? " 😃" : " 👿"
        let message = "\(initial.before)|\(initial.selected)|\(initial.after)" +
            " -> " +
            "\(expected.before)|\(expected.selected)|\(expected.after)" +
            emoji +
        "\(result.before)|\(result.selected)|\(result.after)"
        print(message)
        if result != expected {
            recordFailure(withDescription: message, inFile: file, atLine: line, expected: true)
        }
        return LineTestBuilder(string: touple.expectedString, testCase: self)
    }
    
    func raw(_ string: String) -> Line.Raw {
        var chars = string.unicodeScalars
        let first = chars.index(of: "|")!
        let before = String(chars.prefix(upTo: first))
        chars = chars[chars.index(after: first)..<chars.endIndex]
        if let second = chars.index(of: "|") {
            return (
                before,
                String(chars.prefix(upTo: second)),
                String(chars[chars.index(after: second)..<chars.endIndex])
            )
        } else {
            return (
                before,
                "",
                String(chars)
            )
        }
    }
    
    @discardableResult
    func expect(thatThis initial: String) -> LineTestBuilder {
        return LineTestBuilder(string: initial, testCase: self)
    }
    
    /**
     Disabled test
     */
    @discardableResult
    func _expect(thatThis initial: String) -> LineTestBuilder {
        return LineTestBuilder(string: nil, testCase: self)
    }
}

struct LineTestBuilder {
    let string: String?
    let testCase: XCLineTests
    @discardableResult
    func expands(to other: String, file: String = #file, line: UInt = #line) -> LineTestBuilder {
        if let string = string {
            return testCase.assert(string => other, file: file, line: line)
        } else {
            return LineTestBuilder(string: nil, testCase: testCase)
        }
    }
}

infix operator =>
func => (lhs: String, rhs: String) -> (String, String) {
    return (lhs, rhs)
}
