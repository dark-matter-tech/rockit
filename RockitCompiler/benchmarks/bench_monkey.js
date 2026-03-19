// bench_monkey.js — Monkey Language Lexer/Parser
// Single-threaded reference implementation

const TOK_ILLEGAL = 0;
const TOK_EOF = 1;
const TOK_IDENT = 2;
const TOK_INT = 3;
const TOK_ASSIGN = 4;
const TOK_PLUS = 5;
const TOK_MINUS = 6;
const TOK_BANG = 7;
const TOK_SLASH = 8;
const TOK_ASTERISK = 9;
const TOK_LT = 10;
const TOK_GT = 11;
const TOK_EQ = 12;
const TOK_NOT_EQ = 13;
const TOK_COMMA = 14;
const TOK_SEMICOLON = 15;
const TOK_LPAREN = 16;
const TOK_RPAREN = 17;
const TOK_LBRACE = 18;
const TOK_RBRACE = 19;
const TOK_FUNCTION = 20;
const TOK_LET = 21;
const TOK_IF = 22;
const TOK_ELSE = 23;
const TOK_RETURN = 24;
const TOK_TRUE = 25;
const TOK_FALSE = 26;
const PREC_LOWEST = 1;
const PREC_EQUALS = 2;
const PREC_LESSGREATER = 3;
const PREC_SUM = 4;
const PREC_PRODUCT = 5;
const PREC_PREFIX = 6;
const PREC_CALL = 7;

let lexInput = "";
let lexPos = 0;
let lexReadPos = 0;
let lexCh = 0;
let tokType = 0;
let tokLiteral = "";
let curType = 0;
let curLiteral = "";
let peekType = 0;
let peekLiteral = "";

function lexReadChar() {
    if (lexReadPos >= lexInput.length) {
        lexCh = 0;
    } else {
        lexCh = lexInput.charCodeAt(lexReadPos);
    }
    lexPos = lexReadPos;
    lexReadPos++;
}

function lexPeekChar() {
    if (lexReadPos >= lexInput.length) {
        return 0;
    }
    return lexInput.charCodeAt(lexReadPos);
}

function lexInit(input) {
    lexInput = input;
    lexPos = 0;
    lexReadPos = 0;
    lexCh = 0;
    lexReadChar();
}

function lexSkipWhitespace() {
    while (lexCh === 32 || lexCh === 9 || lexCh === 10 || lexCh === 13) {
        lexReadChar();
    }
}

function isLetterChar(ch) {
    return (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) || ch === 95;
}

function isDigitChar(ch) {
    return ch >= 48 && ch <= 57;
}

function lexReadIdentifier() {
    const start = lexPos;
    while (isLetterChar(lexCh)) {
        lexReadChar();
    }
    return lexInput.substring(start, lexPos);
}

function lexReadNumber() {
    const start = lexPos;
    while (isDigitChar(lexCh)) {
        lexReadChar();
    }
    return lexInput.substring(start, lexPos);
}

function lookupKeyword(ident) {
    switch (ident) {
        case "fn": return TOK_FUNCTION;
        case "let": return TOK_LET;
        case "if": return TOK_IF;
        case "else": return TOK_ELSE;
        case "return": return TOK_RETURN;
        case "true": return TOK_TRUE;
        case "false": return TOK_FALSE;
        default: return TOK_IDENT;
    }
}

function nextToken() {
    lexSkipWhitespace();
    if (lexCh === 61) { // =
        if (lexPeekChar() === 61) {
            lexReadChar();
            tokType = TOK_EQ;
            tokLiteral = "==";
        } else {
            tokType = TOK_ASSIGN;
            tokLiteral = "=";
        }
    } else if (lexCh === 43) { // +
        tokType = TOK_PLUS;
        tokLiteral = "+";
    } else if (lexCh === 45) { // -
        tokType = TOK_MINUS;
        tokLiteral = "-";
    } else if (lexCh === 33) { // !
        if (lexPeekChar() === 61) {
            lexReadChar();
            tokType = TOK_NOT_EQ;
            tokLiteral = "!=";
        } else {
            tokType = TOK_BANG;
            tokLiteral = "!";
        }
    } else if (lexCh === 47) { // /
        tokType = TOK_SLASH;
        tokLiteral = "/";
    } else if (lexCh === 42) { // *
        tokType = TOK_ASTERISK;
        tokLiteral = "*";
    } else if (lexCh === 60) { // <
        tokType = TOK_LT;
        tokLiteral = "<";
    } else if (lexCh === 62) { // >
        tokType = TOK_GT;
        tokLiteral = ">";
    } else if (lexCh === 44) { // ,
        tokType = TOK_COMMA;
        tokLiteral = ",";
    } else if (lexCh === 59) { // ;
        tokType = TOK_SEMICOLON;
        tokLiteral = ";";
    } else if (lexCh === 40) { // (
        tokType = TOK_LPAREN;
        tokLiteral = "(";
    } else if (lexCh === 41) { // )
        tokType = TOK_RPAREN;
        tokLiteral = ")";
    } else if (lexCh === 123) { // {
        tokType = TOK_LBRACE;
        tokLiteral = "{";
    } else if (lexCh === 125) { // }
        tokType = TOK_RBRACE;
        tokLiteral = "}";
    } else if (lexCh === 0) {
        tokType = TOK_EOF;
        tokLiteral = "";
    } else if (isLetterChar(lexCh)) {
        tokLiteral = lexReadIdentifier();
        tokType = lookupKeyword(tokLiteral);
        return;
    } else if (isDigitChar(lexCh)) {
        tokLiteral = lexReadNumber();
        tokType = TOK_INT;
        return;
    } else {
        tokType = TOK_ILLEGAL;
        tokLiteral = String.fromCharCode(lexCh);
    }
    lexReadChar();
}

function parserInit(input) {
    lexInit(input);
    curType = TOK_EOF;
    curLiteral = "";
    peekType = TOK_EOF;
    peekLiteral = "";
    parserAdvance();
    parserAdvance();
}

function parserAdvance() {
    curType = peekType;
    curLiteral = peekLiteral;
    nextToken();
    peekType = tokType;
    peekLiteral = tokLiteral;
}

function expectPeek(t) {
    if (peekType === t) {
        parserAdvance();
        return true;
    }
    return false;
}

function peekPrecedence() {
    switch (peekType) {
        case TOK_EQ: case TOK_NOT_EQ: return PREC_EQUALS;
        case TOK_LT: case TOK_GT: return PREC_LESSGREATER;
        case TOK_PLUS: case TOK_MINUS: return PREC_SUM;
        case TOK_SLASH: case TOK_ASTERISK: return PREC_PRODUCT;
        case TOK_LPAREN: return PREC_CALL;
        default: return PREC_LOWEST;
    }
}

function curPrecedence() {
    switch (curType) {
        case TOK_EQ: case TOK_NOT_EQ: return PREC_EQUALS;
        case TOK_LT: case TOK_GT: return PREC_LESSGREATER;
        case TOK_PLUS: case TOK_MINUS: return PREC_SUM;
        case TOK_SLASH: case TOK_ASTERISK: return PREC_PRODUCT;
        case TOK_LPAREN: return PREC_CALL;
        default: return PREC_LOWEST;
    }
}

function hasInfix(t) {
    return t === TOK_PLUS || t === TOK_MINUS || t === TOK_SLASH ||
        t === TOK_ASTERISK || t === TOK_EQ || t === TOK_NOT_EQ ||
        t === TOK_LT || t === TOK_GT || t === TOK_LPAREN;
}

function parseExpression(precedence) {
    let left;
    if (curType === TOK_IDENT) {
        left = curLiteral;
    } else if (curType === TOK_INT) {
        left = curLiteral;
    } else if (curType === TOK_TRUE) {
        left = "true";
    } else if (curType === TOK_FALSE) {
        left = "false";
    } else if (curType === TOK_BANG || curType === TOK_MINUS) {
        const op = curLiteral;
        parserAdvance();
        const right = parseExpression(PREC_PREFIX);
        left = "(" + op + right + ")";
    } else if (curType === TOK_LPAREN) {
        parserAdvance();
        left = parseExpression(PREC_LOWEST);
        if (peekType === TOK_RPAREN) {
            parserAdvance();
        }
    } else if (curType === TOK_IF) {
        left = parseIfExpression();
    } else if (curType === TOK_FUNCTION) {
        left = parseFunctionLiteral();
    } else {
        left = "?";
    }
    while (peekType !== TOK_SEMICOLON && precedence < peekPrecedence()) {
        if (!hasInfix(peekType)) {
            return left;
        }
        parserAdvance();
        if (curType === TOK_LPAREN) {
            left = parseCallExpression(left);
        } else {
            const op = curLiteral;
            const prec = curPrecedence();
            parserAdvance();
            const right = parseExpression(prec);
            left = "(" + left + " " + op + " " + right + ")";
        }
    }
    return left;
}

function parseIfExpression() {
    let result = "if";
    if (!expectPeek(TOK_LPAREN)) return result;
    parserAdvance();
    const condition = parseExpression(PREC_LOWEST);
    result = result + condition;
    if (!expectPeek(TOK_RPAREN)) return result;
    if (!expectPeek(TOK_LBRACE)) return result;
    const consequence = parseBlockStatement();
    result = result + consequence;
    if (peekType === TOK_ELSE) {
        parserAdvance();
        if (!expectPeek(TOK_LBRACE)) return result;
        const alternative = parseBlockStatement();
        result = result + "else" + alternative;
    }
    return result;
}

function parseFunctionLiteral() {
    let result = "fn";
    if (!expectPeek(TOK_LPAREN)) return result;
    const params = parseFunctionParameters();
    result = result + "(" + params + ")";
    if (!expectPeek(TOK_LBRACE)) return result;
    const body = parseBlockStatement();
    result = result + body;
    return result;
}

function parseFunctionParameters() {
    let result = "";
    if (peekType === TOK_RPAREN) {
        parserAdvance();
        return result;
    }
    parserAdvance();
    result = curLiteral;
    while (peekType === TOK_COMMA) {
        parserAdvance();
        parserAdvance();
        result = result + ", " + curLiteral;
    }
    expectPeek(TOK_RPAREN);
    return result;
}

function parseCallExpression(func) {
    const args = parseCallArguments();
    return func + "(" + args + ")";
}

function parseCallArguments() {
    let result = "";
    if (peekType === TOK_RPAREN) {
        parserAdvance();
        return result;
    }
    parserAdvance();
    result = parseExpression(PREC_LOWEST);
    while (peekType === TOK_COMMA) {
        parserAdvance();
        parserAdvance();
        result = result + ", " + parseExpression(PREC_LOWEST);
    }
    expectPeek(TOK_RPAREN);
    return result;
}

function parseBlockStatement() {
    let result = "";
    parserAdvance();
    while (curType !== TOK_RBRACE && curType !== TOK_EOF) {
        const stmt = parseStatement();
        if (stmt.length > 0) {
            result = result + stmt;
        }
        parserAdvance();
    }
    return result;
}

function parseStatement() {
    if (curType === TOK_LET) {
        return parseLetStatement();
    }
    if (curType === TOK_RETURN) {
        return parseReturnStatement();
    }
    return parseExpressionStatement();
}

function parseLetStatement() {
    if (!expectPeek(TOK_IDENT)) return "";
    const name = curLiteral;
    if (!expectPeek(TOK_ASSIGN)) return "";
    parserAdvance();
    const value = parseExpression(PREC_LOWEST);
    if (peekType === TOK_SEMICOLON) {
        parserAdvance();
    }
    return "let " + name + " = " + value + ";";
}

function parseReturnStatement() {
    parserAdvance();
    const value = parseExpression(PREC_LOWEST);
    if (peekType === TOK_SEMICOLON) {
        parserAdvance();
    }
    return "return " + value + ";";
}

function parseExpressionStatement() {
    const expr = parseExpression(PREC_LOWEST);
    if (peekType === TOK_SEMICOLON) {
        parserAdvance();
    }
    return expr;
}

function parseProgram() {
    let result = "";
    while (curType !== TOK_EOF) {
        const stmt = parseStatement();
        if (stmt.length > 0) {
            result = result + stmt;
        }
        parserAdvance();
    }
    return result;
}

function main() {
    const input = "let five = 5;\nlet ten = 10;\nlet add = fn(x, y) { x + y; };\nlet result = add(five, ten);\n!-/*5;\n5 < 10 > 5;\nif (5 < 10) { return true; } else { return false; }\n10 == 10;\n10 != 9;\n";
    const N = 100000;
    let resultLen = 0;
    for (let i = 0; i < N; i++) {
        parserInit(input);
        const result = parseProgram();
        resultLen = result.length;
    }
    console.log(resultLen);
}

main();
