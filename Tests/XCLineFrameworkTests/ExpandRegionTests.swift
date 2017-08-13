import XCTest
@testable import XCLineFramework

final class ExpandRegionTests: XCTestCase {
    
    /// For Linux tests
    static var allTests : [(String, (ExpandRegionTests) -> () throws -> Void)] {
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
        
        expect(thatThis: "[[[]], [[|]], [[]]]")
            .expands(to: "[[[]], [|[]|], [[]]]")
            .expands(to: "[[[]], |[[]]|, [[]]]")
            ._expands(to: "[|[[]], [[]], [[]]|]")
            .expands(to: "|[[[]], [[]], [[]]]|")
        
        assert("[[\"hello\"], |[]|]" => "[|[\"hello\"], []|]")
    }
    
    func testDictionary() {
        assert(" [|hello:| world] " => " [|hello: world|] ")
        assert(" [hello|:| world] " => " [|hello: world|] ")
        assert(" [hello|: world|] " => " [|hello: world|] ")
        assert(" [hello: |world|] " => " [|hello: world|] ")
        expect(thatThis: "        \"|[\": \"]\",")
            ._expands(to: "        \"|[|\": \"]\",")
            .expands(to: "        |\"[\"|: \"]\",")
            ._expands(to: "        |\"[\": \"]\"|,")
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
        
        expect(thatThis: "String(chars[chars.index|(after: second)|..<chars.endIndex])")
            ._expands(to: "String(chars[|chars.index(after: second)|..<chars.endIndex])")
            ._expands(to: "String(chars[|chars.index(after: second)..<chars.endIndex|])")
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
        expect(thatThis: "let new.line = cu|rrentLine.expandRegion()")
            .expands(to: "let new.line = |currentLine|.expandRegion()")
            ._expands(to: "let new.line = |currentLine.expandRegion()|")
        
        expect(thatThis: "let ne|w.line = currentLine.expandRegion()")
            .expands(to: "let |new|.line = currentLine.expandRegion()")
            ._expands(to: "let |new.line| = currentLine.expandRegion()")
    }
    
    func testFunctionType() {
        expect(thatThis: "func foo(f: @escaping (H|ello) -> World) -> Boom")
            .expands(to: "func foo(f: @escaping (|Hello|) -> World) -> Boom")
            .expands(to: "func foo(f: @escaping |(Hello)| -> World) -> Boom")
            ._expands(to: "func foo(f: |@escaping (Hello) -> World|) -> Boom")
            .expands(to: "func foo(|f: @escaping (Hello) -> World|) -> Boom")
            .expands(to: "func foo|(f: @escaping (Hello) -> World)| -> Boom")
    }
    
}

extension ExpandRegionTests {
    
    @discardableResult
    func assert(_ touple: (initialString: String, expectedString: String), ignored: Bool = false, file: StaticString = #file, line: UInt = #line) -> LineTestBuilder {
        let initial = Line(testString: touple.initialString)
        let expected = Line(testString: touple.expectedString)
        let result = initial.expandedRegion()
        let emoji = ignored ? "🐛" : result == expected ? " 😃" : " 👿"
        let message = "\(initial.rawDescription) -> \(expected.rawDescription) \(emoji) \(result.rawDescription)"
        print(message)
        XCTAssert(ignored || result == expected, message, file: file, line: line)
        return LineTestBuilder(string: touple.expectedString, testCase: self)
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
    let testCase: ExpandRegionTests
    @discardableResult
    func expands(to other: String, ignored: Bool = false, file: StaticString = #file, line: UInt = #line) -> LineTestBuilder {
        if let string = string {
            return testCase.assert(string => other, ignored: ignored, file: file, line: line)
        } else {
            return LineTestBuilder(string: nil, testCase: testCase)
        }
    }
    
    @discardableResult
    func _expands(to other: String, file: StaticString = #file, line: UInt = #line) -> LineTestBuilder {
        return expands(to: other, ignored: true, file: file, line: line)
    }
}

infix operator =>
func => (lhs: String, rhs: String) -> (String, String) {
    return (lhs, rhs)
}
