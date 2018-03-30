//
//  Terminal.swift
//  Covfefe
//
//  Created by Palle Klewitz on 20.02.18.
//

import Foundation

/// A terminal symbol which can occur in a string recognized by a parser and which cannot be
/// replaced by any production
public enum Terminal {
	/// A terminal that is a string. The terminal is matched when the tokenized subsequence of a word is equal to this string.
	case string(string: String, hash: Int)
	
	/// A terminal that is a range of characters. The terminal is matched when the tokenized subsequence is a character contained in this range.
	case characterRange(range: ClosedRange<Character>, hash: Int)
	
	/// A terminal that is a regular epxression. The terminal is matched when the tokenized subsequence is contained in the language generated by the given regular expression
	case regularExpression(expression: NSRegularExpression, hash: Int)
}

public extension Terminal {
	
	/// Creates a terminal that is a string. The terminal is matched when the tokenized subsequence of a word is equal to this string.
	///
	/// - Parameter string: Terminal string
	public init(string: String) {
		self = .string(string: string, hash: string.hashValue)
	}
	
	/// Creates a terminal that is a range of characters. The terminal is matched when the tokenized subsequence is a character contained in this range.
	///
	/// - Parameter range: Range of matched characters
	public init(range: ClosedRange<Character>) {
		self = .characterRange(range: range, hash: range.hashValue)
	}
	
	/// Creates a terminal that is a regular epxression. The terminal is matched when the tokenized subsequence is contained in the language generated by the given regular expression
	///
	/// - Parameter expression: Regular expression specifying the language matched by terminal
	/// - Throws: An error indicating that the regular expression is invalid
	public init(expression: String) throws {
		let regex = try NSRegularExpression(pattern: expression, options: [])
		self = .regularExpression(expression: regex, hash: expression.hashValue)
	}
	
	
	/// Indicates that this terminal matches the empty string and only the empty string.
	public var isEmpty: Bool {
		switch self {
		case .characterRange:
			return false
			
		case .regularExpression(let expression, _):
			return expression.pattern.isEmpty
			
		case .string(let string, _):
			return string.isEmpty
		}
	}
}

extension Terminal: ExpressibleByStringLiteral {
	public init(stringLiteral value: String) {
		self.init(string: value)
	}
}

extension Terminal: Hashable {
	public static func == (lhs: Terminal, rhs: Terminal) -> Bool {
		switch (lhs, rhs) {
		case (.string(string: let ls, hash: _), .string(string: let rs, hash: _)):
			return ls == rs
			
		case (.characterRange(range: let lr, hash: _), .characterRange(range: let rr, hash: _)):
			return lr == rr
			
		case (.regularExpression(expression: let le, hash: _), .regularExpression(expression: let re, hash: _)):
			return le.pattern == re.pattern
			
		default:
			return false
		}
	}
	
	public var hashValue: Int {
		switch self {
		case .characterRange(range: _, hash: let hash):
			return hash
			
		case .regularExpression(expression: _, hash: let hash):
			return hash
			
		case .string(string: _, hash: let hash):
			return hash
		}
	}
}

extension Terminal: CustomStringConvertible {
	public var description: String {
		switch self {
		case .string(let string, _):
			return string
			
		case .characterRange(let range, _):
			return "\(range.lowerBound) ... \(range.upperBound)"
			
		case .regularExpression(let expression, _):
			return expression.pattern
		}
	}
}

extension Terminal: Codable {
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		switch try container.decode(TerminalCoding.self, forKey: .type) {
		case .string:
			let string = try container.decode(String.self, forKey: .value)
			self = .string(string: string, hash: string.hashValue)
			
		case .characterRange:
			let range = try container.decode(ClosedRange<Character>.self, forKey: .value)
			self = .characterRange(range: range, hash: range.hashValue)
			
		case .regularExpression:
			let pattern = try container.decode(String.self, forKey: .value)
			self = try .regularExpression(expression: NSRegularExpression(pattern: pattern, options: []), hash: pattern.hashValue)
		}
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		
		switch self {
		case .string(let string, _):
			try container.encode(TerminalCoding.string, forKey: .type)
			try container.encode(string, forKey: .value)
			
		case .characterRange(let range, _):
			try container.encode(TerminalCoding.characterRange, forKey: .type)
			try container.encode(range, forKey: .value)
			
		case .regularExpression(let expression, _):
			try container.encode(TerminalCoding.regularExpression, forKey: .type)
			try container.encode(expression.pattern, forKey: .value)
		}
	}
	
	private enum CodingKeys: String, CodingKey {
		case type
		case value
	}
	
	private enum TerminalCoding: String, Codable {
		case string
		case characterRange
		case regularExpression
	}
}

extension ClosedRange: Codable where Bound == Character {
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let lower = try container.decode(String.self, forKey: .lowerBound)
		let upper = try container.decode(String.self, forKey: .upperBound)

		guard lower.count == 1 else {
			throw DecodingError.dataCorruptedError(forKey: .lowerBound, in: container, debugDescription: "lowerBound must be string of length 1")
		}
		guard upper.count == 1 else {
			throw DecodingError.dataCorruptedError(forKey: .upperBound, in: container, debugDescription: "upperBound must be string of length 1")
		}

		self.init(uncheckedBounds: (lower[lower.startIndex], upper[upper.startIndex]))
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		let lower = String(lowerBound)
		let upper = String(upperBound)
		try container.encode(lower, forKey: .lowerBound)
		try container.encode(upper, forKey: .upperBound)
	}

	private enum CodingKeys: String, CodingKey {
		case lowerBound
		case upperBound
	}
}

extension ClosedRange: Hashable where Bound: Hashable {
	public var hashValue: Int {
		return lowerBound.hashValue ^ upperBound.hashValue
	}
}
