EDI parser and library using Zig lang.

## Usage
### Lexer 
```
test "lexer.segment" {
    const s = "DXS*9251230013*DX*004010UCS*1*9254850000";
    const options = LexerOptions.init('*', '~');
    var lexer = Lexer.init(s, options);
    lexer.tokens();

    try expect(11 == lexer.size() - 1);
    try expect(std.mem.eql(u8, s, lexer.value()) == true);
}
```

### Parser
```
test "parser.string" {
    const s = "ISA*01*0000000000*01*0000000000*ZZ*ABCDEFGHIJKLMNO~ZZ*123456789012345*101127*1719*U*00400*000000049*0*P*>~IEA*2*000000049";
    const p = Parser.init(s, '*', '~');
    const r = p.parse();
    _ = r;
}
```

## Supported Transaction Sets

|X12 Transaction Set| Description| X12 Version(s)|Status|
|-------------------|------------|---------------|------|
|270 |Eligibility, Coverage or Benefit Inquiry| X12 8040|In development|

