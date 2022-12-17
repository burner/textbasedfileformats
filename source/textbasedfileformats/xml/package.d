module textbasedfileformats.xml;

public import textbasedfileformats.xml.dom;
public import domimpl = textbasedfileformats.xml.domimpl;
public import textbasedfileformats.xml.domparser;
public import textbasedfileformats.xml.sax;
public import textbasedfileformats.xml.writer;
public import textbasedfileformats.xml.cursor;
public import textbasedfileformats.xml.lexers;
public import textbasedfileformats.xml.parser;

/++ This function parses a string `input`
+ into `Document`
+
+ Params:
+   input = The `string` to parse
+
+ Returns:
+   The parsed xml `Document`
+/
Document parseXMLString(string input)
{
    auto builder =
             input
            .lexer
            .parser
            .cursor
            .domBuilder(new domimpl.DOMImplementation());

    builder.setSource(input);
    builder.buildRecursive();
    return builder.getDocument;
}

///
unittest {
    import std.format;

    string xml = q"{
    <!DOCTYPE mydoc https://myUri.org/bla [
        <!ELEMENT myelem ANY>
        <!ENTITY   myent    "replacement text">
        <!ATTLIST myelem foo cdata #REQUIRED >
        <!NOTATION PUBLIC 'h'>
        <!FOODECL asdffdsa >
    ]>
    }";

    Document doc = parseXMLString(xml);
    assert(doc !is null);
    assert(doc.doctype.entities.getNamedItem("myent").nodeValue == "replacement text");
}
