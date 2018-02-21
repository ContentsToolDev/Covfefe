# Covfefe

[![Build Status](https://travis-ci.org/palle-k/Covfefe.svg?branch=master)](https://travis-ci.org/palle-k/Covfefe)
[![docs](https://cdn.rawgit.com/palle-k/Covfefe/66add420af3ce1801629d72ef0eedb9a30af584b/docs/badge.svg)](https://palle-k.github.io/Covfefe/)
[![CocoaPods](https://img.shields.io/cocoapods/v/Covfefe.svg)](https://cocoapods.org/pods/Covfefe)
![CocoaPods](https://img.shields.io/cocoapods/p/Covfefe.svg)
[![license](https://img.shields.io/github/license/palle-k/Covfefe.svg)](https://github.com/palle-k/Covfefe/blob/master/License)

Covfefe is a parser generator framework for languages generated by any (deterministic or nondeterministic) context free grammar.
It uses the [Earley](https://en.wikipedia.org/wiki/Earley_parser) or [CYK](https://en.wikipedia.org/wiki/CYK_algorithm) algorithm.

## Usage

### Swift Package Manager

This framework can be imported as a Swift Package by adding it as a dependency to the `Package.swift` file:

#### Swift 4.1

```swift
.package(url: "https://github.com/palle-k/Covfefe.git", majorVersion: 0, minor: 4)
```

#### Swift 4.0

```swift
.package(url: "https://github.com/palle-k/Covfefe.git", majorVersion: 0, minor: 3)
```

### CocoaPods

Alternatively, it can be added as a dependency via CocoaPods (iOS, tvOS, watchOS and macOS).

#### Swift 4.1

```ruby
target 'Your-App-Name' do
  use_frameworks!
  pod 'Covfefe'
end
```

#### Swift 4.0

```ruby
target 'Your-App-Name' do
use_frameworks!
pod 'Covfefe', '0.3.7'
end
```

Some grammar features are not available when using Swift 4.0 (Grouping, Repetitions, Optional Sequences and Character Ranges)

### To add this framework manually:

1. `git clone https://github.com/palle-k/Covfefe.git`
2. `cd Covfefe`
3. `swift package generate-xcodeproj`
4. Drag the generated project file into your project
5. Add `Covfefe.framework` in the Embedded Binaries section of your project settings

## Example

Grammars can be specified in a language that is a superset of BNF, which adopts some features of EBNF (documented [here](/BNF.md)):

```swift
let grammarString = """
<expression>       ::= <binary-operation> | <brackets> | <unary-operation> | <number> | <variable>
<brackets>         ::= '(' <expression> ')'
<binary-operation> ::= <expression> <binary-operator> <expression>
<binary-operator>  ::= '+' | '-' | '*' | '/'
<unary-operation>  ::= <unary-operator> <expression>
<unary-operator>   ::= '+' | '-'
<number>           ::= {<digit>}
<digit>            ::= '0' ... '9'
<variable>         ::= {<letter>}
<letter>           ::= 'A' ... 'Z' | 'a' ... 'z'
"""
let grammar = try Grammar(bnfString: grammarString, start: "expression")
```

This grammar describes simple mathematical expressions consisting of unary and binary operations and parentheses.
A syntax tree can be generated, which describes how a given word was derived from the grammar above:

 ```swift
let parser = EarleyParser(grammar: grammar)
 
let syntaxTree = try parser.syntaxTree(for: "(a+b)*(-c)")
 ```

![Example Syntax Tree](https://raw.githubusercontent.com/palle-k/Covfefe/master/example-syntax-tree.png)

