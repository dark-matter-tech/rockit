#include <cstdio>
#include <string>

// Token types
const int TOK_ILLEGAL    = 0;
const int TOK_EOF        = 1;
const int TOK_IDENT      = 2;
const int TOK_INT        = 3;
const int TOK_ASSIGN     = 4;
const int TOK_PLUS       = 5;
const int TOK_MINUS      = 6;
const int TOK_BANG       = 7;
const int TOK_SLASH      = 8;
const int TOK_ASTERISK   = 9;
const int TOK_LT         = 10;
const int TOK_GT         = 11;
const int TOK_EQ         = 12;
const int TOK_NOT_EQ     = 13;
const int TOK_COMMA      = 14;
const int TOK_SEMICOLON  = 15;
const int TOK_LPAREN     = 16;
const int TOK_RPAREN     = 17;
const int TOK_LBRACE     = 18;
const int TOK_RBRACE     = 19;
const int TOK_FUNCTION   = 20;
const int TOK_LET        = 21;
const int TOK_IF         = 22;
const int TOK_ELSE       = 23;
const int TOK_RETURN     = 24;
const int TOK_TRUE       = 25;
const int TOK_FALSE      = 26;

// Precedences
const int PREC_LOWEST      = 1;
const int PREC_EQUALS      = 2;
const int PREC_LESSGREATER = 3;
const int PREC_SUM         = 4;
const int PREC_PRODUCT     = 5;
const int PREC_PREFIX      = 6;
const int PREC_CALL        = 7;

// Global lexer state
std::string lexInput;
int lexPos;
int lexReadPos;
int lexCh;

// Global token state
int tokType;
std::string tokLiteral;

// Global parser state
int curType;
std::string curLiteral;
int peekType;
std::string peekLiteral;

// Forward declarations
std::string parseExpression(int precedence);
std::string parseIfExpression();
std::string parseFunctionLiteral();
std::string parseFunctionParameters();
std::string parseCallExpression(const std::string& function);
std::string parseCallArguments();
std::string parseBlockStatement();
std::string parseStatement();
std::string parseLetStatement();
std::string parseReturnStatement();
std::string parseExpressionStatement();
std::string parseProgram();

void lexReadChar() {
    if (lexReadPos >= (int)lexInput.length()) {
        lexCh = 0;
    } else {
        lexCh = (unsigned char)lexInput[lexReadPos];
    }
    lexPos = lexReadPos;
    lexReadPos++;
}

int lexPeekChar() {
    if (lexReadPos >= (int)lexInput.length()) {
        return 0;
    }
    return (unsigned char)lexInput[lexReadPos];
}

void lexInit(const std::string& input) {
    lexInput = input;
    lexPos = 0;
    lexReadPos = 0;
    lexCh = 0;
    lexReadChar();
}

void lexSkipWhitespace() {
    while (lexCh == ' ' || lexCh == '\t' || lexCh == '\n' || lexCh == '\r') {
        lexReadChar();
    }
}

bool isLetterChar(int ch) {
    return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch == '_';
}

bool isDigitChar(int ch) {
    return ch >= '0' && ch <= '9';
}

std::string lexReadIdentifier() {
    int start = lexPos;
    while (isLetterChar(lexCh)) {
        lexReadChar();
    }
    return lexInput.substr(start, lexPos - start);
}

std::string lexReadNumber() {
    int start = lexPos;
    while (isDigitChar(lexCh)) {
        lexReadChar();
    }
    return lexInput.substr(start, lexPos - start);
}

int lookupKeyword(const std::string& ident) {
    if (ident == "fn") return TOK_FUNCTION;
    if (ident == "let") return TOK_LET;
    if (ident == "if") return TOK_IF;
    if (ident == "else") return TOK_ELSE;
    if (ident == "return") return TOK_RETURN;
    if (ident == "true") return TOK_TRUE;
    if (ident == "false") return TOK_FALSE;
    return TOK_IDENT;
}

void nextToken() {
    lexSkipWhitespace();
    if (lexCh == '=') {
        if (lexPeekChar() == '=') {
            lexReadChar();
            tokType = TOK_EQ;
            tokLiteral = "==";
        } else {
            tokType = TOK_ASSIGN;
            tokLiteral = "=";
        }
    } else if (lexCh == '+') {
        tokType = TOK_PLUS;
        tokLiteral = "+";
    } else if (lexCh == '-') {
        tokType = TOK_MINUS;
        tokLiteral = "-";
    } else if (lexCh == '!') {
        if (lexPeekChar() == '=') {
            lexReadChar();
            tokType = TOK_NOT_EQ;
            tokLiteral = "!=";
        } else {
            tokType = TOK_BANG;
            tokLiteral = "!";
        }
    } else if (lexCh == '/') {
        tokType = TOK_SLASH;
        tokLiteral = "/";
    } else if (lexCh == '*') {
        tokType = TOK_ASTERISK;
        tokLiteral = "*";
    } else if (lexCh == '<') {
        tokType = TOK_LT;
        tokLiteral = "<";
    } else if (lexCh == '>') {
        tokType = TOK_GT;
        tokLiteral = ">";
    } else if (lexCh == ',') {
        tokType = TOK_COMMA;
        tokLiteral = ",";
    } else if (lexCh == ';') {
        tokType = TOK_SEMICOLON;
        tokLiteral = ";";
    } else if (lexCh == '(') {
        tokType = TOK_LPAREN;
        tokLiteral = "(";
    } else if (lexCh == ')') {
        tokType = TOK_RPAREN;
        tokLiteral = ")";
    } else if (lexCh == '{') {
        tokType = TOK_LBRACE;
        tokLiteral = "{";
    } else if (lexCh == '}') {
        tokType = TOK_RBRACE;
        tokLiteral = "}";
    } else if (lexCh == 0) {
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
        tokLiteral = std::string(1, (char)lexCh);
    }
    lexReadChar();
}

void parserAdvance() {
    curType = peekType;
    curLiteral = peekLiteral;
    nextToken();
    peekType = tokType;
    peekLiteral = tokLiteral;
}

void parserInit(const std::string& input) {
    lexInit(input);
    curType = TOK_EOF;
    curLiteral = "";
    peekType = TOK_EOF;
    peekLiteral = "";
    parserAdvance();
    parserAdvance();
}

bool expectPeek(int t) {
    if (peekType == t) {
        parserAdvance();
        return true;
    }
    return false;
}

int peekPrecedence() {
    switch (peekType) {
        case TOK_EQ: case TOK_NOT_EQ: return PREC_EQUALS;
        case TOK_LT: case TOK_GT: return PREC_LESSGREATER;
        case TOK_PLUS: case TOK_MINUS: return PREC_SUM;
        case TOK_SLASH: case TOK_ASTERISK: return PREC_PRODUCT;
        case TOK_LPAREN: return PREC_CALL;
    }
    return PREC_LOWEST;
}

int curPrecedence() {
    switch (curType) {
        case TOK_EQ: case TOK_NOT_EQ: return PREC_EQUALS;
        case TOK_LT: case TOK_GT: return PREC_LESSGREATER;
        case TOK_PLUS: case TOK_MINUS: return PREC_SUM;
        case TOK_SLASH: case TOK_ASTERISK: return PREC_PRODUCT;
        case TOK_LPAREN: return PREC_CALL;
    }
    return PREC_LOWEST;
}

bool hasInfix(int t) {
    return t == TOK_PLUS || t == TOK_MINUS || t == TOK_SLASH ||
           t == TOK_ASTERISK || t == TOK_EQ || t == TOK_NOT_EQ ||
           t == TOK_LT || t == TOK_GT || t == TOK_LPAREN;
}

std::string parseExpression(int precedence) {
    std::string left;
    if (curType == TOK_IDENT) {
        left = curLiteral;
    } else if (curType == TOK_INT) {
        left = curLiteral;
    } else if (curType == TOK_TRUE) {
        left = "true";
    } else if (curType == TOK_FALSE) {
        left = "false";
    } else if (curType == TOK_BANG || curType == TOK_MINUS) {
        std::string op = curLiteral;
        parserAdvance();
        std::string right = parseExpression(PREC_PREFIX);
        left = "(" + op + right + ")";
    } else if (curType == TOK_LPAREN) {
        parserAdvance();
        left = parseExpression(PREC_LOWEST);
        if (peekType == TOK_RPAREN) {
            parserAdvance();
        }
    } else if (curType == TOK_IF) {
        left = parseIfExpression();
    } else if (curType == TOK_FUNCTION) {
        left = parseFunctionLiteral();
    } else {
        left = "?";
    }

    while (peekType != TOK_SEMICOLON && precedence < peekPrecedence()) {
        if (!hasInfix(peekType)) {
            return left;
        }
        parserAdvance();
        if (curType == TOK_LPAREN) {
            left = parseCallExpression(left);
        } else {
            std::string op = curLiteral;
            int prec = curPrecedence();
            parserAdvance();
            std::string right = parseExpression(prec);
            left = "(" + left + " " + op + " " + right + ")";
        }
    }
    return left;
}

std::string parseIfExpression() {
    std::string result = "if";
    if (!expectPeek(TOK_LPAREN)) return result;
    parserAdvance();
    std::string condition = parseExpression(PREC_LOWEST);
    result = result + condition;
    if (!expectPeek(TOK_RPAREN)) return result;
    if (!expectPeek(TOK_LBRACE)) return result;
    std::string consequence = parseBlockStatement();
    result = result + consequence;
    if (peekType == TOK_ELSE) {
        parserAdvance();
        if (!expectPeek(TOK_LBRACE)) return result;
        std::string alternative = parseBlockStatement();
        result = result + "else" + alternative;
    }
    return result;
}

std::string parseFunctionLiteral() {
    std::string result = "fn";
    if (!expectPeek(TOK_LPAREN)) return result;
    std::string params = parseFunctionParameters();
    result = result + "(" + params + ")";
    if (!expectPeek(TOK_LBRACE)) return result;
    std::string body = parseBlockStatement();
    result = result + body;
    return result;
}

std::string parseFunctionParameters() {
    std::string result = "";
    if (peekType == TOK_RPAREN) {
        parserAdvance();
        return result;
    }
    parserAdvance();
    result = curLiteral;
    while (peekType == TOK_COMMA) {
        parserAdvance();
        parserAdvance();
        result = result + ", " + curLiteral;
    }
    expectPeek(TOK_RPAREN);
    return result;
}

std::string parseCallExpression(const std::string& function) {
    std::string args = parseCallArguments();
    return function + "(" + args + ")";
}

std::string parseCallArguments() {
    std::string result = "";
    if (peekType == TOK_RPAREN) {
        parserAdvance();
        return result;
    }
    parserAdvance();
    result = parseExpression(PREC_LOWEST);
    while (peekType == TOK_COMMA) {
        parserAdvance();
        parserAdvance();
        result = result + ", " + parseExpression(PREC_LOWEST);
    }
    expectPeek(TOK_RPAREN);
    return result;
}

std::string parseBlockStatement() {
    std::string result = "";
    parserAdvance();
    while (curType != TOK_RBRACE && curType != TOK_EOF) {
        std::string stmt = parseStatement();
        if (stmt.length() > 0) {
            result = result + stmt;
        }
        parserAdvance();
    }
    return result;
}

std::string parseStatement() {
    if (curType == TOK_LET) {
        return parseLetStatement();
    }
    if (curType == TOK_RETURN) {
        return parseReturnStatement();
    }
    return parseExpressionStatement();
}

std::string parseLetStatement() {
    if (!expectPeek(TOK_IDENT)) return "";
    std::string name = curLiteral;
    if (!expectPeek(TOK_ASSIGN)) return "";
    parserAdvance();
    std::string value = parseExpression(PREC_LOWEST);
    if (peekType == TOK_SEMICOLON) {
        parserAdvance();
    }
    return "let " + name + " = " + value + ";";
}

std::string parseReturnStatement() {
    parserAdvance();
    std::string value = parseExpression(PREC_LOWEST);
    if (peekType == TOK_SEMICOLON) {
        parserAdvance();
    }
    return "return " + value + ";";
}

std::string parseExpressionStatement() {
    std::string expr = parseExpression(PREC_LOWEST);
    if (peekType == TOK_SEMICOLON) {
        parserAdvance();
    }
    return expr;
}

std::string parseProgram() {
    std::string result = "";
    while (curType != TOK_EOF) {
        std::string stmt = parseStatement();
        if (stmt.length() > 0) {
            result = result + stmt;
        }
        parserAdvance();
    }
    return result;
}

int main() {
    std::string input = "let five = 5;\nlet ten = 10;\nlet add = fn(x, y) { x + y; };\nlet result = add(five, ten);\n!-/*5;\n5 < 10 > 5;\nif (5 < 10) { return true; } else { return false; }\n10 == 10;\n10 != 9;\n";
    int N = 100000;
    int resultLen = 0;
    for (int i = 0; i < N; i++) {
        parserInit(input);
        std::string result = parseProgram();
        resultLen = (int)result.length();
    }
    printf("%d\n", resultLen);
    return 0;
}
