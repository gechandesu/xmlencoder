module xmlencoder

import encoding.xml
import strings

// encode encodes the given value `val` into XML document.
//
// Example:
// ```v
// import xmlencoder
//
// @[xml: person]
// struct Person {
//     id   int
//     name struct {
//         first string
//         last  string
//     }
//     age  int
// }
//
// fn main() {
//     p := Person{
//         id:   123
//         name: struct {
//             first: 'John'
//             last:  'Doe'
//         }
//         age:  25
//     }
//     doc := xmlencoder.encode(p, pretty: true)
//     println(doc)
// }
// ```
pub fn encode[T](val T, config EncoderConfig) string {
	mut e := Encoder{
		builder: strings.new_builder(1024)
		pretty:  config.pretty
		prefix:  config.prefix
		indent:  config.indent
	}
	e.encode_value(val, none)
	if e.pretty {
		// Delete extra `\n` at end in pretty print mode
		e.builder.go_back(1)
	}
	return e.str()
}

@[params]
pub struct EncoderConfig {
pub:
	pretty bool
	prefix string
	indent string = '  '
}

struct Encoder {
	pretty bool
	prefix string
	indent string
mut:
	builder strings.Builder
	level   int
}

fn (mut e Encoder) str() string {
	return e.builder.str()
}

fn (mut e Encoder) encode_value[T](val T, tagname ?string) {
	mut open_tag := opentag(typeof[T]().name)
	mut close_tag := closetag(typeof[T]().name)
	if tagname != none {
		open_tag = opentag(tagname)
		close_tag = closetag(tagname)
	}
	line_prefix := e.make_prefix()
	$if T is $string {
		e.builder.write_string(line_prefix + open_tag)
		e.builder.write_string(xml.escape_text(val))
		e.builder.write_string(close_tag)
	} $else $if T is $struct {
		e.encode_struct(val, tagname)
	} $else $if T is $array {
		for v in val {
			e.encode_value(v, tagname)
		}
		if e.pretty {
			// Delete extra `\n` after last array element in pretty print mode
			e.builder.go_back(1)
		}
	} $else {
		e.builder.write_string(line_prefix + open_tag)
		e.builder.write_string(val.str())
		e.builder.write_string(close_tag)
	}
	if e.pretty {
		e.builder.write_string('\n')
	}
}

fn (mut e Encoder) encode_struct[T](val T, tagname ?string) {
	line_prefix := e.make_prefix()
	// Use the struct name as XML document name if name not set in `xml` attribute.
	// Also makes sense for embedded structs.
	mut xml_name := T.name
	mut xmlns_prefix := ''
	mut xmlns_uri := ''
	// Grab document/tag name from struct attributes.
	$for attr in T.attributes {
		if attr.name == 'xml' && attr.has_arg {
			xml_name = attr.arg
		}
		if attr.name == 'xmlns' && attr.has_arg {
			xmlns_prefix, xmlns_uri = attr.arg.split_once(',') or { '', '' }
		}
	}
	// The tag name from the field attribute takes precedence over
	// the struct attribute. Override xml_name!
	if tagname != none {
		xml_name = tagname
	}
	// If structure does not have any fields it will be encoded as `<name/>`.
	mut total_fields_nr := 0
	mut non_attr_fields_nr := 0
	mut xml_attrs := []string{}

	// Apply XML Namespace
	if xmlns_prefix != '' && xmlns_uri != '' {
		xml_name = xmlns_prefix + ':' + xml_name
		xml_attrs << 'xmlns:' + xmlns_prefix + "='" + xmlns_uri + "'"
	}
	// Traverse over struct fields to collect all fields that represents XML attrs
	$for field in T.fields {
		if field.attrs.len == 0 {
			total_fields_nr++
			non_attr_fields_nr++
		}
		for attr in field.attrs {
			mut name, option := parse_attr(attr) or { continue }
			if name == '-' {
				continue // skip field
			}
			if option == 'attr' {
				if name == '' {
					name = field.name
				}
				// TODO: support option encoding
				// mut value := ''
				// if field.is_option {
				// 	if val.$(field.name) != none {
				// 		value = val.$(field.name).str()
				// 	}
				// } else {
				// 	value = val.$(field.name).str()
				// }
				// xml_attrs << name + "='" + value + "'"
				xml_attrs << name + "='" + val.$(field.name).str() + "'"
				continue
			}
			total_fields_nr++
			non_attr_fields_nr++
		}
	}
	e.builder.write_string(line_prefix + '<' + xml_name)
	if xml_attrs.len > 0 {
		e.builder.write_string(' ' + xml_attrs.join(' '))
	}
	if total_fields_nr > 0 && non_attr_fields_nr > 0 {
		e.builder.write_string('>')
	} else {
		e.builder.write_string('/>')
		return
	}
	if e.pretty {
		e.builder.write_string('\n')
	}
	e.level++
	$for field in T.fields {
		mut skip := false
		mut name := field.name
		mut option := ''
		for attr in field.attrs {
			name, option = parse_attr(attr) or { continue }
			if name == '-' {
				skip = true
			}
			if option == 'attr' {
				skip = true
			}
		}
		if xmlns_prefix != '' && xmlns_uri != '' {
			name = xmlns_prefix + ':' + name
		}
		value := val.$(field.name)
		if !skip {
			match option {
				'chardata' {
					e.builder.write_string(xml.escape_text(value.str()))
				}
				'cdata' {
					e.builder.write_string('<![CDATA[' + value.str() + ']]>')
				}
				'comment' {
					e.builder.write_string('<!-- ' + xml.escape_text(value.str()) + ' -->')
				}
				else {
					e.encode_value(value, name)
				}
			}
		}
	}
	e.level--
	e.builder.write_string(line_prefix + closetag(xml_name))
}

fn (e Encoder) make_prefix() string {
	if e.pretty {
		return e.prefix + e.indent.repeat(e.level)
	}
	return ''
}

fn opentag(t string) string {
	return '<' + t + '>'
}

fn closetag(t string) string {
	return '</' + t + '>'
}

fn parse_attr(attr string) ?(string, string) {
	if !attr.starts_with('xml: ') {
		return none
	}
	parts := attr.all_after('xml: ').split(',')
	match true {
		parts.len == 1 {
			return parts[0], ''
		}
		parts.len == 2 {
			return parts[0], parts[1]
		}
		else {
			return none
		}
	}
	return none
}
