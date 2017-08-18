//
//  CYKParser.swift
//  Covfefe
//
//  Created by Palle Klewitz on 15.08.17.
//

import Foundation

/// A parser which can check if a word is in a language
/// and generate a syntax tree explaining how a word was derived from a grammar
public protocol Parser {
	
	/// Creates a syntax tree which explains how a word was derived from a grammar
	///
	/// - Parameter tokenization: Tokenized input
	/// - Returns: A syntax tree explaining how the grammar can be used to derive the word described by the given tokenization
	/// - Throws: A syntax error if the word is not in the language recognized by the parser
	func syntaxTree(for tokenization: [[SyntaxTree<Production, Range<String.Index>>]]) throws -> SyntaxTree<NonTerminal, Range<String.Index>>
}

public extension Parser {
	
	/// Returns true if the recognized language contains the given tokenization.
	///
	/// - Parameter tokenization: Tokenization of checked word
	/// - Returns: True, if the word is generated by the grammar, false if not.
	public func recognizes(_ tokenization: [[SyntaxTree<Production, Range<String.Index>>]]) -> Bool {
		return (try? self.syntaxTree(for: tokenization)) != nil
	}
}


/// A parser based on the CYK algorithm.
///
/// The parser can parse non-deterministic and deterministic grammars.
/// It requires O(n^3) runtime.
public class CYKParser: Parser {
	
	/// The grammar which the parser recognizes
	public let grammar: Grammar
	
	/// The parser requires the grammar to be in chomsky normal form
	private lazy var normalizedGrammar: Grammar = grammar.chomskyNormalized()
	
	/// Initializes a CYK parser which recognizes the given grammar.
	///
	/// The parser can parse non-deterministic and deterministic context free languages in O(n^3).
	///
	/// - Parameter grammar: The grammar which the parser recognizes.
	public init(grammar: Grammar) {
		self.grammar = grammar
	}
	
	/// Generates an error from a CYK table if the grammar cannot be used to generate a given word.
	///
	/// - Parameter cykTable: Table containing unfinished syntax trees
	/// - Returns: An error pointing towards the first invalid token in the string.
	private func generateError(_ cykTable: Array<[[SyntaxTree<Production, Range<String.Index>>]]>) -> SyntaxError {
		let memberRows = (0..<cykTable.count).map { columnIndex -> Int? in
			(0 ..< (cykTable.count - columnIndex)).reduce(nil) { maxIndex, rowIndex -> Int? in
				if cykTable[rowIndex][columnIndex].contains(where: { tree -> Bool in
					tree.root?.pattern == normalizedGrammar.start
				}) {
					return rowIndex
				}
				return maxIndex
			}
		}
		
		if let firstMember = memberRows[0] {
			return SyntaxError(range: cykTable[0][firstMember+1][0].leafs.first!, reason: .unmatchedPattern)
		} else {
			return SyntaxError(range: cykTable[0][0][0].leafs.first!, reason: .unmatchedPattern)
		}
	}
	
	/// Reintroduces chain productions which have been eliminated during normalization
	///
	/// - Parameter tree: Syntax tree without chain productions
	/// - Returns: Syntax tree with chain productions added.
	private func unfoldChainProductions(_ tree: SyntaxTree<Production, Range<String.Index>>) -> SyntaxTree<NonTerminal, Range<String.Index>> {
		switch tree {
		case .leaf(let leaf):
			return .leaf(leaf)
			
		case .node(key: let production, children: let children):
			guard let chain = production.nonTerminalChain else {
				return .node(key: production.pattern, children: children.map(unfoldChainProductions))
			}
			let newNode = chain.reversed().reduce(children.map(unfoldChainProductions)) { (childNodes, nonTerminal) -> [SyntaxTree<NonTerminal, Range<String.Index>>] in
				[SyntaxTree.node(key: nonTerminal, children: childNodes)]
			}
			return .node(key: production.pattern, children: newNode)
		}
	}
	
	public func syntaxTree(for tokenization: [[SyntaxTree<Production, Range<String.Index>>]]) throws -> SyntaxTree<NonTerminal, Range<String.Index>> {
		if tokenization.isEmpty {
			if normalizedGrammar.productions.contains(where: { production -> Bool in
				production.pattern == normalizedGrammar.start && production.generatedTerminals.isEmpty
			}) {
				return SyntaxTree.node(key: normalizedGrammar.start, children: [SyntaxTree.leaf("".startIndex ..< "".endIndex)])
			} else {
				throw SyntaxError(range: "".startIndex ..< "".endIndex, reason: .emptyNotAllowed)
			}
		}
		
		let nonTerminalProductions = Dictionary(grouping: normalizedGrammar.productions.filter{!$0.isFinal}) { production -> NonTerminalString in
			NonTerminalString(characters: production.generatedNonTerminals)
		}
		
		var cykTable = [[[SyntaxTree<Production, Range<String.Index>>]]](repeating: [], count: tokenization.count)
		cykTable[0] = tokenization
		
		for row in 1 ..< cykTable.count {
			let upperBound = cykTable.count - row
			
			cykTable[row] = (0..<upperBound).map { column -> [SyntaxTree<Production, Range<String.Index>>] in
				(1...row).flatMap { offset -> [SyntaxTree<Production, Range<String.Index>>] in
					let ref1Row = row - offset
					let ref2Col = column + row - offset + 1
					let ref2Row = offset - 1
					
					return crossFlatMap(cykTable[ref1Row][column], cykTable[ref2Row][ref2Col]) { leftTree, rightTree -> [SyntaxTree<Production, Range<String.Index>>] in
						let combinedString = NonTerminalString(characters: [leftTree.root!.pattern, rightTree.root!.pattern])
						let possibleProductions = nonTerminalProductions[combinedString, default: []]
						return possibleProductions.map { pattern -> SyntaxTree<Production, Range<String.Index>> in
							return SyntaxTree(key: pattern, children: [leftTree, rightTree])
						}
					}
				}.unique(by: {$0.root!.pattern}).collect(Array.init)
			}
		}
		
//		if debug {
//			print(cykTable.map { row -> String in
//				row.map { entry -> String in
//					"[\(entry.map(\.root!.pattern.description).joined(separator: ", "))]"
//					}.joined(separator: ", ")
//				}.joined(separator: "\n\n")
//			)
//		}
		
		// If a given word is not a member of the language generated by this grammar
		// an error will be computed that returns the first and largest structure
		// in the syntax tree that the parser was unable to process.
		guard let syntaxTree = cykTable[cykTable.count-1][0].first(where: { tree -> Bool in
			tree.root?.pattern == normalizedGrammar.start
		}) else {
			throw generateError(cykTable)
		}
		return unfoldChainProductions(syntaxTree).explode(normalizedGrammar.normalizationNonTerminals.contains)[0]
	}
}
