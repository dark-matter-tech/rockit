// SymbolTable.swift
// MoonKit — Moon Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

// MARK: - Symbol Kind

/// What kind of binding a symbol represents
public enum SymbolKind: Equatable {
    case variable(isMutable: Bool)
    case function
    case parameter
    case typeDeclaration
    case typeParameter
    case enumEntry
}

// MARK: - Symbol

/// A named binding in the symbol table
public struct Symbol {
    public let name: String
    public let type: Type
    public let kind: SymbolKind
    public let span: SourceSpan?

    public init(name: String, type: Type, kind: SymbolKind, span: SourceSpan? = nil) {
        self.name = name
        self.type = type
        self.kind = kind
        self.span = span
    }
}

// MARK: - Type Declaration Info

/// Extra information about a type declaration (class, sealed class, enum, interface, etc.)
public struct TypeDeclInfo {
    public let name: String
    public let typeParameters: [String]
    public var sealedSubclasses: [String]
    public var enumEntries: [String]
    public var members: [Symbol]
    public var superTypes: [String]

    public init(name: String, typeParameters: [String] = [],
                sealedSubclasses: [String] = [], enumEntries: [String] = [],
                members: [Symbol] = [], superTypes: [String] = []) {
        self.name = name
        self.typeParameters = typeParameters
        self.sealedSubclasses = sealedSubclasses
        self.enumEntries = enumEntries
        self.members = members
        self.superTypes = superTypes
    }
}

// MARK: - Scope

/// A lexical scope containing symbols. Scopes form a parent chain for lookup.
public final class Scope {
    public let parent: Scope?
    private var symbols: [String: Symbol] = [:]

    public init(parent: Scope? = nil) {
        self.parent = parent
    }

    /// Define a symbol in this scope. Returns false if already defined in THIS scope.
    @discardableResult
    public func define(_ symbol: Symbol) -> Bool {
        if symbols[symbol.name] != nil {
            return false
        }
        symbols[symbol.name] = symbol
        return true
    }

    /// Look up a symbol by name, walking the parent chain.
    public func lookup(_ name: String) -> Symbol? {
        if let sym = symbols[name] {
            return sym
        }
        return parent?.lookup(name)
    }

    /// Look up a symbol only in this scope (no parent walk).
    public func lookupLocal(_ name: String) -> Symbol? {
        return symbols[name]
    }

    /// Update an existing symbol in this scope (for type inference).
    public func update(_ symbol: Symbol) {
        symbols[symbol.name] = symbol
    }
}

// MARK: - Symbol Table

/// Manages the scope stack and type declaration registry.
public final class SymbolTable {
    public private(set) var globalScope: Scope
    public private(set) var currentScope: Scope
    private var scopeStack: [Scope] = []

    /// Registry of type declarations (classes, interfaces, enums, etc.)
    public private(set) var typeDeclarations: [String: TypeDeclInfo] = [:]

    public init() {
        let global = Scope()
        self.globalScope = global
        self.currentScope = global
        populateBuiltins()
    }

    /// Push a new child scope
    public func pushScope() {
        let child = Scope(parent: currentScope)
        scopeStack.append(currentScope)
        currentScope = child
    }

    /// Pop back to the parent scope
    public func popScope() {
        guard let parent = scopeStack.popLast() else { return }
        currentScope = parent
    }

    /// Define a symbol in the current scope
    @discardableResult
    public func define(_ symbol: Symbol) -> Bool {
        return currentScope.define(symbol)
    }

    /// Look up a symbol by name (walks scope chain)
    public func lookup(_ name: String) -> Symbol? {
        return currentScope.lookup(name)
    }

    /// Register a type declaration
    public func registerType(_ info: TypeDeclInfo) {
        typeDeclarations[info.name] = info
    }

    /// Look up a type declaration by name
    public func lookupType(_ name: String) -> TypeDeclInfo? {
        return typeDeclarations[name]
    }

    /// Add a sealed subclass to a parent sealed class
    public func addSealedSubclass(parent: String, child: String) {
        typeDeclarations[parent]?.sealedSubclasses.append(child)
    }

    // MARK: - Builtins

    private func populateBuiltins() {
        // Primitive types
        let builtinTypes: [(String, Type)] = [
            ("Int",       .int),
            ("Int32",     .int32),
            ("Int64",     .int64),
            ("Float",     .float),
            ("Float64",   .float64),
            ("Double",    .double),
            ("Bool",      .bool),
            ("String",    .string),
            ("ByteArray", .byteArray),
            ("Unit",      .unit),
            ("Nothing",   .nothing),
        ]

        for (name, type) in builtinTypes {
            globalScope.define(Symbol(name: name, type: type, kind: .typeDeclaration))
            typeDeclarations[name] = TypeDeclInfo(name: name)
        }

        // Common generic types (List, Map, Set) — registered as type declarations
        // with type parameters so they can be resolved
        let genericTypes: [(String, [String])] = [
            ("List", ["T"]),
            ("MutableList", ["T"]),
            ("Map", ["K", "V"]),
            ("MutableMap", ["K", "V"]),
            ("Set", ["T"]),
            ("MutableSet", ["T"]),
            ("Pair", ["A", "B"]),
            ("Result", ["T", "E"]),
        ]

        for (name, typeParams) in genericTypes {
            let type = Type.classType(name: name, typeArguments: [])
            globalScope.define(Symbol(name: name, type: type, kind: .typeDeclaration))
            typeDeclarations[name] = TypeDeclInfo(name: name, typeParameters: typeParams)
        }

        // Built-in functions
        let builtinFunctions: [(String, Type)] = [
            ("println", .function(parameterTypes: [.string], returnType: .unit)),
            ("print",   .function(parameterTypes: [.string], returnType: .unit)),
            ("readLine", .function(parameterTypes: [], returnType: .nullable(.string))),
            ("listOf",  .function(parameterTypes: [], returnType: .classType(name: "List", typeArguments: []))),
            ("mapOf",   .function(parameterTypes: [], returnType: .classType(name: "Map", typeArguments: []))),
            ("setOf",   .function(parameterTypes: [], returnType: .classType(name: "Set", typeArguments: []))),
            ("mutableListOf", .function(parameterTypes: [], returnType: .classType(name: "MutableList", typeArguments: []))),
            ("mutableMapOf",  .function(parameterTypes: [], returnType: .classType(name: "MutableMap", typeArguments: []))),
        ]

        for (name, type) in builtinFunctions {
            globalScope.define(Symbol(name: name, type: type, kind: .function))
        }

        // Collection builtin functions
        let collectionBuiltins: [(String, Type)] = [
            // List operations
            ("listCreate",   .function(parameterTypes: [],
                                       returnType: .classType(name: "List", typeArguments: []))),
            ("listAppend",   .function(parameterTypes: [.classType(name: "List", typeArguments: []), .typeParameter(name: "T", bound: nil)],
                                       returnType: .unit)),
            ("listGet",      .function(parameterTypes: [.classType(name: "List", typeArguments: []), .int],
                                       returnType: .typeParameter(name: "T", bound: nil))),
            ("listSet",      .function(parameterTypes: [.classType(name: "List", typeArguments: []), .int, .typeParameter(name: "T", bound: nil)],
                                       returnType: .unit)),
            ("listSize",     .function(parameterTypes: [.classType(name: "List", typeArguments: [])],
                                       returnType: .int)),
            ("listRemoveAt", .function(parameterTypes: [.classType(name: "List", typeArguments: []), .int],
                                       returnType: .typeParameter(name: "T", bound: nil))),
            ("listContains", .function(parameterTypes: [.classType(name: "List", typeArguments: []), .typeParameter(name: "T", bound: nil)],
                                       returnType: .bool)),
            ("listIndexOf",  .function(parameterTypes: [.classType(name: "List", typeArguments: []), .typeParameter(name: "T", bound: nil)],
                                       returnType: .int)),
            ("listIsEmpty",  .function(parameterTypes: [.classType(name: "List", typeArguments: [])],
                                       returnType: .bool)),
            ("listClear",    .function(parameterTypes: [.classType(name: "List", typeArguments: [])],
                                       returnType: .unit)),

            // HashMap operations
            ("mapCreate",      .function(parameterTypes: [],
                                         returnType: .classType(name: "Map", typeArguments: []))),
            ("mapPut",         .function(parameterTypes: [.classType(name: "Map", typeArguments: []), .typeParameter(name: "K", bound: nil), .typeParameter(name: "V", bound: nil)],
                                         returnType: .unit)),
            ("mapGet",         .function(parameterTypes: [.classType(name: "Map", typeArguments: []), .typeParameter(name: "K", bound: nil)],
                                         returnType: .nullable(.typeParameter(name: "V", bound: nil)))),
            ("mapRemove",      .function(parameterTypes: [.classType(name: "Map", typeArguments: []), .typeParameter(name: "K", bound: nil)],
                                         returnType: .nullable(.typeParameter(name: "V", bound: nil)))),
            ("mapContainsKey", .function(parameterTypes: [.classType(name: "Map", typeArguments: []), .typeParameter(name: "K", bound: nil)],
                                         returnType: .bool)),
            ("mapKeys",        .function(parameterTypes: [.classType(name: "Map", typeArguments: [])],
                                         returnType: .classType(name: "List", typeArguments: []))),
            ("mapValues",      .function(parameterTypes: [.classType(name: "Map", typeArguments: [])],
                                         returnType: .classType(name: "List", typeArguments: []))),
            ("mapSize",        .function(parameterTypes: [.classType(name: "Map", typeArguments: [])],
                                         returnType: .int)),
            ("mapIsEmpty",     .function(parameterTypes: [.classType(name: "Map", typeArguments: [])],
                                         returnType: .bool)),
            ("mapClear",       .function(parameterTypes: [.classType(name: "Map", typeArguments: [])],
                                         returnType: .unit)),
        ]

        for (name, type) in collectionBuiltins {
            globalScope.define(Symbol(name: name, type: type, kind: .function))
        }
    }
}
