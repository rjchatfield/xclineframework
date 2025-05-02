import Testing
@_spi(Testing) import XCLineFramework

/// Test Case Categories:
/// 1. Basic String Cases
///    - Words with/without spaces
///    - Words with quotes
///    - Words with quotes and spaces
/// 2. Swift Syntax Cases
///    - Arrays (basic, nested)
///    - Dictionaries (single, multiple, from key/value)
///    - Functions (parameters, multiple parameters, labeled parameters)
///    - Generics (basic, multiple parameters, complex)
///    - Closures (simple, multiple params, with parentheses)
///    - Other (protocols, properties, chaining)
///
/// Each test verifies selection behavior using string patterns where:
/// - `|` represents cursor position or selection boundaries
/// - Text between two `|` marks represents selected text
/// - Comments trailing each string explain the self assessment of where it is, followed by the expected expansion behavior
///
/// Example: "h|ello" means cursor is between 'h' and 'e'
///         "|hello|" means entire word is selected
///
/// Two types of expect() are used (see method signature for more details):
/// - `expect(eachInitialCase:expandsTo:thenExpandsStepByStepTo:)`
/// - `expect(expandsStepByStep:)`

/// Result builder for constructing test cases with source location tracking
/// This builder enables fluent test case definition while maintaining
/// accurate source location information for error reporting

/// Common Expansion Patterns:
/// 1. Word Selection
///    - Start: Select from cursor to end of word
///    - Middle: Select entire word
///    - End: Select from start of word to cursor
/// 2. Container Selection
///    - First select content
///    - Then select delimiters (quotes, brackets, parentheses)
/// 3. Parameter Selection
///    - First select the word (either name or type)
///    - Then select both the name and type
///    - Then select all parameters

/// When a test fails, check:
/// 1. Word Boundaries
///    - Is the word correctly identified?
///    - Are spaces properly handled?
/// 2. Container Boundaries
///    - Are quotes/brackets/parentheses properly paired?
///    - Is nesting properly handled?
/// 3. Syntax Context
///    - Is the correct syntax node being selected?
///    - Are adjacent tokens properly included/excluded?

/// Adding New Test Cases:
/// 1. Start with basic cases
///    - Single word
///    - Simple containers
/// 2. Add complexity
///    - Nested structures
///    - Mixed syntax
/// 3. Add edge cases
///    - Empty containers
///    - Special characters
///    - Unicode

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

@Test func testBasicArrayFirstElement() {
    expect(
        eachInitialCase: {
            "[|789, 1, 3, 4]" // I'm at the start of an element in an array, I should select the whole element
            "[|7|89, 1, 3, 4]" // I'm at the start of an element in an array, I should select the whole element
            "[7|89, 1, 3, 4]" // I'm in the middle of an element in an array, I should select the whole element
            "[7|8|9, 1, 3, 4]" // I'm in the middle of an element in an array, I should select the whole element
            "[789|, 1, 3, 4]" // I'm at the end of an element in an array, I should select the whole element
            "[78|9|, 1, 3, 4]" // I'm at the end of an element in an array, I should select the whole element
        },
        expandsTo: {
            "[|789|, 1, 3, 4]" // I have selected the whole element in an array, I should select every element in the array
        },
        thenExpandsStepByStepTo: {
            "[|789, 1, 3, 4|]" // I have selected every element in the array, I should select the square brackets too
            "|[789, 1, 3, 4]|" // I have selected the whole array
        }
    )
}

@Test func testBasicArrayMiddleElement() {
    expect(
        eachInitialCase: {
            "[1, |789, 3, 4]" // I'm at the start of an element in an array, I should select the whole element
            "[1, |7|89, 3, 4]" // I'm at the start of an element in an array, I should select the whole element
            "[1, 7|89, 3, 4]" // I'm in the middle of an element in an array, I should select the whole element
            "[1, 7|8|9, 3, 4]" // I'm in the middle of an element in an array, I should select the whole element
            "[1, 789|, 3, 4]" // I'm at the end of an element in an array, I should select the whole element
            "[1, 78|9|, 3, 4]" // I'm at the end of an element in an array, I should select the whole element
        },
        expandsTo: {
            "[1, |789|, 3, 4]" // I have selected the whole element in an array, I should select every element in the array
        },
        thenExpandsStepByStepTo: {
            "[|1, 789, 3, 4|]" // I have selected every element in the array, I should select the square brackets too
            "|[1, 789, 3, 4]|" // I have selected the whole array
        }
    )  
}

@Test func testBasicArrayLastElement() {
    expect(
        eachInitialCase: {
            "[1, |789, 3, 4]" // I'm at the start of an element in an array, I should select the whole element
            "[1, |7|89, 3, 4]" // I'm at the start of an element in an array, I should select the whole element
            "[1, 7|89, 3, 4]" // I'm in the middle of an element in an array, I should select the whole element
            "[1, 7|8|9, 3, 4]" // I'm in the middle of an element in an array, I should select the whole element
            "[1, 789|, 3, 4]" // I'm at the end of an element in an array, I should select the whole element
            "[1, 78|9|, 3, 4]" // I'm at the end of an element in an array, I should select the whole element
        },
        expandsTo: {
            "[1, |789|, 3, 4]" // I have selected the whole element in an array, I should select every element in the array
        },
        thenExpandsStepByStepTo: {
            "[|1, 789, 3, 4|]" // I have selected every element in the array, I should select the square brackets too
            "|[1, 789, 3, 4]|" // I have selected the whole array
        }
    )
}

@Test func testNestedArrays() {
    expect(
        expandsStepByStep: {
            " [[1, |2], [3, 4]] " // I'm at the start of an element in an array, I should select the whole element
            " [[1, |2|], [3, 4]] " // I have selected the whole element in an array, I should select every element in the array
            " [[|1, 2|], [3, 4]] " // I have selected every element in the array, I should select the square brackets too
            " [|[1, 2]|, [3, 4]] " // I have selected the whole element in an array, I should select every element in the array
            " [|[1, 2], [3, 4]|] " // I have selected every element in the array, I should select the square brackets too
            " |[[1, 2], [3, 4]]| " // I have selected the whole array
        }
    )
}

// MARK: - Swift Syntax Cases - Dictionaries

@Test func testDictionarySingle() {
    expect(
        expandsStepByStep: {
            #" ["key": |value] "# // I'm at the start of a word, I should select the word
            #" ["key": |value|] "# // I'm have selected a value in a dictionary, I should select both the key and the value
            #" [|"key": value|] "# // I have selected every key/value pair in the dictionary, I should select the square brackets too
            #" |["key": value]| "# // I have selected the dictionary
        }
    )
}

@Test func testDictionaryMultipleFromValue() {
    expect(
        expandsStepByStep: {
            #" ["key1": value1, "key2": |value2] "# // I'm at the start of a word, I should select the word
            #" ["key1": value1, "key2": |value2|] "# // I'm have selected a value in a dictionary, I should select both the key and the value
            #" ["key1": value1, |"key2": value2|] "# // I have selected a key/value pair in a dictionary, I should select every key/value pair in a dictionary
            #" [|"key1": value1, "key2": value2|] "# // I have selected every key/value pair in a dictionary, I should select the square brackets too
            #" |["key1": value1, "key2": value2]| "# // I have selected the dictionary
        }
    )
}

@Test func testDictionaryMultipleFromKey() {
    expect(
        expandsStepByStep: {
            #" ["key1": value1, "|key2": value2] "# // I'm at the start of a word, I should select the word
            #" ["key1": value1, "|key2|": value2] "# // I am at the edges of the string, I should select the quotes too
            #" ["key1": value1, |"key2"|: value2] "# // I have selected a key in a dictionary, I should select both the key and the value
            #" ["key1": value1, |"key2": value2|] "# // I have selected a key/value pair in a dictionary, I should select every key/value pair in a dictionary
            #" [|"key1": value1, "key2": value2|] "# // I have selected every key/value pair in a dictionary, I should select the square brackets too
            #" |["key1": value1, "key2": value2]| "#
        }
    )
}

@Test func testDictionaryMultipleFromKeyComplex1() {
    expect(
        expandsStepByStep: {
            #" ["foo.bar.baz": value1!, "foo bar baz": val|ue2?.foo, "foo/bar/baz": value3 as AnyObject] "# // I'm in the middle of a word, I should select the word
            #" ["foo.bar.baz": value1!, "foo bar baz": |value2|?.foo, "foo/bar/baz": value3 as AnyObject] "# // I have selected a just word in a value of a Dictionary's key/value pair, I should select the whole value
            #" ["foo.bar.baz": value1!, "foo bar baz": |value2?.foo|, "foo/bar/baz": value3 as AnyObject] "# // I have selected the value of a Dictionary's key/value pair, I should select the key and the value
            #" ["foo.bar.baz": value1!, |"foo bar baz": value2?.foo|, "foo/bar/baz": value3 as AnyObject] "# // I have selected a Dictionary's key/value pair, I should select all the other key/value pairs in the dictionary
            #" [|"foo.bar.baz": value1!, "foo bar baz": value2?.foo, "foo/bar/baz": value3 as AnyObject|] "# // I have selected every key/value pair in the dictionary, I should select the square brackets too
            #" |["foo.bar.baz": value1!, "foo bar baz": value2?.foo, "foo/bar/baz": value3 as AnyObject]| "# // I have selected the dictionary
        }
    )
}

@Test func testDictionaryMultipleFromKeyComplex2() {
    expect(
        expandsStepByStep: {
            #" ["foo.bar.baz": value1!, "foo |bar baz": value2?.foo, "foo/bar/baz": value3 as AnyObject] "# // I'm at the start of a word, I should select the word
            #" ["foo.bar.baz": value1!, "foo |bar| baz": value2?.foo, "foo/bar/baz": value3 as AnyObject] "# // I have selected a just word in a string, I should select the string contents
            #" ["foo.bar.baz": value1!, "|foo bar baz|": value2?.foo, "foo/bar/baz": value3 as AnyObject] "# // I have selected the string contents, I should select the quotes too
            #" ["foo.bar.baz": value1!, |"foo bar baz"|: value2?.foo, "foo/bar/baz": value3 as AnyObject] "# // I have selected the key of a Dictionary's key/value pair, I should select the key and the value
            #" ["foo.bar.baz": value1!, |"foo bar baz": value2?.foo|, "foo/bar/baz": value3 as AnyObject] "# // I have selected a Dictionary's key/value pair, I should select all the other key/value pairs in the dictionary
            #" [|"foo.bar.baz": value1!, "foo bar baz": value2?.foo, "foo/bar/baz": value3 as AnyObject|] "# // I have selected every key/value pair in the dictionary, I should select the square brackets too
            #" |["foo.bar.baz": value1!, "foo bar baz": value2?.foo, "foo/bar/baz": value3 as AnyObject]| "# // I have selected the dictionary
        }
    )
}

@Test func testDictionaryMultipleFromKeyComplex3() {
    expect(
        expandsStepByStep: {
            #" ["foo.bar.baz": value1!, "foo bar baz": value2?.foo, "foo/bar/baz": valu|e3 as? AnyObject] "# // I'm in the middle of a word, I should select the word
            #" ["foo.bar.baz": value1!, "foo bar baz": value2?.foo, "foo/bar/baz": |value3| as? AnyObject] "# // I have selected a word in a value of a Dictionary's key/value pair, I should select the whole value
            #" ["foo.bar.baz": value1!, "foo bar baz": value2?.foo, "foo/bar/baz": |value3 as? AnyObject|] "# // I have selected the value of a Dictionary's key/value pair, I should select the key and the value
            #" ["foo.bar.baz": value1!, "foo bar baz": value2?.foo, |"foo/bar/baz": value3 as? AnyObject|] "# // I have selected a Dictionary's key/value pair, I should select all the other key/value pairs in the dictionary
            #" [|"foo.bar.baz": value1!, "foo bar baz": value2?.foo, "foo/bar/baz": value3 as? AnyObject|] "# // I have selected every key/value pair in the dictionary, I should select the square brackets too
            #" |["foo.bar.baz": value1!, "foo bar baz": value2?.foo, "foo/bar/baz": value3 as? AnyObject]| "# // I have selected the dictionary
        }
    )
}

// MARK: - Swift Syntax Cases - Ternary Operator

@Test func testTernaryOperator1() {
    expect(
        expandsStepByStep: {
            "let result = isVa|lid ? trueValue : falseValue" // I'm in the middle of a word, I should select the word
            "let result = |isValid| ? trueValue : falseValue" // I have selected the condition of the ternary, I should select the whole ternary
            "let result = |isValid ? trueValue : falseValue|" // I have selected the whole assignment value
        }
    )
}

@Test func testTernaryOperator2() {
    expect(
        expandsStepByStep: {
            "let result = isValid ? tru|eValue : falseValue" // I'm in the middle of a word, I should select the word
            "let result = isValid ? |trueValue| : falseValue" // I have selected one value in the ternary, I should select the whole ternary
            "let result = |isValid ? trueValue : falseValue|" // I have selected the whole assignment value
        }
    )
}

@Test func testTernaryOperator3() {
    expect(
        expandsStepByStep: {
            "let result = isValid ? trueValue : fals|eValue" // I'm in the middle of a word, I should select the word
            "let result = isValid ? trueValue : |falseValue|" // I have selected one value in the ternary, I should select the whole ternary
            "let result = |isValid ? trueValue : falseValue|" // I have selected the whole assignment value
        }
    )
}

@Test func testNestedTernaryOperator() {
    expect(
        expandsStepByStep: {
            "let result: MyEnum = isValid ? (hasPermission ? .allow|ed : .denied) : falseValue" // I'm in the middle of a word, I should select the word
            "let result: MyEnum = isValid ? (hasPermission ? .|allowed| : .denied) : falseValue" // I have selected one value in the inner ternary, I should select both values
            "let result: MyEnum = isValid ? (hasPermission ? |.allowed| : .denied) : falseValue" // I have selected one value in the inner ternary, I should select both values
            "let result: MyEnum = isValid ? (|hasPermission ? .allowed : .denied|) : falseValue" // I have selected the inner ternary expression, I should select the parentheses
            "let result: MyEnum = isValid ? |(hasPermission ? .allowed : .denied)| : falseValue" // I have selected one value in the outer ternary, I should select both values
            "let result: MyEnum = |isValid ? (hasPermission ? .allowed : .denied) : falseValue|" // I have selected both values, I should select the outer condition
        }
    )
}

@Test func testTernaryIf1() {
    expect(
        expandsStepByStep: {
            "let result = if isVa|lid { trueValue } else { falseValue }" // I'm in the middle of a word, I should select the word
            "let result = if |isValid| { trueValue } else { falseValue }" // I have selected the condition of the ternary, I should select the whole if statement
            "let result = |if isValid { trueValue } else { falseValue }|".lowCareScore() // I have selected the whole assignment value
        }
    )
}

@Test func testTernaryIf2() {
    expect(
        expandsStepByStep: {
            "let result = if isValid { true|Value } else { falseValue }" // I'm in the middle of a word, I should select the word
            "let result = if isValid { |trueValue| } else { falseValue }" // I have selected one value in the ternary, I should select the whole if statement
            "let result = |if isValid { trueValue } else { falseValue }|".lowCareScore() // I have selected the whole assignment value
        }
    )
}

@Test func testTernaryIf3() {
    expect(
        expandsStepByStep: {
            "let result = if isValid { trueValue } else { f|alseValue }" // I'm in the middle of a word, I should select the word
            "let result = if isValid { trueValue } else { |falseValue| }" // I have selected one value in the ternary, I should select the whole if statement
            "let result = |if isValid { trueValue } else { falseValue }|".lowCareScore() // I have selected the whole assignment value
        }
    )
}


// MARK: - Swift Syntax Cases - Functions

@Test func testFunctionParameters() {
    expect(
        expandsStepByStep: {
            "func test(param1: |String)" // I'm at the start of a word, I should select the word
            "func test(param1: |String|)" // I have selected the type of a parameter, I should select the parameter too because in Swift, parameter names and types form a semantic unit that should be selected together
            "func test(|param1: String|)" // I have selected all the elements of a tuple, I should select the parentheses too
            "func test|(param1: String)|" // I have selected a tuple
        }
    )
}

@Test func testFunctionWithMultipleParameters() {
    expect(
        expandsStepByStep: {
            "foo(arg|1: String, arg2: String)" // I'm in the middle of a word, I should select the word
            "foo(|arg1|: String, arg2: String)" // I have selected the name of the parameter, I should select the type of the parameter too
            "foo(|arg1: String|, arg2: String)" // I have selected an element in the tuple, I should select all the elements of the tuple
            "foo(|arg1: String, arg2: String|)" // I have selected all the elements of the tuple, I should select the parentheses too
            "foo|(arg1: String, arg2: String)|" // I have selected a tuple
        }
    )
}

@Test func testFunctionWithLabeledParameters() {
    expect(
        expandsStepByStep: {
            "foo(in arg1: String, at arg2|: String)" // I'm at the end of a word, I should select the word
            "foo(in arg1: String, at |arg2|: String)" // I have selected the internal argument name of a parameter, I should select the external argument name and type of the parameter
            "foo(in arg1: String, |at arg2: String|)" // I have selected an element in the tuple, I should select all the elements of the tuple
            "foo(|in arg1: String, at arg2: String|)" // I have selected all the elements of the tuple, I should select the parentheses too
            "foo|(in arg1: String, at arg2: String)|" // I have selected a tuple
        }
    )
}

// MARK: - Swift Syntax Cases - Generics

@Test func testGenericType() {
    expect(
        expandsStepByStep: {
            "let array: Array<|String>" // I'm at the start of a word, I should select the word
            "let array: Array<|String|>" // I have selected the all the elements of the generic, I should select the angle brackets too
            "let array: Array|<String>|" // I have selected the generic, I should select the whole type
            "let array: |Array<String>|" // I have selected the whole type
        }
    )
}

@Test func testMultipleGenericParameters() {
    expect(
        expandsStepByStep: {
            "Dictionary<|String, Int>" // I'm at the start of a word, I should select the word
            "Dictionary<|String|, Int>" // I have selected an element in a generic, I should select all of the elements of the generic
            "Dictionary<|String, Int|>" // I have selected all of the elements of a generic, I should select the angle brackets too
            "Dictionary|<String, Int>|" // I have selected the generic, I should select the whole type
            "|Dictionary<String, Int>|" // I have selected the whole type
        }
    )
}

@Test func testComplexGenericType() {
    expect(
        eachInitialCase: {
            "Dictionary<String, Array<|Int>>" // I'm at the start of a word, I should select the word
            "Dictionary<String, Array<I|nt>>" // I'm in the middle of a word, I should select the word
            "Dictionary<String, Array<Int|>>" // I'm at the end of a word, I should select the word
        },
        expandsTo: {
            "Dictionary<String, Array<|Int|>>" // I have selected all the elements of a generic, I should select the angle brackets too
        },
        thenExpandsStepByStepTo: {
            "Dictionary<String, Array|<Int>|>" // I have selected the generic, I should select the whole type
            "Dictionary<String, |Array<Int>|>" // I have selected an element in a generic, I should select all of the elements of the generic
            "Dictionary<|String, Array<Int>|>" // I have selected all of the elements of a generic, I should select the angle brackets too
            "Dictionary|<String, Array<Int>>|" // I have selected the generic, I should select the whole type
            "|Dictionary<String, Array<Int>>|" // I have selected the whole type
        }
    )
}

// MARK: - Swift Syntax Cases - Closures

@Test func testSimpleClosure() {
    expect(
        expandsStepByStep: {
            "{ |param in" // I'm at the start of a word, I should select the word
            "{ |param| in" // I have selected all of the parameters in the closure, I should select the `in` keyword to
            "{ |param in|" // I have selected the `in` keyword
        }
    )
}

@Test func testClosureWithMultipleParams() {
    expect(
        expandsStepByStep: {
            "{ param, |p2 in" // I'm at the start of a word, I should select the word
            "{ param, |p2| in" // I have selected the second parameter, I should select all the parameters of the closure
            "{ |param, p2| in" // I have selected all the parameters of the closure, I should select the `in` keyword too
            "{ |param, p2 in|" // I have selected the `in` keyword
        }
    )
}

@Test func testClosureWithParentheses() {
    expect(
        expandsStepByStep: {
            "{ (param, |p2) in" // I'm at the start of a word, I should select the word
            "{ (param, |p2|) in" // I have selected the second parameter, I should select all the parameters of the closure
            "{ (|param, p2|) in" // I have selected all the parameters of the closure, I should select the parentheses too
            "{ |(param, p2)| in" // I have selected the whole closure, I should select the `in` keyword too
            "{ |(param, p2) in|" // I have selected the `in` keyword
        }
    )
}

@Test func testClosureWithParenthesesAndExplicitTypes() {
    expect(
        expandsStepByStep: {
            "{ (param: String, |p2: String) -> Bool in" // I'm at the start of a word, I should select the word
            "{ (param: String, |p2|: String) -> Bool in" // I have selected the name of the second parameter, I should select the type of the second parameter too
            "{ (param: String, |p2: String|) -> Bool in" // I have selected a key/value element of a tuple, I should select all of the elements of the tuple
            "{ (|param: String, p2: String|) -> Bool in" // I have selected all the elements of a tuple, I should select the parentheses too
            "{ |(param: String, p2: String)| -> Bool in" // I have selected the arguments of the closure, I should select the return type too
            "{ |(param: String, p2: String) -> Bool| in" // I have selected the return type of the closure, I should select the `in` keyword too
            "{ |(param: String, p2: String) -> Bool in|" // I have selected the `in` keyword
        }
    )
}

 @Test func testComplexClosure() {
     expect(
         expandsStepByStep: {
             "{ [weak self] (foo: (S|tring) -> Int) -> Bool in" // I'm in the middle of a word, I should select the word
             "{ [weak self] (foo: (|String|) -> Int) -> Bool in" // I have selected all the elements of a tuple, I should select the parentheses too
             "{ [weak self] (foo: |(String)| -> Int) -> Bool in".lowCareScore() // I have selected the arguments of a closure, I should select the return type too
             "{ [weak self] (foo: |(String) -> Int|) -> Bool in".lowCareScore() // I have selected the type of an argument, I should select the name of the argument too
             "{ [weak self] (|foo: (String) -> Int|) -> Bool in".lowCareScore() // I have selected all the key/value elements of a tuple, I should select the parentheses too
             "{ [weak self] |(foo: (String) -> Int)| -> Bool in".lowCareScore() // I have selected the arguments of a closure, I should select the return type too
             "{ [weak self] |(foo: (String) -> Int) -> Bool| in".lowCareScore() // I have selected the type signature of a closure, I  should select the capture list and `in` keyword too
             "{ |[weak self] (foo: (String) -> Int) -> Bool in|".lowCareScore() // I have selected the `in` keyword
         }
     )
 }

// MARK: - Swift Syntax Cases - Other

@Test func testProtocolConformance() {
    expect(
        expandsStepByStep: {
            "class MyClass: Prot|ocol1, Protocol2 {" // I'm in the middle of a word, I should select the word
            "class MyClass: |Protocol1|, Protocol2 {" // I have selected the first protocol, I should select all of the protocols too
        }
    )
}

@Test func testPropertyDeclaration() {
    expect(
        expandsStepByStep: {
            " var name: |String " // I'm at the start of a word, I should select the word
            " var name: |String| " // I have selected the type of the property, I should select the name of the property too
            " var |name: String| ".lowCareScore() // I have selected the name and type of the property, I should select the `var` keyword too
            " |var name: String| ".lowCareScore() // I have selected the whole line
        }
    )
}

@Test func testChainingFromEnd() {
    expect(
        expandsStepByStep: {
            " value.optional.va|lue " // I'm in the middle of a word, I should select the word
            " value.optional.|value| " // I have selected the property at the end of the chain, I should select the `.` before it too
            " value.optional|.value| " // I have selected the dot and property at the end of the chain, I should select property before it too up to the `.`
            " value.|optional.value| " // I have selected the properties at the end of the chain, I should select the `.` before it too.
            " value|.optional.value| " // I have selected the dot and all the properties to the end of the chain, I should select instance variable too
            " |value.optional.value| " // I have selected the whole expression
        }
    )
}

@Test func testChainingOptionalsFromEnd() {
    expect(
        expandsStepByStep: {
            " value?.optional?.va|lue " // I'm in the middle of a word, I should select the word
            " value?.optional?.|value| " // I have selected the property at the end of the chain, I should select the `?.` before it too.
            " value?.optional|?.value| " // I have selected the dot and property at the end of the chain, I should select property before it too up to the `?.`
            " value?.|optional?.value| " // I have selected the properties at the end of the chain, I should select the `?.` before it too.
            " value|?.optional?.value| " // I have selected the dot and all the properties to the end of the chain, I should select instance variable too
            " |value?.optional?.value| " // I have selected the whole expression
        }
    )
}

@Test func testGuardStatement() {
    expect(
        expandsStepByStep: {
            "guard let |value = optional as? AnyObject" // I'm at the start of a word, I should select the word
            "guard let |value| = optional as? AnyObject" // I have selected the name of the variable
        }
    )
}

@Test func testGuardStatementWithOptionalChaining() {
    expect(
        expandsStepByStep: {
            "guard let value = optional?.v|alue as? AnyObject," // I'm in the middle of a word, I should select the word
            "guard let value = optional?.|value| as? AnyObject," // I have selected an ivar of an optional, I should select the leading `?.` too
            "guard let value = optional|?.value| as? AnyObject," // I have selected the chained logic of an optional, I should select the original variable too
            "guard let value = |optional?.value| as? AnyObject," // I have selected the value, I should select the whole assignment expression
            "guard let value = |optional?.value as? AnyObject|," // I have selected the assignment expression on the left of an =
        }
    )
}

@Test func testIfLetStatement() {
    expect(
        expandsStepByStep: {
            "if let value = optional?.v|alue as? AnyObject," // I'm in the middle of a word, I should select the word
            "if let value = optional?.|value| as? AnyObject," // I have selected the name of the ivar, I should select the `?.` too
            "if let value = optional|?.value| as? AnyObject," // I have selected the chained logic of an optional, I should select the original variable too
            "if let value = |optional?.value| as? AnyObject," // I have selected the value, I should select the whole assignment expression
            "if let value = |optional?.value as? AnyObject|," // I have selected the assignment expression on the left of an =
        }
    )
}

@Test func testSwitchCase() {
    expect(
        expandsStepByStep: {
            " case .su|ccess: break " // I'm in the middle of a word, I should select the word
            " case .|success|: break " // I have selected the name of the enum case, I should select the `.` too
            " case |.success|: break " // I have selected the name of the enum case
        }
    )
}

@Test func testEnumDeclaration() {
    expect(
        expandsStepByStep: {
            " case suc|cess(String) " // I'm in the middle of a word, I should select the word
            " case |success|(String) " // I have selected the name of the enum case, I should select the associated value too
            " case |success(String)| ".lowCareScore() // I have selected the enum case, I should select the `case` keyword too
            " |case success(String)| ".lowCareScore() // I have selected the whole enum case
        }
    )
}

// MARK: - Helper Functions

/// Tests that a selection expands step by step through the expected states.
///
/// This helper function tests that when repeatedly expanding a selection, it progresses through
/// each of the expected states in sequence. It takes an array of expected states and verifies
/// that the first expansion matches the first state, then subsequent expansions match the remaining states.
///
/// Testing Strategy:
/// 1. Verify initial selection expands to first expected state
/// 2. For each subsequent state:
///    - Take the previous state as input
///    - Verify expansion matches next expected state
///    - Continue until all states are verified
///
/// - Parameters:
///   - expectations: A closure returning an array of `TestInfo` representing the expected selection states
///   - sourceLocation: The source location where this test is being called from, used for error reporting
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

/// Tests that a selection expands through multiple expected states.
///
/// This helper function tests the expansion behavior in three phases:
/// 1. Initial cases: Tests that multiple different initial selections all expand to the same first expected state
/// 2. First expansion: Verifies that the initial selections expand to match this expected state
/// 3. Subsequent expansions: Tests that further expansions match the sequence of expected states
///
/// - Parameters:
///   - initialCases: A closure returning an array of String litterals representing different initial selection states to test
///   - firstExpansion: A closure returning a String litteral representing the expected state after first expansion
///   - subsequentExpansions: A closure returning an array of String litterals representing subsequent expected expansion states
///   - sourceLocation: The source location where this test is being called from, used for error reporting
private func expect(
    @LineTestResultBuilder eachInitialCase initialCases: () -> [TestInfo],
    @LineTestResultBuilder expandsTo firstExpansion: () -> TestInfo,
    @LineTestResultBuilder thenExpandsStepByStepTo subsequentExpansions: () -> [TestInfo] = { [] },
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let initialCases = initialCases()
    let initialExpandsTo = firstExpansion()
    let thenExpandsStepByStep = subsequentExpansions()

    // Test all initial cases
    for initialCase in initialCases {
        print("")
        let initial = Buffer(testString: initialCase.string)
        let expected = Buffer(testString: initialExpandsTo.string)
        print(" 🤔\(initial.rawDescription) -> \(expected.rawDescription)")
        var mutableInitial = initial
        let result = mutableInitial.expandedSelection()
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
    func lowCareScore(sourceLocation: SourceLocation = #_sourceLocation) -> TestInfo {
        TestInfo(string: self, skip: true, sourceLocation: sourceLocation)
    }
}
