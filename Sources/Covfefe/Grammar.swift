//
//  Grammar.swift
//  Covfefe
//
//  Created by Palle Klewitz on 07.08.17.
//  Copyright (c) 2017 - 2020 Palle Klewitz
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

/// A syntax error which was generated during parsing or tokenization
public struct SyntaxError: Error {
	
	/// The reason for the syntax error
	///
	/// - emptyNotAllowed: An empty string was provided but the grammar does not allow empty productions
	/// - unknownToken: The tokenization could not be completed because no matching token was found
	/// - unmatchedPattern: A pattern was found which could not be merged
	/// - unexpectedToken: A token was found that was not expected
	public enum Reason {
		/// An empty string was provided but the grammar does not allow empty productions
		case emptyNotAllowed
		
		/// The tokenization could not be completed because no matching token was found
		case unknownToken
		
		/// A pattern was found which could not be merged
		case unmatchedPattern
		
		/// A token was found that was not expected
		case unexpectedToken
	}
	
	/// Range in which the error occurred
	public let range: Range<String.Index>
	
	/// Reason for the error
	public let reason: Reason
	
	/// The context around the error
	public let context: [NonTerminal]
	
	/// The string for which the parsing was unsuccessful.
	public let string: String
    
    /// The line in which the error occurred.
    ///
    /// The first line of the input string is line 0.
    public var line: Int {
        if string.count == 0 {
            return 0
        }
        return string[...range.lowerBound].filter { (char: Character) in
            char.isNewline
        }.count
    }
    
    public var column: Int {
        if string.count == 0 {
            return 0
        }
        let lastNewlineIndex = string[...range.lowerBound].lastIndex(where: {$0.isNewline}) ?? string.startIndex
        return string.distance(from: lastNewlineIndex, to: range.lowerBound)
    }
	
	/// Creates a new syntax error with a given range and reason
	///
	/// - Parameters:
	///   - range: String range in which the syntax error occurred
	///   - string: String which was unsuccessfully parsed
	///   - reason: Reason why the syntax error occurred
	///   - context: Non-terminals which were expected at the location of the error.
	public init(range: Range<String.Index>, in string: String, reason: Reason, context: [NonTerminal] = []) {
		self.range = range
		self.string = string
		self.reason = reason
		self.context = context
	}
}

extension SyntaxError: CustomStringConvertible {
	public var description: String {
		let main = "Error: \(reason) at L\(line):\(column): '\(string[range])'"
		if !context.isEmpty {
			return "\(main), expected: \(context.map{$0.description}.joined(separator: " | "))"
		} else {
			return main
		}
	}
}

extension SyntaxError.Reason: CustomStringConvertible {
	public var description: String {
		switch self {
		case .emptyNotAllowed:
			return "Empty string not accepted"
		case .unknownToken:
			return "Unknown token"
		case .unmatchedPattern:
			return "Unmatched pattern"
		case .unexpectedToken:
			return "Unexpected token"
		}
	}
}


/// A context free or regular grammar
/// consisting of a set of productions
///
/// In context free grammars, the left side of productions
/// (in this framework also referred to as pattern) is always
/// a single non-terminal.
///
/// Grammars might be ambiguous. For example, the grammar
///
///		<expr> ::= <expr> '+' <expr> | 'a'
///
/// can recognize the expression `a+a+a+a` in 5 different ways:
/// `((a+a)+a)+a`, `(a+(a+a))+a`, `a+(a+(a+a))`, `a+((a+a)+a)`, `(a+a)+(a+a)`.
public struct Grammar {
	
	/// Productions for generating words of the language generated by this grammar
	public var productions: [Production]
	
	/// Root non-terminal
	///
	/// All syntax trees of words in this grammar must have a root containing this non-terminal.
	public var start: NonTerminal
	
	/// Non-terminals generated by normalizing the grammar.
	let utilityNonTerminals: Set<NonTerminal>
	
	/// Creates a new grammar with a given set of productions and a start non-terminal
	///
	/// - Parameters:
	///   - productions: Productions for generating words
	///   - start: Root non-terminal
	public init(productions: [Production], start: NonTerminal) {
		self.init(productions: productions, start: start, utilityNonTerminals: [])
		
		// assertNonFatal(unreachableNonTerminals.isEmpty, "Grammar contains unreachable non-terminals (\(unreachableNonTerminals))")
		// assertNonFatal(unterminatedNonTerminals.isEmpty, "Grammar contains non-terminals which can never reach terminals (\(unterminatedNonTerminals))")
	}
	
	/// Creates a new grammar with a given set of productions, a start non-terminal and
	/// a set of non-terminals which have been created for normalization
	///
	/// - Parameters:
	///   - productions: Productions for generating words
	///   - start: Root non-terminal
	///   - normalizationNonTerminals: Non-terminals generated during normalization
	init(productions: [Production], start: NonTerminal, utilityNonTerminals: Set<NonTerminal>) {
		self.productions = productions
		self.start = start
		self.utilityNonTerminals = utilityNonTerminals
	}
}


extension Grammar: CustomStringConvertible {
	
	/// Returns a Backus-Naur form representation of the grammar.
	///
	/// Production rules are encoded in the following form:
	/// `pattern ::= production-result`, where the pattern is always a single non-terminal and the production-result
	/// is a list of alternative results separated by `|` (or just one single result). The production result is a concatenation
	/// of terminal and non-terminal symbols. Terminals are delimited by single or double quotation marks; non-terminals
	/// are delimited by angle brackets (`<`, `>`). Concatenations consist of one or multiple symbols separated by zero or more
	/// whitespace characters.
	///
	/// Example:
	///
	///		<non-terminal-pattern> ::= <produced-non-terminal-pattern> | 'terminal' <concatenated-non-terminal>
	public var bnf: String {
		let groupedProductions = Dictionary(grouping: self.productions) { production in
			production.pattern
		}
		return groupedProductions.sorted(by: {$0.key.name < $1.key.name}).map { entry -> String in
			let (pattern, productions) = entry
			
			let productionString = productions.map { production in
				if production.production.isEmpty {
					return "\"\""
				}
				return production.production.map { symbol -> String in
					switch symbol {
					case .nonTerminal(let nonTerminal):
						return "<\(nonTerminal.name)>"
						
					case .terminal(.string(let string, _)) where string.contains("\""):
						let escapedValue = string.singleQuoteLiteralEscaped
						return "'\(escapedValue)'"
						
					case .terminal(.string(let string, _)):
						let escapedValue = string.doubleQuoteLiteralEscaped
						return "\"\(escapedValue)\""
						
					case .terminal(.regularExpression(let expression, _)) where expression.pattern.contains("\""):
						let escapedValue = expression.pattern.singleQuoteLiteralEscaped
						return "'\(escapedValue)'"
						
					case .terminal(.regularExpression(let expression, _)):
						let escapedValue = expression.pattern.doubleQuoteLiteralEscaped
						return "\"\(escapedValue)\""
						
					case .terminal(.characterRange(let range, _)):
						let lowerString: String
						let upperString: String
						
						if range.lowerBound == "'" {
							lowerString = "\"'\""
						} else {
							lowerString = "'\(range.lowerBound)'"
						}
						
						if range.upperBound == "'" {
							upperString = "\"'\""
						} else {
							upperString = "'\(range.upperBound)'"
						}
						
						return "\(lowerString) ... \(upperString)"
					}
				}.joined(separator: " ")
			}.joined(separator: " | ")
			
			return "<\(pattern.name)> ::= \(productionString)"
		}.joined(separator: "\n")
	}
	
	
	/// Returns a Extended Backus-Naur form representation of the grammar.
	///
	/// Production rules are encoded in the following form:
	/// `pattern = production-result;`, where the pattern is always a single non-terminal and the production-result
	/// is a list of alternative results separated by `|` (or just one single result). The production result is a concatenation
	/// of terminal and non-terminal symbols. Terminals are delimited by single or double quotation marks; non-terminals
	/// are not delimited by a special character. Concatenations consist of one or multiple symbols separated by a comma.
	///
	/// Example:
	///
	///		non-terminal pattern = produced non-terminal | 'terminal', concatenated non-terminal;
	public var ebnf: String {
		let groupedProductions = Dictionary(grouping: self.productions) { production in
			production.pattern
		}
		return groupedProductions.sorted(by: {$0.key.name < $1.key.name}).map { entry -> String in
			let (pattern, productions) = entry
			
			let productionString = productions.map { production in
				if production.production.isEmpty {
					return "\"\""
				}
				return production.production.map { symbol -> String in
					switch symbol {
					case .nonTerminal(let nonTerminal):
						return nonTerminal.name
						
					case .terminal(.string(let string, _)) where string.contains("\""):
						let escapedValue = string.singleQuoteLiteralEscaped
						return "'\(escapedValue)'"
						
					case .terminal(.string(let string, _)):
						let escapedValue = string.doubleQuoteLiteralEscaped
						return "\"\(escapedValue)\""
						
					case .terminal(.regularExpression(let expression, _)) where expression.pattern.contains("\""):
						let escapedValue = expression.pattern.singleQuoteLiteralEscaped
						return "'\(escapedValue)'"
						
					case .terminal(.regularExpression(let expression, _)):
						let escapedValue = expression.pattern.doubleQuoteLiteralEscaped
						return "\"\(escapedValue)\""
						
					case .terminal(.characterRange(let range, _)):
						let lowerString: String
						let upperString: String
						
						if range.lowerBound == "'" {
							lowerString = "\"'\""
						} else {
							lowerString = "'\(range.lowerBound)'"
						}
						
						if range.upperBound == "'" {
							upperString = "\"'\""
						} else {
							upperString = "'\(range.upperBound)'"
						}
						
						return "\(lowerString) ... \(upperString)"
					}
				}.joined(separator: ", ")
			}.joined(separator: " | ")
			
			return "\(pattern.name) = \(productionString);"
		}.joined(separator: "\n")
	}
    
    /// Returns a Augmented Backus-Naur form representation of the grammar.
    ///
    /// Production rules are encoded in the following form:
    /// `pattern = production-result`, where the pattern is always a single non-terminal and the production-result
    /// is a list of alternative results separated by `/` (or just one single result). The production result is a concatenation
    /// of terminal and non-terminal symbols.
    ///
    /// Example:
    ///
    ///        non-terminal-pattern = produced non-terminal / "terminal" concatenated non-terminal;
    public var abnf: String {
        let groupedProductions = Dictionary(grouping: self.productions) { production in
            production.pattern
        }
        return groupedProductions.sorted(by: {$0.key.name < $1.key.name}).map { entry -> String in
            let (pattern, productions) = entry
            
            let productionString = productions.map { production in
                if production.production.isEmpty {
                    return "\"\""
                }
                return production.production.map { symbol -> String in
                    switch symbol {
                    case .nonTerminal(let nonTerminal):
                        return nonTerminal.name
   
                    case .terminal(.string(let string, _)):
                        if let scalar = string.unicodeScalars.first, string.unicodeScalars.count == 1 {
                            return "%x\(String(scalar.value, radix: 16))"
                        }
                        let escapedValue = string.doubleQuoteLiteralEscaped
                        return "\"\(escapedValue)\""
                        
                    case .terminal(.regularExpression):
                        fatalError("Regular expressions cannot be expressed in standard ABNF")
                        
                    case .terminal(.characterRange(let range, _)):
                        let lowerBound = String(range.lowerBound.unicodeScalars.first!.value, radix: 16)
                        let upperBound = String(range.upperBound.unicodeScalars.first!.value, radix: 16)
                        
                        return "%x\(lowerBound)-\(upperBound)"
                    }
                }.joined(separator: " ")
            }.joined(separator: " / ")
            
            return "\(pattern.name) = \(productionString);"
        }.joined(separator: "\n")
    }
	
	public var description: String {
		return bnf
	}
		
}

public extension Grammar {
	
	/// Returns true, if the grammar is in chomsky normal form.
	///
	/// A grammar is in chomsky normal form if all productions satisfy one of the following conditions:
	///
	/// - A production generates exactly one terminal symbol
	/// - A production generates exactly two non-terminal symbols
	/// - A production generates an empty string and is generated from the start non-terminal
	///
	/// Certain parsing algorithms, such as the CYK parser, require the recognized grammar to be in Chomsky normal form.
	var isInChomskyNormalForm: Bool {
        return productions.allSatisfy { production -> Bool in
			(production.isFinal && production.production.count == 1)
			|| (!production.isFinal && production.generatedNonTerminals.count == 2 && production.generatedTerminals.count == 0)
			|| (production.production.isEmpty && production.pattern == start)
		}
	}
}

extension Grammar: Equatable {
	public static func == (lhs: Grammar, rhs: Grammar) -> Bool {
		return lhs.start == rhs.start && Set(lhs.productions) == Set(rhs.productions)
	}
}
