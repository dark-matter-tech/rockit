package main

import "fmt"

const (
	TOK_ILLEGAL    = 0
	TOK_EOF        = 1
	TOK_IDENT      = 2
	TOK_INT        = 3
	TOK_ASSIGN     = 4
	TOK_PLUS       = 5
	TOK_MINUS      = 6
	TOK_BANG       = 7
	TOK_SLASH      = 8
	TOK_ASTERISK   = 9
	TOK_LT         = 10
	TOK_GT         = 11
	TOK_EQ         = 12
	TOK_NOT_EQ     = 13
	TOK_COMMA      = 14
	TOK_SEMICOLON  = 15
	TOK_LPAREN     = 16
	TOK_RPAREN     = 17
	TOK_LBRACE     = 18
	TOK_RBRACE     = 19
	TOK_FUNCTION   = 20
	TOK_LET        = 21
	TOK_IF         = 22
	TOK_ELSE       = 23
	TOK_RETURN     = 24
	TOK_TRUE       = 25
	TOK_FALSE      = 26
	PREC_LOWEST      = 1
	PREC_EQUALS      = 2
	PREC_LESSGREATER = 3
	PREC_SUM         = 4
	PREC_PRODUCT     = 5
	PREC_PREFIX      = 6
	PREC_CALL        = 7
)

var lexInput string
var lexPos int
var lexReadPos int
var lexCh byte
var tokType int
var tokLiteral string
var curType int
var curLiteral string
var peekType int
var peekLiteral string

func lexReadChar() {
	if lexReadPos >= len(lexInput) {
		lexCh = 0
	} else {
		lexCh = lexInput[lexReadPos]
	}
	lexPos = lexReadPos
	lexReadPos++
}

func lexPeekChar() byte {
	if lexReadPos >= len(lexInput) {
		return 0
	}
	return lexInput[lexReadPos]
}

func lexInit(input string) {
	lexInput = input
	lexPos = 0
	lexReadPos = 0
	lexCh = 0
	lexReadChar()
}

func lexSkipWhitespace() {
	for lexCh == ' ' || lexCh == '\t' || lexCh == '\n' || lexCh == '\r' {
		lexReadChar()
	}
}

func isLetterChar(ch byte) bool {
	return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch == '_'
}

func isDigitChar(ch byte) bool {
	return ch >= '0' && ch <= '9'
}

func lexReadIdentifier() string {
	start := lexPos
	for isLetterChar(lexCh) {
		lexReadChar()
	}
	return lexInput[start:lexPos]
}

func lexReadNumber() string {
	start := lexPos
	for isDigitChar(lexCh) {
		lexReadChar()
	}
	return lexInput[start:lexPos]
}

func lookupKeyword(ident string) int {
	switch ident {
	case "fn":
		return TOK_FUNCTION
	case "let":
		return TOK_LET
	case "if":
		return TOK_IF
	case "else":
		return TOK_ELSE
	case "return":
		return TOK_RETURN
	case "true":
		return TOK_TRUE
	case "false":
		return TOK_FALSE
	}
	return TOK_IDENT
}

func nextToken() {
	lexSkipWhitespace()
	switch {
	case lexCh == '=':
		if lexPeekChar() == '=' {
			lexReadChar()
			tokType = TOK_EQ
			tokLiteral = "=="
		} else {
			tokType = TOK_ASSIGN
			tokLiteral = "="
		}
	case lexCh == '+':
		tokType = TOK_PLUS
		tokLiteral = "+"
	case lexCh == '-':
		tokType = TOK_MINUS
		tokLiteral = "-"
	case lexCh == '!':
		if lexPeekChar() == '=' {
			lexReadChar()
			tokType = TOK_NOT_EQ
			tokLiteral = "!="
		} else {
			tokType = TOK_BANG
			tokLiteral = "!"
		}
	case lexCh == '/':
		tokType = TOK_SLASH
		tokLiteral = "/"
	case lexCh == '*':
		tokType = TOK_ASTERISK
		tokLiteral = "*"
	case lexCh == '<':
		tokType = TOK_LT
		tokLiteral = "<"
	case lexCh == '>':
		tokType = TOK_GT
		tokLiteral = ">"
	case lexCh == ',':
		tokType = TOK_COMMA
		tokLiteral = ","
	case lexCh == ';':
		tokType = TOK_SEMICOLON
		tokLiteral = ";"
	case lexCh == '(':
		tokType = TOK_LPAREN
		tokLiteral = "("
	case lexCh == ')':
		tokType = TOK_RPAREN
		tokLiteral = ")"
	case lexCh == '{':
		tokType = TOK_LBRACE
		tokLiteral = "{"
	case lexCh == '}':
		tokType = TOK_RBRACE
		tokLiteral = "}"
	case lexCh == 0:
		tokType = TOK_EOF
		tokLiteral = ""
	case isLetterChar(lexCh):
		tokLiteral = lexReadIdentifier()
		tokType = lookupKeyword(tokLiteral)
		return
	case isDigitChar(lexCh):
		tokLiteral = lexReadNumber()
		tokType = TOK_INT
		return
	default:
		tokType = TOK_ILLEGAL
		tokLiteral = string(lexCh)
	}
	lexReadChar()
}

func parserInit(input string) {
	lexInit(input)
	curType = TOK_EOF
	curLiteral = ""
	peekType = TOK_EOF
	peekLiteral = ""
	parserAdvance()
	parserAdvance()
}

func parserAdvance() {
	curType = peekType
	curLiteral = peekLiteral
	nextToken()
	peekType = tokType
	peekLiteral = tokLiteral
}

func expectPeek(t int) bool {
	if peekType == t {
		parserAdvance()
		return true
	}
	return false
}

func peekPrecedence() int {
	switch peekType {
	case TOK_EQ, TOK_NOT_EQ:
		return PREC_EQUALS
	case TOK_LT, TOK_GT:
		return PREC_LESSGREATER
	case TOK_PLUS, TOK_MINUS:
		return PREC_SUM
	case TOK_SLASH, TOK_ASTERISK:
		return PREC_PRODUCT
	case TOK_LPAREN:
		return PREC_CALL
	}
	return PREC_LOWEST
}

func curPrecedence() int {
	switch curType {
	case TOK_EQ, TOK_NOT_EQ:
		return PREC_EQUALS
	case TOK_LT, TOK_GT:
		return PREC_LESSGREATER
	case TOK_PLUS, TOK_MINUS:
		return PREC_SUM
	case TOK_SLASH, TOK_ASTERISK:
		return PREC_PRODUCT
	case TOK_LPAREN:
		return PREC_CALL
	}
	return PREC_LOWEST
}

func hasInfix(t int) bool {
	return t == TOK_PLUS || t == TOK_MINUS || t == TOK_SLASH ||
		t == TOK_ASTERISK || t == TOK_EQ || t == TOK_NOT_EQ ||
		t == TOK_LT || t == TOK_GT || t == TOK_LPAREN
}

func parseExpression(precedence int) string {
	var left string
	switch {
	case curType == TOK_IDENT:
		left = curLiteral
	case curType == TOK_INT:
		left = curLiteral
	case curType == TOK_TRUE:
		left = "true"
	case curType == TOK_FALSE:
		left = "false"
	case curType == TOK_BANG || curType == TOK_MINUS:
		op := curLiteral
		parserAdvance()
		right := parseExpression(PREC_PREFIX)
		left = "(" + op + right + ")"
	case curType == TOK_LPAREN:
		parserAdvance()
		left = parseExpression(PREC_LOWEST)
		if peekType == TOK_RPAREN {
			parserAdvance()
		}
	case curType == TOK_IF:
		left = parseIfExpression()
	case curType == TOK_FUNCTION:
		left = parseFunctionLiteral()
	default:
		left = "?"
	}
	for peekType != TOK_SEMICOLON && precedence < peekPrecedence() {
		if !hasInfix(peekType) {
			return left
		}
		parserAdvance()
		if curType == TOK_LPAREN {
			left = parseCallExpression(left)
		} else {
			op := curLiteral
			prec := curPrecedence()
			parserAdvance()
			right := parseExpression(prec)
			left = "(" + left + " " + op + " " + right + ")"
		}
	}
	return left
}

func parseIfExpression() string {
	result := "if"
	if !expectPeek(TOK_LPAREN) { return result }
	parserAdvance()
	condition := parseExpression(PREC_LOWEST)
	result = result + condition
	if !expectPeek(TOK_RPAREN) { return result }
	if !expectPeek(TOK_LBRACE) { return result }
	consequence := parseBlockStatement()
	result = result + consequence
	if peekType == TOK_ELSE {
		parserAdvance()
		if !expectPeek(TOK_LBRACE) { return result }
		alternative := parseBlockStatement()
		result = result + "else" + alternative
	}
	return result
}

func parseFunctionLiteral() string {
	result := "fn"
	if !expectPeek(TOK_LPAREN) { return result }
	params := parseFunctionParameters()
	result = result + "(" + params + ")"
	if !expectPeek(TOK_LBRACE) { return result }
	body := parseBlockStatement()
	result = result + body
	return result
}

func parseFunctionParameters() string {
	result := ""
	if peekType == TOK_RPAREN {
		parserAdvance()
		return result
	}
	parserAdvance()
	result = curLiteral
	for peekType == TOK_COMMA {
		parserAdvance()
		parserAdvance()
		result = result + ", " + curLiteral
	}
	expectPeek(TOK_RPAREN)
	return result
}

func parseCallExpression(function string) string {
	args := parseCallArguments()
	return function + "(" + args + ")"
}

func parseCallArguments() string {
	result := ""
	if peekType == TOK_RPAREN {
		parserAdvance()
		return result
	}
	parserAdvance()
	result = parseExpression(PREC_LOWEST)
	for peekType == TOK_COMMA {
		parserAdvance()
		parserAdvance()
		result = result + ", " + parseExpression(PREC_LOWEST)
	}
	expectPeek(TOK_RPAREN)
	return result
}

func parseBlockStatement() string {
	result := ""
	parserAdvance()
	for curType != TOK_RBRACE && curType != TOK_EOF {
		stmt := parseStatement()
		if len(stmt) > 0 {
			result = result + stmt
		}
		parserAdvance()
	}
	return result
}

func parseStatement() string {
	if curType == TOK_LET {
		return parseLetStatement()
	}
	if curType == TOK_RETURN {
		return parseReturnStatement()
	}
	return parseExpressionStatement()
}

func parseLetStatement() string {
	if !expectPeek(TOK_IDENT) { return "" }
	name := curLiteral
	if !expectPeek(TOK_ASSIGN) { return "" }
	parserAdvance()
	value := parseExpression(PREC_LOWEST)
	if peekType == TOK_SEMICOLON {
		parserAdvance()
	}
	return "let " + name + " = " + value + ";"
}

func parseReturnStatement() string {
	parserAdvance()
	value := parseExpression(PREC_LOWEST)
	if peekType == TOK_SEMICOLON {
		parserAdvance()
	}
	return "return " + value + ";"
}

func parseExpressionStatement() string {
	expr := parseExpression(PREC_LOWEST)
	if peekType == TOK_SEMICOLON {
		parserAdvance()
	}
	return expr
}

func parseProgram() string {
	result := ""
	for curType != TOK_EOF {
		stmt := parseStatement()
		if len(stmt) > 0 {
			result = result + stmt
		}
		parserAdvance()
	}
	return result
}

func main() {
	input := "let five = 5;\nlet ten = 10;\nlet add = fn(x, y) { x + y; };\nlet result = add(five, ten);\n!-/*5;\n5 < 10 > 5;\nif (5 < 10) { return true; } else { return false; }\n10 == 10;\n10 != 9;\n"
	N := 100000
	resultLen := 0
	for i := 0; i < N; i++ {
		parserInit(input)
		result := parseProgram()
		resultLen = len(result)
	}
	fmt.Println(resultLen)
}
