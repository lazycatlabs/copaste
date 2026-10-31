import Testing
@testable import Copaste

struct TextFormatterTests {
    @Test(arguments: [
        (#"{"b": 1, "a": [true, null]}"#, CodeLanguage.json),
        ("<html><body><p>Hi</p></body></html>", .html),
        ("<note><to>Tove</to></note>", .xml),
        ("import SwiftUI\n\nstruct ContentView: View {\n    var body: some View { Text(\"Hi\") }\n}", .swift),
        ("struct ContentView: View {\n    var body: some View {\n        Text(\"Hello\")\n    }\n}", .swift),
        ("a:hover, .nav > li {\n  color: red;\n}", .css),
        ("def greet(name):\n    print(f\"Hi {name}\")\n", .python),
        ("const total = items.reduce((sum, x) => {\n  return sum + x;\n}, 0);", .javascript),
        ("package main\n\nfunc main() {\n    fmt.Println(\"hi\")\n}", .go),
        ("fn main() {\n    let mut x = 1;\n    println!(\"{}\", x);\n}", .rust),
        ("#include <stdio.h>\nint main() {\n    printf(\"hi\");\n}", .c),
        ("SELECT id, name\nFROM users\nWHERE active = 1;", .sql),
        (".card {\n  color: red;\n  padding: 4px;\n}", .css),
        ("git status", .shell),
        ("brew install --cask copaste", .shell),
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
        #expect(TextFormatter.codeBlock("let a = 1\n", language: .swift) == "```swift\nlet a = 1\n```")
        #expect(TextFormatter.codeBlock("a ``` b", language: .other) == "````\na ``` b\n````")
        #expect(TextFormatter.codeBlock("x", language: nil) == "```\nx\n```")
    }

    @Test func picksDefaultsFromWhatWasCopied() {
        let model = TextPasteSpecialModel(items: [], text: #"{"a":1}"#)
        #expect(model.options == TextPasteOptions(reformat: .prettyJSON, style: .plain))
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
