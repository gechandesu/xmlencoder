# XML encoder library for V

The `xmlencoder` module provides a way to marshal V structs into XML documents, similar to what the `json` module does.

Use `xml` attribute to set XML document and field names and encoder special options:

- a field with attribute `-` is omitted.
- a field with attribute `name,attr` becomes an attribute with the given name in the XML element.
- a field with attribute `,attr` becomes an attribute with the field name in the XML element.
- a field with attribute `,chardata` is written as character data, not as an XML element.
- a field with attribute `,cdata` is written as character data wrapped in one or more `<![CDATA[ ... ]]>` tags, not as an XML element.
- a field with attribute `,comment` is written as an XML comment. It must not contain the `--` string within it.

XML Namespaces are also supported. See examples below.

## Examples

```v
import xmlencoder

@[xml: 'user']
struct User {
    first_name string @[xml: 'firstName']
    last_name  string @[xml: 'lastName']
    age        int
    skipped    int @[xml: '-']
}

fn main() {
    user := User{'John', 'Doe', 27, -1}
    assert xmlencoder.encode(user, pretty: true) == '
    <user>
      <firstName>John</firstName>
      <lastName>Doe</lastName>
      <age>27</age>
    </user>'.trim_indent()
}
```

Tag with attrubutes:

```v
@[xml: topology]
struct Topology {
    sockets int @[xml: ',attr']
    cores   int @[xml: ',attr']
    threads int @[xml: ',attr']
}

fn main() {
    topo := Topology{1, 4, 1}
    assert xmlencoder.encode(topo) == "<topology sockets='1' cores='4' threads='1'/>"
}
```

Example with `,chardata`:

```v
@[xml: memory]
struct Memory {
    unit  string @[xml: ',attr']
    value u64    @[xml: ',chardata']
}

fn main() {
    mem := Memory{'MiB', 10240}
    assert xmlencoder.encode(mem) == "<memory unit='MiB'>10240</memory>"
}
```

For XML Namespaces specify `xmlns` attribute with comma separated `PREFIX,URI` arguments:

```v ignore
@[xmlns: 'exampl,https://example.com/xmlns/EXAMPL']
@[xml: 'metadata']
struct Metadata {
    tag []string
}

fn main() {
    m := Metadata{['foobar', 'foobaz']}
    assert xmlencoder.encode(m, pretty: true) == "
    <exampl:metadata xmlns:exampl='https://example.com/xmlns/EXAMPL'>
      <exampl:tag>foobar</exampl:tag>
      <exampl:tag>foobaz</exampl:tag>
    </exampl:metadata>".trim_indent()
}
```
