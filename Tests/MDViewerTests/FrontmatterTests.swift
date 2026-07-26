import Testing
@testable import MDViewer

struct FrontmatterTests {

    /// Verifies a well-formed block with three scalar keys yields three entries in document
    /// order, and the body starts at the first content line after the closing fence.
    @Test func wellFormedBlockThreeScalarKeys() throws {
        let text = """
        ---
        title: Hello
        author: Pierre
        tags: test
        ---
        # Heading

        Body text.
        """

        let (frontmatter, body) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        #expect(entries.count == 3)
        #expect(entries[0].key == "title" && entries[0].value == "Hello")
        #expect(entries[1].key == "author" && entries[1].value == "Pierre")
        #expect(entries[2].key == "tags" && entries[2].value == "test")
        #expect(body.hasPrefix("# Heading"))
    }

    /// Verifies a document with no frontmatter (first line is a heading) returns nil and the
    /// body is byte-identical to the input.
    @Test func noFrontmatterReturnsNilAndUnmodifiedBody() {
        let text = """
        # Heading

        Some text.
        """

        let (frontmatter, body) = FrontmatterParser.split(text)

        #expect(frontmatter == nil)
        #expect(body == text)
    }

    /// Verifies an opening fence with no closing fence is not treated as frontmatter and
    /// nothing is swallowed from the body.
    @Test func unterminatedFenceReturnsNilAndUnmodifiedBody() {
        let text = """
        ---
        title: Hello
        Some more text without a closing fence
        """

        let (frontmatter, body) = FrontmatterParser.split(text)

        #expect(frontmatter == nil)
        #expect(body == text)
    }

    /// Verifies a `---` line that is not on line 0 is not treated as a frontmatter fence and is
    /// left for the Markdown renderer to treat as a thematic break.
    @Test func dashesNotOnLineZeroIsNotAFence() {
        let text = """
        Intro line
        ---
        title: Hello
        ---
        """

        let (frontmatter, body) = FrontmatterParser.split(text)

        #expect(frontmatter == nil)
        #expect(body == text)
    }

    /// Verifies a closing fence of `...` is parsed identically to a closing fence of `---`.
    @Test func closingFenceDotDotDotParsedLikeDashes() throws {
        let text = """
        ---
        title: Hello
        ...
        Body
        """

        let (frontmatter, body) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        #expect(entries.count == 1)
        #expect(entries[0].key == "title" && entries[0].value == "Hello")
        #expect(body == "Body")
    }

    /// Verifies single- and double-quoted values have their surrounding quotes stripped.
    @Test func quotedValuesHaveQuotesStripped() throws {
        let text = """
        ---
        key1: 'a'
        key2: "b"
        ---
        Body
        """

        let (frontmatter, _) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        #expect(entries[0].value == "a")
        #expect(entries[1].value == "b")
    }

    /// Verifies an inline flow sequence (`tags: [a, b]`) is flattened to a comma-joined value.
    @Test func inlineFlowSequenceFlattened() throws {
        let text = """
        ---
        tags: [a, b]
        ---
        Body
        """

        let (frontmatter, _) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        #expect(entries[0].key == "tags")
        #expect(entries[0].value == "a, b")
    }

    /// Verifies an indented block sequence (`tags:` followed by `- a` / `- b`) is flattened to a
    /// comma-joined value.
    @Test func blockSequenceFlattened() throws {
        let text = """
        ---
        tags:
          - a
          - b
        ---
        Body
        """

        let (frontmatter, _) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        #expect(entries[0].key == "tags")
        #expect(entries[0].value == "a, b")
    }

    /// Verifies a value containing a colon (a URL) is split on the first colon only.
    @Test func valueContainingColonSplitsOnFirstColonOnly() throws {
        let text = """
        ---
        url: https://x.co/y
        ---
        Body
        """

        let (frontmatter, _) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        #expect(entries[0].key == "url")
        #expect(entries[0].value == "https://x.co/y")
    }

    /// Verifies a value containing Markdown syntax is retained verbatim, not interpreted.
    @Test func markdownInValueRetainedVerbatim() throws {
        let text = """
        ---
        title: **b**
        ---
        Body
        """

        let (frontmatter, _) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        #expect(entries[0].value == "**b**")
    }

    /// Verifies an empty block (`---` immediately followed by `---`) strips the fences from the
    /// body and yields empty frontmatter, so no table is rendered.
    @Test func emptyBlockStripsFencesNoEntries() throws {
        let text = """
        ---
        ---
        Body
        """

        let (frontmatter, body) = FrontmatterParser.split(text)

        let fm = try #require(frontmatter)
        #expect(fm.isEmpty)
        #expect(body == "Body")
    }

    /// Verifies four dashes on line 0 is not recognized as a fence.
    @Test func fourDashesIsNotAFence() {
        let text = """
        ----
        title: Hello
        ----
        """

        let (frontmatter, body) = FrontmatterParser.split(text)

        #expect(frontmatter == nil)
        #expect(body == text)
    }

    /// Verifies CRLF line endings are normalized before scanning, and no stray `\r` leaks into
    /// keys or values.
    @Test func crlfLineEndingsParsedIdenticallyToLF() throws {
        let text = "---\r\ntitle: Hello\r\n---\r\nBody\r\n"

        let (frontmatter, _) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        #expect(entries[0].key == "title")
        #expect(entries[0].value == "Hello")
        #expect(!entries[0].key.contains("\r"))
        #expect(!entries[0].value.contains("\r"))
    }

    /// Validation gate: verifies prose with no colons between two fences is rejected as
    /// frontmatter, so no content is lost.
    @Test func validationGateRejectsColonlessProse() {
        let text = """
        ---
        This is just prose.
        No colons here.
        ---
        """

        let (frontmatter, body) = FrontmatterParser.split(text)

        #expect(frontmatter == nil)
        #expect(body == text)
    }

    /// Validation gate: verifies a heading inside the fenced block is rejected as frontmatter,
    /// so the body (and therefore the outline) is unaffected.
    @Test func validationGateRejectsHeadingInBlock() {
        let text = """
        ---
        # Title
        key: value
        ---
        """

        let (frontmatter, body) = FrontmatterParser.split(text)

        #expect(frontmatter == nil)
        #expect(body == text)
    }

    /// Verifies an empty-value key (`aliases:`) is kept as an entry with an empty string value,
    /// not dropped.
    @Test func emptyValueKeyKeptWithEmptyString() throws {
        let text = """
        ---
        aliases:
        title: Test
        ---
        Body
        """

        let (frontmatter, _) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        let aliases = try #require(entries.first { $0.key == "aliases" })
        #expect(aliases.value == "")
    }

    /// Verifies a blank line inside an otherwise valid block does not break parsing; it is
    /// simply ignored.
    @Test func blankLineInsideBlockIgnored() throws {
        let text = """
        ---
        title: Hello

        tags: test
        ---
        Body
        """

        let (frontmatter, _) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        #expect(entries.count == 2)
        #expect(entries[0].key == "title" && entries[0].value == "Hello")
        #expect(entries[1].key == "tags" && entries[1].value == "test")
    }

    /// Verifies a block scalar (`desc: |` with indented continuation) degrades to a literal
    /// `|` value with the continuation ignored, and does not crash.
    @Test func blockScalarDegradesToLiteralPipe() throws {
        let text = """
        ---
        desc: |
          Line one
          Line two
        ---
        Body
        """

        let (frontmatter, _) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        #expect(entries.count == 1)
        #expect(entries[0].key == "desc")
        #expect(entries[0].value == "|")
    }

    /// Verifies a frontmatter-only document (no body content) still parses its entries, and the
    /// body is empty or whitespace-only.
    @Test func frontmatterOnlyDocumentEmptyBody() throws {
        let text = """
        ---
        title: Hello
        ---
        """

        let (frontmatter, body) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        #expect(entries.count == 1)
        #expect(body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    /// Verifies duplicate keys are both retained, in document order (display fidelity over
    /// YAML last-wins semantics).
    @Test func duplicateKeysBothRetainedInOrder() throws {
        let text = """
        ---
        tag: a
        tag: b
        ---
        Body
        """

        let (frontmatter, _) = FrontmatterParser.split(text)

        let entries = try #require(frontmatter?.entries)
        #expect(entries.count == 2)
        #expect(entries[0].key == "tag" && entries[0].value == "a")
        #expect(entries[1].key == "tag" && entries[1].value == "b")
    }

    /// Regression: parsedSections() on a frontmatter-stripped body produces sections identical
    /// (count, id, level, title, content) to the same document authored without frontmatter.
    @Test func parsedSectionsRegressionMatchesHandStrippedDocument() {
        let withFrontmatter = """
        ---
        title: Hello
        author: Pierre
        ---
        # Heading One

        Some text.

        ## Heading Two

        More text.
        """

        let withoutFrontmatter = """
        # Heading One

        Some text.

        ## Heading Two

        More text.
        """

        let (_, body) = FrontmatterParser.split(withFrontmatter)
        let strippedSections = body.parsedSections()
        let referenceSections = withoutFrontmatter.parsedSections()

        #expect(strippedSections.count == referenceSections.count)
        for (a, b) in zip(strippedSections, referenceSections) {
            #expect(a.id == b.id)
            #expect(a.level == b.level)
            #expect(a.title == b.title)
            #expect(a.content == b.content)
        }
    }
}
