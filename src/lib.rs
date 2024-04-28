use syntect::parsing::{ParseState, Scope, ScopeStack, ScopeStackOp, SyntaxSet};
use syntect::util::LinesWithEndings;

struct ParseChar {
    char: u8,
    state: Vec<Scope>,
}

struct ParseIter {
    ps: SyntaxSet,
    parse_state: ParseState,
    wants_next_line: bool,
    state: ScopeStack,

    current_line_str: Option<String>,
    current_line_idx: usize,
    next_line_option_idx: usize,
    current_line: Option<Vec<(usize, ScopeStackOp)>>,
}
impl ParseIter {
    pub fn init(language: &str) -> ParseIter {
        let ps = SyntaxSet::load_defaults_newlines();
        let syntax = ps.find_syntax_by_extension(language).unwrap();

        let parse_state = ParseState::new(syntax);

        ParseIter {
            ps,
            parse_state,
            wants_next_line: true,
            state: ScopeStack::new(),

            current_line_str: None,
            current_line_idx: 0,
            next_line_option_idx: 0,
            current_line: None,
        }
    }

    pub fn add_line(&mut self, line: &str) -> () {
        if !self.wants_next_line {panic!("not wants next line")}
        self.wants_next_line = false;
        self.current_line_str = Some(line.into());
        self.current_line = Some(self.parse_state.parse_line(line, &self.ps).unwrap());
        self.current_line_idx = 0;
        self.next_line_option_idx = 0;
    }

    pub fn next(&mut self) -> Option<ParseChar> {
        if self.wants_next_line {panic!("wants next line")}

        // positions in the line are relative to the line
        let line_str: &str = self.current_line_str.as_ref().unwrap();
        let line = self.current_line.as_ref().unwrap();

        let res_chars = line_str.as_bytes();
        if self.current_line_idx >= res_chars.len() {
            // oops! should have posted a line
            panic!("should have posted a line");
        };

        let res_byte = res_chars[self.current_line_idx];

        while self.next_line_option_idx < line.len() && line[self.next_line_option_idx].0 < self.current_line_idx {
            // can't make this a function because not allowed to have &mut self and a & reference to a thing in self
            // even though that's completely fine and ok? rust just doesn't allow it.
            // state would need to be extracted out into a seperate struct and then
            // applyOp could probably be called on that, maybe.
            let op = &line[self.next_line_option_idx].1;
            _ = self.state.apply(op);
            self.next_line_option_idx += 1;
        }
        self.current_line_idx += 1;

        if res_byte == b'\n' {
            self.wants_next_line = true;
        };

        Some(ParseChar {
            char: res_byte,
            state: self.state.scopes.clone(),
        })
    }
}

#[no_mangle]
pub extern "C" fn syntect_demo() {
    let s = "pub struct Wow { hi: u64 }\nfn blah() -> u64 {}\n";

    let mut parser = ParseIter::init("rs");

    for line in LinesWithEndings::from(s) {
        parser.add_line(line);

        loop {
            if parser.wants_next_line {break}
            match parser.next() {
                Some(val) => {
                    println!("value: '{:#?}' {:#?}", val.char as char, val.state);
                },
                _ => break,
            }
        }
    }
}

#[no_mangle]
pub extern "C" fn add(n1: i32, n2: i32) -> i32 {
    return n1 + n2;
}
