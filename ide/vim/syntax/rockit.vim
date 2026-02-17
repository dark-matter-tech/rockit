" Vim syntax file for the Rockit programming language
" Language: Rockit (.rok)
" Maintainer: Dark Matter Tech
" Generated from rockit-language.json — DO NOT EDIT MANUALLY

if exists("b:current_syntax")
  finish
endif

" --- Keywords ---
syn keyword rockitDeclaration fun val var class interface object enum data sealed abstract open override private internal public protected companion typealias vararg import package this super constructor init where out
syn keyword rockitControl if else when for while do return break continue in is as throw try catch finally
syn keyword rockitRockit view actor navigation route theme style suspend async await concurrent weak unowned
syn keyword rockitBoolean true false
syn keyword rockitNull null

" --- Built-in types ---
syn keyword rockitBuiltinType Int Int8 Int16 Int32 Int64 UInt UInt8 UInt16 UInt32 UInt64 Float Double Bool String Char Any Unit Nothing Void List Map Set Array Pair Triple Result Optional Sequence Iterable Comparable Throwable Error Exception

" --- Built-in functions ---
syn keyword rockitBuiltinFunction println print readLine assert listOf mapOf setOf arrayOf mutableListOf mutableMapOf mutableSetOf maxOf minOf repeat TODO require check error

" --- Operators ---
syn match rockitForceUnwrap "!!"
syn match rockitOptionalOp "\?\."
syn match rockitOptionalOp "\?:"
syn match rockitRangeOp "\.\.<"
syn match rockitRangeOp "\.\."
syn match rockitArrow "->"
syn match rockitArrow "=>"
syn match rockitScopeOp "::"

" --- Numbers ---
syn match rockitNumber "\<0[xX][0-9a-fA-F_]\+\>"
syn match rockitNumber "\<0[bB][01_]\+\>"
syn match rockitFloat "\<[0-9][0-9_]*\.[0-9][0-9_]*\([eE][+-]\?[0-9_]\+\)\?\>"
syn match rockitFloat "\<[0-9][0-9_]*[eE][+-]\?[0-9_]\+\>"
syn match rockitNumber "\<[0-9][0-9_]*\>"

" --- Strings ---
syn region rockitString start='"' skip='\\\\\|\\"' end='"' contains=rockitStringEscape,rockitStringInterp,rockitStringInterpExpr
syn match rockitStringEscape "\\[\\\"\/ntr0'$]" contained
syn match rockitStringEscape "\\u{[0-9a-fA-F]\+}" contained
syn match rockitStringInterp "\$[a-zA-Z_][a-zA-Z0-9_]*" contained
syn region rockitStringInterpExpr start="\${" end="}" contained contains=TOP

" --- Comments ---
syn match rockitLineComment "\/\/.*$"
syn region rockitBlockComment start="/\*" end="\*/" contains=rockitBlockComment

" --- Annotations ---
syn match rockitAnnotation "@[a-zA-Z_][a-zA-Z0-9_]*"

" --- Declarations ---
syn match rockitFunctionDecl "\<fun\>\s\+\zs[a-zA-Z_][a-zA-Z0-9_]*"
syn match rockitTypeDecl "\<\(class\|interface\|enum\|object\|actor\|view\)\>\s\+\zs[a-zA-Z_][a-zA-Z0-9_]*"

" --- Highlight links ---
hi def link rockitDeclaration   Keyword
hi def link rockitControl        Conditional
hi def link rockitRockit          Keyword
hi def link rockitBoolean         Boolean
hi def link rockitNull            Constant
hi def link rockitBuiltinType     Type
hi def link rockitBuiltinFunction Function
hi def link rockitForceUnwrap     WarningMsg
hi def link rockitOptionalOp      Operator
hi def link rockitRangeOp         Operator
hi def link rockitArrow           Operator
hi def link rockitScopeOp         Operator
hi def link rockitNumber          Number
hi def link rockitFloat           Float
hi def link rockitString          String
hi def link rockitStringEscape    SpecialChar
hi def link rockitStringInterp    Special
hi def link rockitStringInterpExpr Special
hi def link rockitLineComment     Comment
hi def link rockitBlockComment    Comment
hi def link rockitAnnotation      PreProc
hi def link rockitFunctionDecl    Function
hi def link rockitTypeDecl        Type

" --- Rockit theme colors (for colorschemes that support it) ---
" These use the canonical colors from rockit-language.json.
" Override in your colorscheme or vimrc if desired.
" hi rockitKeyword guifg=#FF7AB2 gui=bold cterm=bold
" hi rockitControlKeyword guifg=#FF7AB2 gui=bold cterm=bold
" hi rockitRockitKeyword guifg=#B381CF gui=bold cterm=bold
" hi rockitBooleanLiteral guifg=#FFA030 gui=bold cterm=bold
" hi rockitNullLiteral guifg=#FF6B68 gui=bold cterm=bold
" hi rockitOptionalOperator guifg=#56B6C2 gui=bold cterm=bold
" hi rockitForceUnwrap guifg=#FF6B68 gui=bold cterm=bold
" hi rockitBuiltinType guifg=#5DD8B4
" hi rockitBuiltinFunction guifg=#67B7A4 gui=italic cterm=italic
" hi rockitString guifg=#FC6A5D
" hi rockitStringEscape guifg=#E9B96E gui=bold cterm=bold
" hi rockitStringInterpolation guifg=#41A1C0 gui=bold cterm=bold
" hi rockitNumber guifg=#D0BF69
" hi rockitLineComment guifg=#7F8C98 gui=italic cterm=italic
" hi rockitBlockComment guifg=#7F8C98 gui=italic cterm=italic
" hi rockitAnnotation guifg=#FFA14F
" hi rockitIdentifier guifg=#D4D4D4

let b:current_syntax = "rockit"
