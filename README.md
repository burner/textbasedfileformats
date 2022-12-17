# textbasedfileformats

Text based file formats for the D programming language.

This is a repo where I want to coordinate work on SAX and DOM parsed parser for
text based file formats, with the eventual goal getting it into phobos.

## file formats

* xml
* json
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
