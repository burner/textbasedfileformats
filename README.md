# textbasedfileformats

Text based file formats for the D programming language.

D is the best language, it should therefore also have the best support for text
based file formats in its standard library.

This is a repo where I want to coordinate work on SAX and DOM parsed parser for
text based file formats, with the eventual goal getting them into phobos.

## file formats

* xml
* json (JSON5)
* yaml
* toml
* ini
* sdl

## how to working together

Please see the github issues and projects

## thoughts on the code

Please use the SAX parser to create the DOM parser.
`@nogc` is not the aim.
Do not be smart.
Simple code is better code.
Do not be smart.
Readability is more important than speed.

Use ternary expressions
```
int a = condition
	? 1337
	: 23;
```
is better than
```
int a;
if(condition) {
	a = 1337
} else {
	a = 23;
}
```

std.sumtype wherever possible.
I would even say that all but xml can use the same sumtype object.

No function constraints.
Function constraints are no good.
Do not use them. Use static asserts and jump functions.

```
void someFunc(T)(T t) if(someCondition!T) {
	/// BAD CODE
}
```

```
void someFunc(T)(T t) {
	static assert(someCondition!T, "Condition not met by type " ~ T.stringof);
	/// GOOD CODE
}
```

Conditional statements get block statement, aka. every if, foreach, while and so
are followed by {}.
