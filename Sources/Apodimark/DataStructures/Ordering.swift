//
//  Ordering.swift
//  Apodimark
//

enum Ordering {
    case lessThan
    case equal
    case greaterThan
}

extension Comparable {
    static func compare(_ lhs: Self, _ rhs: Self) -> Ordering {
        if lhs == rhs { return .equal }
        if lhs < rhs  { return .lessThan }
        if lhs > rhs  { return .greaterThan }
        fatalError()
    }
}
