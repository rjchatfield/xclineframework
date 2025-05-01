# Text Selection Range Expander Specification

## Overview
The Text Selection Range Expander is a feature that intelligently expands text selections based on semantic boundaries and content structure. It follows a progressive expansion pattern where each expansion operation grows the selection according to specific rules while maintaining context awareness.

## Core concepts for this document

### Selection Representation
- The `|` character represents either:
  - A cursor position when used singularly (e.g., "hello|")
  - Selection boundaries when used in pairs (e.g., "|hello|")
- Selections can start and end at any position within the text

## Core Concepts

### Expansion Rules

#### 1. Word-Level Expansion
- When a cursor is within or at the edge of a word, expansion selects the entire word
- Example:
  ```
  "h|ello" → "|hello|"
  "hel|l|o" → "|hello|"
  ```

#### 2. Quoted String Expansion
- When selection is within quoted text, expansion progresses through multiple stages:
  1. First expands to the content within quotes
  2. Then includes the quotes themselves
  3. Finally includes any surrounding whitespace if present
- Example:
  ```
  ""h|ello"" → ""|hello|"" → "|"hello"|"
  ```

#### 3. Whitespace Handling
- Leading and trailing whitespace is included in expansions when present
- Example:
  ```
  " |hello " → " |hello| "
  ```

#### 4. Multi-word Expansion
- When dealing with multiple words, expansion happens progressively:
  1. First to the current word
  2. Then to the logical phrase or complete quoted content
  3. Finally to the entire string including quotes
- Example:
  ```
  ""hel|l|o world"" → ""|hello| world"" → ""|hello world|"" → "|"hello world"|"
  ```

## Expansion Behavior

### Single-Character Selection
- When a single character is selected, expansion selects the entire word containing that character
- Example:
  ```
  "hel|l|o" → "|hello|"
  ```

### Cursor Position Expansion
- A single cursor position expands to select the word it's positioned within or adjacent to
- Example:
  ```
  "hello|" → "|hello|"
  ```

### Quote-Aware Expansion
- The expander is aware of quotation marks and treats them as significant boundaries
- Expansion respects quoted strings as discrete units
- Both single and double quotes are supported
- Example:
  ```
  ""|hello"" → ""|hello|"" → "|"hello"|"
  ```

### Progressive Expansion
- Each expansion operation builds upon the previous selection
- The expansion sequence is deterministic and follows a logical progression from smallest to largest semantic unit

## Swift-Specific Syntax Handling

### Collection Types

#### Arrays
- Expansion within arrays follows a hierarchical pattern:
  1. Individual element
  2. Complete array contents
  3. Entire array declaration
- Example:
  ```swift
  [1, 2, |3|, 4] → |[1, 2, 3, 4]|
  ```

#### Nested Arrays
- Expansion respects nested structure:
  ```swift
  [[1, |2|], [3, 4]] → [|[1, 2]|, [3, 4]] → |[[1, 2], [3, 4]]|
  ```

#### Dictionaries
- Expansion handles key-value pairs as units:
  ```swift
  ["key": |value|] → [|"key": value|] → |["key": value]|
  ```

### Function and Type Declarations

#### Function Parameters
- Progressive expansion from parameter type to full function declaration:
  ```swift
  func test(param1: |String|) →
  func test(|param1: String|) →
  |func test(param1: String)| →
  |func test(param1: String) {|
  ```

#### Generic Types
- Handles single and multiple generic parameters:
  ```swift
  Array<|String|> → |Array<String>| → |let array: Array<String>|
  Dictionary<|String|, Int> → Dictionary<|String, Int|> → |Dictionary<String, Int>|
  ```

### Closures and Blocks

#### Simple Closures
- Expands from parameters to complete closure:
  ```swift
  { |param| in → |{ param in| → |{ param in }|
  ```

#### Complex Closures
- Handles capture lists, parameters, and return types:
  ```swift
  { [weak self] (|param1|: String) -> Int in →
  { [weak self] (|param1: String|) -> Int in →
  { [weak self] |(param1: String)| -> Int in →
  { [weak self] |(param1: String) -> Int| in →
  |{ [weak self] (param1: String) -> Int in }|
  ```

### Swift Control Structures

#### Guard Statements
- Expands from value to complete guard statement:
  ```swift
  guard let |value| = optional →
  guard |let value = optional| →
  |guard let value = optional| →
  |guard let value = optional else {|
  ```

#### If Let Statements
- Similar progression to guard statements:
  ```swift
  if let |value| = optional →
  if |let value = optional| →
  |if let value = optional| →
  |if let value = optional {|
  ```

### Type Definitions

#### Protocol Conformance
- Expands from single protocol to complete class declaration:
  ```swift
  class MyClass: |Protocol1| →
  class MyClass: |Protocol1, Protocol2| →
  |class MyClass: Protocol1, Protocol2 {|
  ```

#### Property Declarations
- Handles expansion of property declarations including accessors:
  ```swift
  var name: |String| →
  |var name: String| →
  |var name: String {| →
  |var name: String { get set }|
  ```

#### Enum Cases
- Expands from case name to complete enum declaration:
  ```swift
  case |success|(String) →
  case |success(String)| →
  |case success(String)| →
  |enum Result {
      case success(String)
  }|
  ```

## Edge Cases

### Whitespace Considerations
- Leading and trailing whitespace is preserved during expansion
- Whitespace between words is handled as part of the larger text unit

## Test Implementation Notes

- Tests have been written that enforce this spec in ExpandRegionTests.swift.
- Use `swift test` to verify implementation 

### Test DSL
- Tests use a custom DSL with an `expect` function that takes two closures:
  1. Initial cases: Various starting points that should all expand to the same first expansion
  2. Expansion sequence: The expected progression of expansions
- The DSL supports marking certain cases as skipped using `.skip()`
