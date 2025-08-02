import xmlencoder

@[xml: person]
struct Person {
	id   int
	name struct {
		first string
		last  string
	}
	age  int
}

fn main() {
	p := Person{
		id:   123
		name: struct {
			first: 'John'
			last:  'Doe'
		}
		age:  25
	}
	println(xmlencoder.encode(p, pretty: true))
}
