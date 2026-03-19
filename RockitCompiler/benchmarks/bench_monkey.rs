// bench_monkey.rs — Monkey Language Lexer/Parser
// Single-threaded reference implementation

const TOK_ILLEGAL: i32 = 0;
const TOK_EOF: i32 = 1;
const TOK_IDENT: i32 = 2;
const TOK_INT: i32 = 3;
const TOK_ASSIGN: i32 = 4;
const TOK_PLUS: i32 = 5;
const TOK_MINUS: i32 = 6;
const TOK_BANG: i32 = 7;
const TOK_SLASH: i32 = 8;
const TOK_ASTERISK: i32 = 9;
const TOK_LT: i32 = 10;
const TOK_GT: i32 = 11;
const TOK_EQ: i32 = 12;
const TOK_NOT_EQ: i32 = 13;
const TOK_COMMA: i32 = 14;
const TOK_SEMICOLON: i32 = 15;
const TOK_LPAREN: i32 = 16;
const TOK_RPAREN: i32 = 17;
const TOK_LBRACE: i32 = 18;
const TOK_RBRACE: i32 = 19;
const TOK_FUNCTION: i32 = 20;
const TOK_LET: i32 = 21;
const TOK_IF: i32 = 22;
const TOK_ELSE: i32 = 23;
const TOK_RETURN: i32 = 24;
const TOK_TRUE: i32 = 25;
const TOK_FALSE: i32 = 26;

const PREC_LOWEST: i32 = 1;
const PREC_EQUALS: i32 = 2;
const PREC_LESSGREATER: i32 = 3;
const PREC_SUM: i32 = 4;
const PREC_PRODUCT: i32 = 5;
const PREC_PREFIX: i32 = 6;
const PREC_CALL: i32 = 7;

struct Lexer {
    input: Vec<u8>,
    pos: usize,
    read_pos: usize,
    ch: u8,
}

impl Lexer {
    fn new(input: &str) -> Lexer {
        let mut l = Lexer {
            input: input.as_bytes().to_vec(),
            pos: 0,
            read_pos: 0,
            ch: 0,
        };
        l.read_char();
        l
    }

    fn read_char(&mut self) {
        if self.read_pos >= self.input.len() {
            self.ch = 0;
        } else {
            self.ch = self.input[self.read_pos];
        }
        self.pos = self.read_pos;
        self.read_pos += 1;
    }

    fn peek_char(&self) -> u8 {
        if self.read_pos >= self.input.len() {
            0
        } else {
            self.input[self.read_pos]
        }
    }

    fn skip_whitespace(&mut self) {
        while self.ch == b' ' || self.ch == b'\t' || self.ch == b'\n' || self.ch == b'\r' {
            self.read_char();
        }
    }

    fn read_identifier(&mut self) -> String {
        let start = self.pos;
        while is_letter(self.ch) {
            self.read_char();
        }
        String::from_utf8(self.input[start..self.pos].to_vec()).unwrap()
    }

    fn read_number(&mut self) -> String {
        let start = self.pos;
        while is_digit(self.ch) {
            self.read_char();
        }
        String::from_utf8(self.input[start..self.pos].to_vec()).unwrap()
    }

    fn next_token(&mut self) -> (i32, String) {
        self.skip_whitespace();
        let (tok_type, tok_literal);
        match self.ch {
            b'=' => {
                if self.peek_char() == b'=' {
                    self.read_char();
                    tok_type = TOK_EQ;
                    tok_literal = "==".to_string();
                } else {
                    tok_type = TOK_ASSIGN;
                    tok_literal = "=".to_string();
                }
            }
            b'+' => { tok_type = TOK_PLUS; tok_literal = "+".to_string(); }
            b'-' => { tok_type = TOK_MINUS; tok_literal = "-".to_string(); }
            b'!' => {
                if self.peek_char() == b'=' {
                    self.read_char();
                    tok_type = TOK_NOT_EQ;
                    tok_literal = "!=".to_string();
                } else {
                    tok_type = TOK_BANG;
                    tok_literal = "!".to_string();
                }
            }
            b'/' => { tok_type = TOK_SLASH; tok_literal = "/".to_string(); }
            b'*' => { tok_type = TOK_ASTERISK; tok_literal = "*".to_string(); }
            b'<' => { tok_type = TOK_LT; tok_literal = "<".to_string(); }
            b'>' => { tok_type = TOK_GT; tok_literal = ">".to_string(); }
            b',' => { tok_type = TOK_COMMA; tok_literal = ",".to_string(); }
            b';' => { tok_type = TOK_SEMICOLON; tok_literal = ";".to_string(); }
            b'(' => { tok_type = TOK_LPAREN; tok_literal = "(".to_string(); }
            b')' => { tok_type = TOK_RPAREN; tok_literal = ")".to_string(); }
            b'{' => { tok_type = TOK_LBRACE; tok_literal = "{".to_string(); }
            b'}' => { tok_type = TOK_RBRACE; tok_literal = "}".to_string(); }
            0 => { tok_type = TOK_EOF; tok_literal = String::new(); }
            _ => {
                if is_letter(self.ch) {
                    let ident = self.read_identifier();
                    let tt = lookup_keyword(&ident);
                    return (tt, ident);
                } else if is_digit(self.ch) {
                    let num = self.read_number();
                    return (TOK_INT, num);
                } else {
                    tok_type = TOK_ILLEGAL;
                    tok_literal = (self.ch as char).to_string();
                }
            }
        }
        self.read_char();
        (tok_type, tok_literal)
    }
}

fn is_letter(ch: u8) -> bool {
    (ch >= b'A' && ch <= b'Z') || (ch >= b'a' && ch <= b'z') || ch == b'_'
}

fn is_digit(ch: u8) -> bool {
    ch >= b'0' && ch <= b'9'
}

fn lookup_keyword(ident: &str) -> i32 {
    match ident {
        "fn" => TOK_FUNCTION,
        "let" => TOK_LET,
        "if" => TOK_IF,
        "else" => TOK_ELSE,
        "return" => TOK_RETURN,
        "true" => TOK_TRUE,
        "false" => TOK_FALSE,
        _ => TOK_IDENT,
    }
}

struct Parser {
    lex: Lexer,
    cur_type: i32,
    cur_literal: String,
    peek_type: i32,
    peek_literal: String,
}

impl Parser {
    fn new(input: &str) -> Parser {
        let lex = Lexer::new(input);
        let mut p = Parser {
            lex,
            cur_type: TOK_EOF,
            cur_literal: String::new(),
            peek_type: TOK_EOF,
            peek_literal: String::new(),
        };
        p.advance();
        p.advance();
        p
    }

    fn advance(&mut self) {
        self.cur_type = self.peek_type;
        self.cur_literal = self.peek_literal.clone();
        let (tt, tl) = self.lex.next_token();
        self.peek_type = tt;
        self.peek_literal = tl;
    }

    fn expect_peek(&mut self, t: i32) -> bool {
        if self.peek_type == t {
            self.advance();
            true
        } else {
            false
        }
    }

    fn peek_precedence(&self) -> i32 {
        match self.peek_type {
            TOK_EQ | TOK_NOT_EQ => PREC_EQUALS,
            TOK_LT | TOK_GT => PREC_LESSGREATER,
            TOK_PLUS | TOK_MINUS => PREC_SUM,
            TOK_SLASH | TOK_ASTERISK => PREC_PRODUCT,
            TOK_LPAREN => PREC_CALL,
            _ => PREC_LOWEST,
        }
    }

    fn cur_precedence(&self) -> i32 {
        match self.cur_type {
            TOK_EQ | TOK_NOT_EQ => PREC_EQUALS,
            TOK_LT | TOK_GT => PREC_LESSGREATER,
            TOK_PLUS | TOK_MINUS => PREC_SUM,
            TOK_SLASH | TOK_ASTERISK => PREC_PRODUCT,
            TOK_LPAREN => PREC_CALL,
            _ => PREC_LOWEST,
        }
    }

    fn has_infix(t: i32) -> bool {
        t == TOK_PLUS || t == TOK_MINUS || t == TOK_SLASH ||
            t == TOK_ASTERISK || t == TOK_EQ || t == TOK_NOT_EQ ||
            t == TOK_LT || t == TOK_GT || t == TOK_LPAREN
    }

    fn parse_expression(&mut self, precedence: i32) -> String {
        let mut left;
        if self.cur_type == TOK_IDENT {
            left = self.cur_literal.clone();
        } else if self.cur_type == TOK_INT {
            left = self.cur_literal.clone();
        } else if self.cur_type == TOK_TRUE {
            left = "true".to_string();
        } else if self.cur_type == TOK_FALSE {
            left = "false".to_string();
        } else if self.cur_type == TOK_BANG || self.cur_type == TOK_MINUS {
            let op = self.cur_literal.clone();
            self.advance();
            let right = self.parse_expression(PREC_PREFIX);
            left = format!("({}{})", op, right);
        } else if self.cur_type == TOK_LPAREN {
            self.advance();
            left = self.parse_expression(PREC_LOWEST);
            if self.peek_type == TOK_RPAREN {
                self.advance();
            }
        } else if self.cur_type == TOK_IF {
            left = self.parse_if_expression();
        } else if self.cur_type == TOK_FUNCTION {
            left = self.parse_function_literal();
        } else {
            left = "?".to_string();
        }

        while self.peek_type != TOK_SEMICOLON && precedence < self.peek_precedence() {
            if !Self::has_infix(self.peek_type) {
                return left;
            }
            self.advance();
            if self.cur_type == TOK_LPAREN {
                left = self.parse_call_expression(left);
            } else {
                let op = self.cur_literal.clone();
                let prec = self.cur_precedence();
                self.advance();
                let right = self.parse_expression(prec);
                left = format!("({} {} {})", left, op, right);
            }
        }
        left
    }

    fn parse_if_expression(&mut self) -> String {
        let mut result = "if".to_string();
        if !self.expect_peek(TOK_LPAREN) { return result; }
        self.advance();
        let condition = self.parse_expression(PREC_LOWEST);
        result = result + &condition;
        if !self.expect_peek(TOK_RPAREN) { return result; }
        if !self.expect_peek(TOK_LBRACE) { return result; }
        let consequence = self.parse_block_statement();
        result = result + &consequence;
        if self.peek_type == TOK_ELSE {
            self.advance();
            if !self.expect_peek(TOK_LBRACE) { return result; }
            let alternative = self.parse_block_statement();
            result = result + "else" + &alternative;
        }
        result
    }

    fn parse_function_literal(&mut self) -> String {
        let mut result = "fn".to_string();
        if !self.expect_peek(TOK_LPAREN) { return result; }
        let params = self.parse_function_parameters();
        result = result + "(" + &params + ")";
        if !self.expect_peek(TOK_LBRACE) { return result; }
        let body = self.parse_block_statement();
        result = result + &body;
        result
    }

    fn parse_function_parameters(&mut self) -> String {
        let mut result = String::new();
        if self.peek_type == TOK_RPAREN {
            self.advance();
            return result;
        }
        self.advance();
        result = self.cur_literal.clone();
        while self.peek_type == TOK_COMMA {
            self.advance();
            self.advance();
            result = result + ", " + &self.cur_literal;
        }
        self.expect_peek(TOK_RPAREN);
        result
    }

    fn parse_call_expression(&mut self, function: String) -> String {
        let args = self.parse_call_arguments();
        function + "(" + &args + ")"
    }

    fn parse_call_arguments(&mut self) -> String {
        let mut result = String::new();
        if self.peek_type == TOK_RPAREN {
            self.advance();
            return result;
        }
        self.advance();
        result = self.parse_expression(PREC_LOWEST);
        while self.peek_type == TOK_COMMA {
            self.advance();
            self.advance();
            let expr = self.parse_expression(PREC_LOWEST);
            result = result + ", " + &expr;
        }
        self.expect_peek(TOK_RPAREN);
        result
    }

    fn parse_block_statement(&mut self) -> String {
        let mut result = String::new();
        self.advance();
        while self.cur_type != TOK_RBRACE && self.cur_type != TOK_EOF {
            let stmt = self.parse_statement();
            if !stmt.is_empty() {
                result = result + &stmt;
            }
            self.advance();
        }
        result
    }

    fn parse_statement(&mut self) -> String {
        if self.cur_type == TOK_LET {
            return self.parse_let_statement();
        }
        if self.cur_type == TOK_RETURN {
            return self.parse_return_statement();
        }
        self.parse_expression_statement()
    }

    fn parse_let_statement(&mut self) -> String {
        if !self.expect_peek(TOK_IDENT) { return String::new(); }
        let name = self.cur_literal.clone();
        if !self.expect_peek(TOK_ASSIGN) { return String::new(); }
        self.advance();
        let value = self.parse_expression(PREC_LOWEST);
        if self.peek_type == TOK_SEMICOLON {
            self.advance();
        }
        format!("let {} = {};", name, value)
    }

    fn parse_return_statement(&mut self) -> String {
        self.advance();
        let value = self.parse_expression(PREC_LOWEST);
        if self.peek_type == TOK_SEMICOLON {
            self.advance();
        }
        format!("return {};", value)
    }

    fn parse_expression_statement(&mut self) -> String {
        let expr = self.parse_expression(PREC_LOWEST);
        if self.peek_type == TOK_SEMICOLON {
            self.advance();
        }
        expr
    }

    fn parse_program(&mut self) -> String {
        let mut result = String::new();
        while self.cur_type != TOK_EOF {
            let stmt = self.parse_statement();
            if !stmt.is_empty() {
                result = result + &stmt;
            }
            self.advance();
        }
        result
    }
}

fn main() {
    let input = "let five = 5;\nlet ten = 10;\nlet add = fn(x, y) { x + y; };\nlet result = add(five, ten);\n!-/*5;\n5 < 10 > 5;\nif (5 < 10) { return true; } else { return false; }\n10 == 10;\n10 != 9;\n";
    let n = 100000;
    let mut result_len = 0;
    for _ in 0..n {
        let mut parser = Parser::new(input);
        let result = parser.parse_program();
        result_len = result.len();
    }
    println!("{}", result_len);
}
