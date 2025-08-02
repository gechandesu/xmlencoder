import xmlencoder

fn test_encode_primitives() {
	assert xmlencoder.encode[int](15) == '<int>15</int>'
	assert xmlencoder.encode[[]int]([1, 2, 3]) == '<int>1</int><int>2</int><int>3</int>'
	assert xmlencoder.encode[string]('R&D') == '<string>R&amp;D</string>'
	assert xmlencoder.encode[[]string](['a', 'b', 'c']) == '<string>a</string><string>b</string><string>c</string>'
}

@[xml: employee]
struct Employee {
	name       string
	age        int
	department string
}

fn test_encode_struct() {
	doc := Employee{
		name:       'John Doe'
		age:        24
		department: 'R&D'
	}
	doc_str := '<employee><name>John Doe</name><age>24</age><department>R&amp;D</department></employee>'
	doc_str_pretty := '
	<employee>
	  <name>John Doe</name>
	  <age>24</age>
	  <department>R&amp;D</department>
	</employee>'.trim_indent()
	assert xmlencoder.encode[Employee](doc) == doc_str
	assert xmlencoder.encode[Employee](doc, pretty: true) == doc_str_pretty
}

fn test_encode_array_of_structs() {
	doc := [
		Employee{
			name:       'John Doe'
			age:        24
			department: 'R&D'
		},
		Employee{
			name:       'Jane Doe'
			age:        21
			department: 'Sales'
		},
	]
	doc_str_pretty := '
	<employee>
	  <name>John Doe</name>
	  <age>24</age>
	  <department>R&amp;D</department>
	</employee>
	<employee>
	  <name>Jane Doe</name>
	  <age>21</age>
	  <department>Sales</department>
	</employee>'.trim_indent()
	assert xmlencoder.encode[[]Employee](doc, pretty: true) == doc_str_pretty
}

@[xml: doc]
struct Doc {
	EmbedStruct
	name   string    @[xml: documentName]
	nested NestedOne @[xml: nestedOne]
	status Status
}

struct EmbedStruct {
	document_id int @[xml: documentId]
}

struct NestedOne {
	foo   int
	bar   []string
	baz   Baz @[xml: baZ]
	empty Empty
}

struct Baz {
	bytearray []u8
}

struct Empty {}

enum Status {
	unknown
	open
	closed
}

fn test_encode_complex_struct() {
	doc := Doc{
		document_id: 228
		name:        'Top Secret'
		nested:      NestedOne{
			baz: Baz{[u8(0), 1, 2, 3, 4]}
		}
	}
	doc_str_pretty := '
	<doc>
	  <EmbedStruct>
	    <documentId>228</documentId>
	  </EmbedStruct>
	  <documentName>Top Secret</documentName>
	  <nestedOne>
	    <foo>0</foo>
	    <baZ>
	      <bytearray>0</bytearray>
	      <bytearray>1</bytearray>
	      <bytearray>2</bytearray>
	      <bytearray>3</bytearray>
	      <bytearray>4</bytearray>
	    </baZ>
	    <empty/>
	  </nestedOne>
	  <status>unknown</status>
	</doc>'.trim_indent()
	assert xmlencoder.encode[Doc](doc, pretty: true) == doc_str_pretty
}

@[xml: foo]
struct Foo {
	bar struct {
		hello int
		world int
	}
	baz struct {
		hello int
		world int
	} @[xml: baZ]
}

fn test_encode_anon_struct() {
	foo := Foo{}
	assert xmlencoder.encode(foo) == '<foo><bar><hello>0</hello><world>0</world></bar><baZ><hello>0</hello><world>0</world></baZ></foo>'
}

@[xml: opt]
struct WithOptions {
	hello int
	maybe ?string
}

fn test_encode_options() {
	// assert xmlencoder.encode(WithOptions{ hello: 1 }) == '<opt><hello>1</hello></opt>'
}

@[xml: topology]
struct DocWithAttrs {
	sockets int @[xml: ',attr']
	cores   int @[xml: ',attr']
	threads int @[xml: 'threads,attr']
}

fn test_encode_xml_attrs() {
	assert xmlencoder.encode(DocWithAttrs{1, 4, 1}) == "<topology sockets='1' cores='4' threads='1'/>"
}

@[xml: memory]
struct Memory {
	unit  string @[xml: ',attr']
	value u64    @[xml: ',chardata']
}

fn test_encode_chardata() {
	doc_str := "<memory unit='MiB'>10240</memory>"
	assert xmlencoder.encode(Memory{ unit: 'MiB', value: 10240 }) == doc_str
}

struct CData {
	data string @[xml: ',cdata']
}

fn test_encode_cdata() {
	d := CData{
		data: 'R&D'
	}
	assert xmlencoder.encode(d) == '<CData><![CDATA[R&D]]></CData>'
}

@[xmlns: 'meta,https://example.com/xmlns/meta']
@[xml: 'metadata']
struct Metadata {
	key string
}

fn test_encode_xmlns() {
	m := Metadata{
		key: 'foobar'
	}
	assert xmlencoder.encode(m, pretty: true) == "
	<meta:metadata xmlns:meta='https://example.com/xmlns/meta'>
	  <meta:key>foobar</meta:key>
	</meta:metadata>".trim_indent()
}
