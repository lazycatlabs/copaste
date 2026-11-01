import Testing
@testable import ReCopy

struct TextFormatterTests {
    @Test(arguments: [
        (#"{"b": 1, "a": [true, null]}"#, CodeLanguage.json),
        ("<html><body><p>Hi</p></body></html>", .html),
        ("<note><to>Tove</to></note>", .xml),
        ("import SwiftUI\n\nstruct ContentView: View {\n    var body: some View { Text(\"Hi\") }\n}", .swift),
        ("struct ContentView: View {\n    var body: some View {\n        Text(\"Hello\")\n    }\n}", .swift),
        ("a:hover, .nav > li {\n  color: red;\n}", .css),
        ("import 'package:flutter/material.dart';\nimport 'package:flutter_bloc/flutter_bloc.dart';", .dart),
        ("class App extends StatelessWidget {\n  @override\n  Widget build(BuildContext context) {\n"
            + "    return MaterialApp(\n      home: Text('Hi'),\n    );\n  }\n}", .dart),
        ("def greet(name):\n    print(f\"Hi {name}\")\n", .python),
        ("const total = items.reduce((sum, x) => {\n  return sum + x;\n}, 0);", .javascript),
        ("package main\n\nfunc main() {\n    fmt.Println(\"hi\")\n}", .go),
        ("fn main() {\n    let mut x = 1;\n    println!(\"{}\", x);\n}", .rust),
        ("#include <stdio.h>\nint main() {\n    printf(\"hi\");\n}", .c),
        ("SELECT id, name\nFROM users\nWHERE active = 1;", .sql),
        (".card {\n  color: red;\n  padding: 4px;\n}", .css),
        ("git status", .shell),
        ("```swift\nlet a = 1\n```", .swift),
        ("```yaml\na: 1\n```", .other),
        ("brew install --cask recopy", .shell),
        ("if (a) {\n  b();\n}", .other),
    ])
    func detectsCode(text: String, language: CodeLanguage) {
        #expect(TextFormatter.language(of: text) == language)
    }

    @Test(arguments: [
        "Hello, see you tomorrow.",
        "Meeting at 5 (room 3)",
        "Dear team,\n\nThe release is ready. Please check it before Friday.\n\nThanks!",
        "Shopping list:\n- milk\n- eggs",
        "Dear team,\nThanks for the update,\nsee you soon",
        "{not json at all",
    ])
    func leavesProseAlone(text: String) {
        #expect(TextFormatter.language(of: text) == nil)
    }

    @Test func prettyPrintsJSONKeepingKeyOrderAndNumbers() {
        let json = #"{"z":1.0,"a":[1,2,{}],"s":"a, b: {c}","e":[],"n":{"x":"q\"}"}}"#
        #expect(TextFormatter.json(json, pretty: true) == """
        {
          "z": 1.0,
          "a": [
            1,
            2,
            {}
          ],
          "s": "a, b: {c}",
          "e": [],
          "n": {
            "x": "q\\"}"
          }
        }
        """)
    }

    @Test func minifiesJSON() {
        let json = "{\n  \"a\" : [ 1, 2 ],\n  \"b\" : \"x y\"\n}"
        #expect(TextFormatter.json(json, pretty: false) == #"{"a":[1,2],"b":"x y"}"#)
        #expect(TextFormatter.json("not json", pretty: false) == nil)
    }

    @Test func tidiesIndentationAndBlankLines() {
        let text = "\n\n    func a() {   \r\n        b()\t\n\n\n\n    }\n  \n"
        #expect(TextFormatter.tidy(text) == "func a() {\n    b()\n\n}")
    }

    @Test func wrapsInACodeFenceLongerThanAnyInside() {
        #expect(TextFormatter.codeBlock("let a = 1\n", tag: "swift") == "```swift\nlet a = 1\n```")
        #expect(TextFormatter.codeBlock("a ``` b", tag: "") == "````\na ``` b\n````")
    }

    @Test func opensExistingCodeBlocks() {
        #expect(TextFormatter.unfenced("```yaml\na: 1\nb: 2\n```")! == ("a: 1\nb: 2", "yaml"))
        #expect(TextFormatter.unfenced("````csharp\n```cpp\nint a;\n```\n````")! == ("int a;", "csharp"),
                "Nested blocks are all opened; the outer tag wins")
        #expect(TextFormatter.unfenced("```\nx\n```")! == ("x", ""))
        #expect(TextFormatter.unfenced("```swift\nlet a = 1") == nil, "Not closed")
        #expect(TextFormatter.unfenced("Use ``` for code") == nil)
        #expect(TextFormatter.unfenced("```swift\na\n```\nText\n```python\nb\n```") == nil, "Two blocks aren't one")
        #expect(TextFormatter.unfenced("```swift\nlet a = 1\n````")! == ("let a = 1", "swift"), "A longer closing fence")
        #expect(TextFormatter.unfenced("```swift\nlet a = 1\n    ```") == nil, "Backticks indented four spaces are code")
        #expect(TextFormatter.language(of: "```\nimport SwiftUI\n```") == .swift, "An untagged block: its code decides")
        #expect(TextFormatter.languageName(.other, of: "```yaml\na: 1\n```") == "YAML", "The block's own tag names it")
        #expect(TextFormatter.languageName(.other, of: "```cpp\nint a;\n```") == "C++")
        #expect(TextFormatter.languageName(.other, of: "```zig\nconst a = 1;\n```") == "zig", "An unlisted tag as it is")
        #expect(TextFormatter.languageName(.swift, of: "```swift\nlet a = 1\n```") == "Swift")
    }

    @Test func rewrappingACodeBlockReplacesItsLanguage() {
        let model = TextPasteSpecialModel(items: [], text: "````csharp\n```cpp\ntargets:\n  a: 1\n```\n````")
        #expect(model.options.style == .codeBlock && model.options.fenceTag == "csharp")
        #expect(model.detectedName == "C#")
        #expect(model.result == "```csharp\ntargets:\n  a: 1\n```", "One block, not three")

        model.options.fenceTag = "yaml"
        #expect(model.result == "```yaml\ntargets:\n  a: 1\n```")
        model.options.style = .plain
        #expect(model.result == "targets:\n  a: 1", "Plain text is the code alone")
    }

    @Test func findsFenceLanguagesByNameTagOrAlias() {
        #expect(FenceLanguage.matching("").count == FenceLanguage.all.count)
        #expect(FenceLanguage.matching("ts").first?.tag == "typescript", "An exact alias before names starting with it (TSX)")
        #expect(FenceLanguage.matching("RUB").map(\.tag) == ["ruby"])
        #expect(FenceLanguage.matching("script").map(\.tag) == ["javascript", "typescript"])
        #expect(FenceLanguage.matching("zzz").isEmpty)
        #expect(CodeLanguage.allCases.filter { $0 != .other }.allSatisfy { FenceLanguage.named($0.fenceTag) != nil },
                "Every detected language can be picked")
    }

    @Test func picksDefaultsFromWhatWasCopied() {
        let model = TextPasteSpecialModel(items: [], text: #"{"a":1}"#)
        #expect(model.options == TextPasteOptions(reformat: .prettyJSON, style: .plain, fenceTag: "json"))
        #expect(model.result == "{\n  \"a\": 1\n}")
        #expect(model.reformats.contains(.minifyJSON))

        model.options.style = .codeBlock
        #expect(model.result == "```json\n{\n  \"a\": 1\n}\n```")

        let prose = TextPasteSpecialModel(items: [], text: "  Hello  \n  world")
        #expect(prose.language == nil && prose.options.style == .plain)
        #expect(prose.result == "Hello\nworld")
        #expect(!prose.reformats.contains(.prettyJSON))
    }
}
