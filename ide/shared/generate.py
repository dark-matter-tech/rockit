#!/usr/bin/env python3
"""
Rockit Syntax Highlighting Generator
Dark Matter Tech

Reads rockit-language.json (the single source of truth) and generates
editor-specific syntax files:
  - TextMate grammar (.tmLanguage.json) for VS Code / Sublime / GitHub
  - Vim syntax file (rockit.vim)

Usage:
  python3 generate.py                  # generate all
  python3 generate.py --textmate       # generate only TextMate grammar
  python3 generate.py --vim            # generate only Vim syntax
"""

import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LANG_FILE = os.path.join(SCRIPT_DIR, "rockit-language.json")


def load_language():
    with open(LANG_FILE, "r") as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# TextMate Grammar Generator (.tmLanguage.json)
# ---------------------------------------------------------------------------

def generate_textmate(lang):
    """Generate a TextMate grammar from the canonical language definition."""
    kw = lang["keywords"]
    all_declaration = kw["declaration"]
    all_control = kw["controlFlow"]
    all_rockit = kw["rockit"]
    all_literal = kw["literal"]
    builtin_types = lang["builtinTypes"]
    builtin_funcs = lang["builtinFunctions"]
    bool_prefixes = lang["booleanPrefixes"]

    def word_pattern(words):
        return "\\b(" + "|".join(sorted(words, key=len, reverse=True)) + ")\\b"

    grammar = {
        "$schema": "https://raw.githubusercontent.com/martinring/tmlanguage/master/tmlanguage.json",
        "name": "Rockit",
        "scopeName": "source.rockit",
        "fileTypes": ["rok"],
        "patterns": [
            {"include": "#comments"},
            {"include": "#strings"},
            {"include": "#numbers"},
            {"include": "#annotations"},
            {"include": "#keywords"},
            {"include": "#builtins"},
            {"include": "#operators"},
            {"include": "#identifiers"},
        ],
        "repository": {
            # --- Comments ---
            "comments": {
                "patterns": [
                    {
                        "name": "comment.line.double-slash.rockit",
                        "match": "//.*$"
                    },
                    {
                        "name": "comment.block.rockit",
                        "begin": "/\\*",
                        "end": "\\*/",
                        "patterns": [
                            {"include": "#comments"}
                        ]
                    }
                ]
            },

            # --- Strings ---
            "strings": {
                "patterns": [
                    # Multiline strings (must come before single-line)
                    {
                        "name": "string.quoted.triple.rockit",
                        "begin": '"""',
                        "end": '"""',
                        "patterns": [
                            {"include": "#string-interpolation"},
                            {"include": "#string-escapes"}
                        ]
                    },
                    # Single-line strings
                    {
                        "name": "string.quoted.double.rockit",
                        "begin": '"',
                        "end": '"',
                        "patterns": [
                            {"include": "#string-interpolation"},
                            {"include": "#string-escapes"}
                        ]
                    }
                ]
            },

            "string-escapes": {
                "patterns": [
                    {
                        "name": "constant.character.escape.rockit",
                        "match": "\\\\([\\\\\"/ntr0'$]|u\\{[0-9a-fA-F]+\\})"
                    }
                ]
            },

            "string-interpolation": {
                "patterns": [
                    # ${expression} interpolation
                    {
                        "name": "meta.interpolation.rockit",
                        "begin": "\\$\\{",
                        "end": "\\}",
                        "beginCaptures": {
                            "0": {"name": "punctuation.definition.interpolation.begin.rockit"}
                        },
                        "endCaptures": {
                            "0": {"name": "punctuation.definition.interpolation.end.rockit"}
                        },
                        "patterns": [
                            {"include": "source.rockit"}
                        ]
                    },
                    # $identifier interpolation
                    {
                        "name": "variable.other.interpolation.rockit",
                        "match": "\\$[a-zA-Z_][a-zA-Z0-9_]*"
                    }
                ]
            },

            # --- Numbers ---
            "numbers": {
                "patterns": [
                    # Hex
                    {
                        "name": "constant.numeric.hex.rockit",
                        "match": "\\b0[xX][0-9a-fA-F]([0-9a-fA-F_]*[0-9a-fA-F])?\\b"
                    },
                    # Binary
                    {
                        "name": "constant.numeric.binary.rockit",
                        "match": "\\b0[bB][01]([01_]*[01])?\\b"
                    },
                    # Float (must come before integer)
                    {
                        "name": "constant.numeric.float.rockit",
                        "match": "\\b[0-9]([0-9_]*[0-9])?(\\.[0-9]([0-9_]*[0-9])?)?[eE][+-]?[0-9]([0-9_]*[0-9])?\\b"
                    },
                    {
                        "name": "constant.numeric.float.rockit",
                        "match": "\\b[0-9]([0-9_]*[0-9])?\\.[0-9]([0-9_]*[0-9])?\\b"
                    },
                    # Integer
                    {
                        "name": "constant.numeric.integer.rockit",
                        "match": "\\b[0-9]([0-9_]*[0-9])?\\b"
                    }
                ]
            },

            # --- Annotations ---
            "annotations": {
                "patterns": [
                    {
                        "name": "storage.type.annotation.rockit",
                        "match": "@[a-zA-Z_][a-zA-Z0-9_]*"
                    }
                ]
            },

            # --- Keywords ---
            "keywords": {
                "patterns": [
                    # Rockit-specific keywords (purple) — must come before declaration
                    {
                        "name": "keyword.other.rockit.rockit",
                        "match": word_pattern(all_rockit)
                    },
                    # Boolean literals
                    {
                        "name": "constant.language.boolean.rockit",
                        "match": "\\b(true|false)\\b"
                    },
                    # Null literal
                    {
                        "name": "constant.language.null.rockit",
                        "match": "\\b(null)\\b"
                    },
                    # Control flow keywords
                    {
                        "name": "keyword.control.rockit",
                        "match": word_pattern(all_control)
                    },
                    # Declaration keywords
                    {
                        "name": "keyword.declaration.rockit",
                        "match": word_pattern(all_declaration)
                    },
                ]
            },

            # --- Built-in types and functions ---
            "builtins": {
                "patterns": [
                    {
                        "name": "support.type.builtin.rockit",
                        "match": word_pattern(builtin_types)
                    },
                    {
                        "name": "support.function.builtin.rockit",
                        "match": word_pattern(builtin_funcs)
                    }
                ]
            },

            # --- Operators ---
            "operators": {
                "patterns": [
                    # Force unwrap (must come before !)
                    {
                        "name": "keyword.operator.force-unwrap.rockit",
                        "match": "!!"
                    },
                    # Optional operators
                    {
                        "name": "keyword.operator.optional.rockit",
                        "match": "\\?\\.|\\.\\.\\.?<|\\?:|\\?"
                    },
                    # Range operators
                    {
                        "name": "keyword.operator.range.rockit",
                        "match": "\\.\\.<|\\.\\."
                    },
                    # Arrow operators
                    {
                        "name": "keyword.operator.arrow.rockit",
                        "match": "->|=>"
                    },
                    # Scope resolution
                    {
                        "name": "keyword.operator.scope.rockit",
                        "match": "::"
                    },
                    # Compound assignment
                    {
                        "name": "keyword.operator.assignment.compound.rockit",
                        "match": "[+\\-*/%]="
                    },
                    # Comparison
                    {
                        "name": "keyword.operator.comparison.rockit",
                        "match": "==|!=|<=|>="
                    },
                    # Logical
                    {
                        "name": "keyword.operator.logical.rockit",
                        "match": "&&|\\|\\||!"
                    },
                    # Assignment
                    {
                        "name": "keyword.operator.assignment.rockit",
                        "match": "="
                    }
                ]
            },

            # --- Identifiers ---
            "identifiers": {
                "patterns": [
                    # Function declarations
                    {
                        "match": "\\b(fun)\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
                        "captures": {
                            "1": {"name": "keyword.declaration.rockit"},
                            "2": {"name": "entity.name.function.rockit"}
                        }
                    },
                    # Class/interface/enum/object/actor/view declarations
                    {
                        "match": "\\b(class|interface|enum|object|actor|view|data\\s+class|sealed\\s+class)\\s+([a-zA-Z_][a-zA-Z0-9_]*)",
                        "captures": {
                            "1": {"name": "keyword.declaration.rockit"},
                            "2": {"name": "entity.name.type.rockit"}
                        }
                    },
                    # Function calls
                    {
                        "match": "\\b([a-zA-Z_][a-zA-Z0-9_]*)\\s*(?=\\()",
                        "captures": {
                            "1": {"name": "entity.name.function.call.rockit"}
                        }
                    }
                ]
            }
        }
    }

    return grammar


# ---------------------------------------------------------------------------
# Vim Syntax Generator (rockit.vim)
# ---------------------------------------------------------------------------

def generate_vim(lang):
    """Generate a Vim syntax file from the canonical language definition."""
    kw = lang["keywords"]
    builtin_types = lang["builtinTypes"]
    builtin_funcs = lang["builtinFunctions"]
    bool_prefixes = lang["booleanPrefixes"]
    theme = lang["theme"]

    lines = []
    lines.append('" Vim syntax file for the Rockit programming language')
    lines.append('" Language: Rockit (.rok)')
    lines.append('" Maintainer: Dark Matter Tech')
    lines.append('" Generated from rockit-language.json — DO NOT EDIT MANUALLY')
    lines.append('')
    lines.append('if exists("b:current_syntax")')
    lines.append('  finish')
    lines.append('endif')
    lines.append('')

    # Keywords
    lines.append('" --- Keywords ---')
    lines.append('syn keyword rockitDeclaration ' + ' '.join(kw["declaration"]))
    lines.append('syn keyword rockitControl ' + ' '.join(kw["controlFlow"]))
    lines.append('syn keyword rockitRockit ' + ' '.join(kw["rockit"]))
    lines.append('syn keyword rockitBoolean true false')
    lines.append('syn keyword rockitNull null')
    lines.append('')

    # Built-in types and functions
    lines.append('" --- Built-in types ---')
    lines.append('syn keyword rockitBuiltinType ' + ' '.join(builtin_types))
    lines.append('')
    lines.append('" --- Built-in functions ---')
    lines.append('syn keyword rockitBuiltinFunction ' + ' '.join(builtin_funcs))
    lines.append('')

    # Operators
    lines.append('" --- Operators ---')
    lines.append('syn match rockitForceUnwrap "!!"')
    lines.append('syn match rockitOptionalOp "\\?\\."')
    lines.append('syn match rockitOptionalOp "\\?:"')
    lines.append('syn match rockitRangeOp "\\.\\.<"')
    lines.append('syn match rockitRangeOp "\\.\\."')
    lines.append('syn match rockitArrow "->"')
    lines.append('syn match rockitArrow "=>"')
    lines.append('syn match rockitScopeOp "::"')
    lines.append('')

    # Numbers
    lines.append('" --- Numbers ---')
    lines.append('syn match rockitNumber "\\<0[xX][0-9a-fA-F_]\\+\\>"')
    lines.append('syn match rockitNumber "\\<0[bB][01_]\\+\\>"')
    lines.append('syn match rockitFloat "\\<[0-9][0-9_]*\\.[0-9][0-9_]*\\([eE][+-]\\?[0-9_]\\+\\)\\?\\>"')
    lines.append('syn match rockitFloat "\\<[0-9][0-9_]*[eE][+-]\\?[0-9_]\\+\\>"')
    lines.append('syn match rockitNumber "\\<[0-9][0-9_]*\\>"')
    lines.append('')

    # Strings
    lines.append('" --- Strings ---')
    lines.append('syn region rockitString start=\'"\' skip=\'\\\\\\\\\\|\\\\"\' end=\'"\' contains=rockitStringEscape,rockitStringInterp,rockitStringInterpExpr')
    lines.append("syn match rockitStringEscape " + r'"\\[\\\"\/ntr0' + "'" + r'$]" contained')
    lines.append('syn match rockitStringEscape "\\\\u{[0-9a-fA-F]\\+}" contained')
    lines.append('syn match rockitStringInterp "\\$[a-zA-Z_][a-zA-Z0-9_]*" contained')
    lines.append('syn region rockitStringInterpExpr start="\\${" end="}" contained contains=TOP')
    lines.append('')

    # Comments
    lines.append('" --- Comments ---')
    lines.append('syn match rockitLineComment "\\/\\/.*$"')
    lines.append('syn region rockitBlockComment start="/\\*" end="\\*/" contains=rockitBlockComment')
    lines.append('')

    # Annotations
    lines.append('" --- Annotations ---')
    lines.append('syn match rockitAnnotation "@[a-zA-Z_][a-zA-Z0-9_]*"')
    lines.append('')

    # Function/type declarations
    lines.append('" --- Declarations ---')
    lines.append('syn match rockitFunctionDecl "\\<fun\\>\\s\\+\\zs[a-zA-Z_][a-zA-Z0-9_]*"')
    lines.append('syn match rockitTypeDecl "\\<\\(class\\|interface\\|enum\\|object\\|actor\\|view\\)\\>\\s\\+\\zs[a-zA-Z_][a-zA-Z0-9_]*"')
    lines.append('')

    # Highlight links
    lines.append('" --- Highlight links ---')
    lines.append('hi def link rockitDeclaration   Keyword')
    lines.append('hi def link rockitControl        Conditional')
    lines.append('hi def link rockitRockit          Keyword')
    lines.append('hi def link rockitBoolean         Boolean')
    lines.append('hi def link rockitNull            Constant')
    lines.append('hi def link rockitBuiltinType     Type')
    lines.append('hi def link rockitBuiltinFunction Function')
    lines.append('hi def link rockitForceUnwrap     WarningMsg')
    lines.append('hi def link rockitOptionalOp      Operator')
    lines.append('hi def link rockitRangeOp         Operator')
    lines.append('hi def link rockitArrow           Operator')
    lines.append('hi def link rockitScopeOp         Operator')
    lines.append('hi def link rockitNumber          Number')
    lines.append('hi def link rockitFloat           Float')
    lines.append('hi def link rockitString          String')
    lines.append('hi def link rockitStringEscape    SpecialChar')
    lines.append('hi def link rockitStringInterp    Special')
    lines.append('hi def link rockitStringInterpExpr Special')
    lines.append('hi def link rockitLineComment     Comment')
    lines.append('hi def link rockitBlockComment    Comment')
    lines.append('hi def link rockitAnnotation      PreProc')
    lines.append('hi def link rockitFunctionDecl    Function')
    lines.append('hi def link rockitTypeDecl        Type')
    lines.append('')

    # Custom Rockit-specific highlights using theme colors
    lines.append('" --- Rockit theme colors (for colorschemes that support it) ---')
    lines.append('" These use the canonical colors from rockit-language.json.')
    lines.append('" Override in your colorscheme or vimrc if desired.')
    for name, info in theme.items():
        if name.startswith("$"):
            continue
        light, dark = info["color"]
        style = info["style"]
        vim_group = "rockit" + name[0].upper() + name[1:]
        gui_style = ""
        if style == "bold":
            gui_style = " gui=bold cterm=bold"
        elif style == "italic":
            gui_style = " gui=italic cterm=italic"
        elif style == "bold-italic":
            gui_style = " gui=bold,italic cterm=bold,italic"
        lines.append(f'" hi {vim_group} guifg={dark}{gui_style}')
    lines.append('')

    lines.append('let b:current_syntax = "rockit"')
    lines.append('')

    return '\n'.join(lines)


# ---------------------------------------------------------------------------
# Vim ftdetect (rockit.vim)
# ---------------------------------------------------------------------------

def generate_vim_ftdetect():
    return (
        '" Vim filetype detection for Rockit (.rok)\n'
        '" Generated from rockit-language.json — DO NOT EDIT MANUALLY\n'
        '\n'
        'au BufRead,BufNewFile *.rok set filetype=rockit\n'
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if isinstance(content, dict):
        with open(path, "w") as f:
            json.dump(content, f, indent=2)
            f.write("\n")
    else:
        with open(path, "w") as f:
            f.write(content)
    print(f"  Generated: {os.path.relpath(path, SCRIPT_DIR)}")


def main():
    args = sys.argv[1:]
    do_all = not args
    do_textmate = do_all or "--textmate" in args
    do_vim = do_all or "--vim" in args

    print("Rockit Syntax Generator")
    print(f"  Source: {os.path.basename(LANG_FILE)}")
    print()

    lang = load_language()

    if do_textmate:
        grammar = generate_textmate(lang)
        write_file(
            os.path.join(SCRIPT_DIR, "..", "vscode", "syntaxes", "rockit.tmLanguage.json"),
            grammar
        )

    if do_vim:
        vim_syntax = generate_vim(lang)
        vim_ftdetect = generate_vim_ftdetect()
        write_file(
            os.path.join(SCRIPT_DIR, "..", "vim", "syntax", "rockit.vim"),
            vim_syntax
        )
        write_file(
            os.path.join(SCRIPT_DIR, "..", "vim", "ftdetect", "rockit.vim"),
            vim_ftdetect
        )

    print()
    print("Done. To add a keyword, edit rockit-language.json and re-run this script.")


if __name__ == "__main__":
    main()
