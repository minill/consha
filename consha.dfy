datatype Option<T> = None | Some(val: T)

datatype Type = NumT
              | BoolT
              | RefT(t: Type)
              | ShareT(st: Type)
datatype Loc  = Loc(l: int, t: Type)
datatype Value= Num(nval: int)
              | Bool(bval: bool)
              | Ref(l: Loc)
              | SRef(sl: Loc)
datatype Expr = V(val: Value)
              | Var(name: string)
              | Deref(re: Expr)
              | Alloc(ie: Expr)
              | Share(se: Expr)
              | Copy(ce: Expr)
              | Add(leftA: Expr, rightA: Expr)
              | Eq(leftE: Expr, rightE: Expr)
              | GT(leftG: Expr, rightG: Expr)
              | Receive(ch: Expr, t: Type)
datatype Stmt = VarDecl(x: string, vtype: Type, vinit: Expr)
              | Assign(y: string, expr: Expr)
              | RefAssign(z: string, rexpr: Expr)
              | Send(ch: Expr, send: Expr)
              | If(cond: Expr, the: Stmt, els: Stmt)
              | CleanUp(g: Gamma, refs: Stmt, decls: Stmt)
              | While(wcond: Expr, wbody: Stmt)
              | Seq(s1: Stmt, s2: Stmt)
              | Fork(fork: Stmt)
              | Skip

// --------- Parsing ---------

function LocsE(expr: Expr): set<Loc>
decreases expr;
{
  match expr {
    case V(val) => match val {
      case Num(n) => {}
      case Bool(b) => {}
      case Ref(l) => {l}
      case SRef(l) => {l}
    }
    case Var(x) => {}
    case Deref(re) => LocsE(re)
    case Alloc(ie) => LocsE(ie)
    case Share(se) => LocsE(se)
    case Copy(ce) => LocsE(ce)
    case Add(l, r) => LocsE(l) + LocsE(r)
    case Eq(l, r) =>  LocsE(l) + LocsE(r)
    case GT(l, r) =>  LocsE(l) + LocsE(r)
    case Receive(ch, t) => LocsE(ch)
  }
}

function LocsS(stmt: Stmt): set<Loc>
decreases stmt;
{
  match stmt {
    case VarDecl(x, vtype, vinit) => LocsE(vinit)
    case Assign(y, expr) => LocsE(expr)
    case RefAssign(z, expr) => LocsE(expr)
    case Send(ch, send) => LocsE(ch) + LocsE(send)
    case If(con, the, els) => LocsE(con) + LocsS(the) + LocsS(els)
    case CleanUp(g, refs, decls) => {}
    case While(con, body) => LocsE(con) + LocsS(body)
    case Seq(s1, s2) => LocsS(s1) + LocsS(s2)
    case Fork(s) => LocsS(s)
    case Skip => {}
  }
}

function method SatP(f: char -> bool, s: string): Option<(char, string)>
reads f.reads;
requires forall c :: f.requires(c);
ensures SatP(f, s).Some? ==> |SatP(f, s).val.1| < |s|;
{
  if |s| > 0 && f(s[0]) then
    Some((s[0], s[1..]))
  else
    None
}

function method Ch(c: char, s: string): Option<(char, string)>
ensures Ch(c, s).Some? ==> |Ch(c, s).val.1| < |s|;
{
  SatP(c1 => c == c1, s)
}

function method KW(kw: string, s: string): Option<(string,string)>
ensures KW(kw, s).Some? && |kw| >= 1 ==> |KW(kw, s).val.1| < |s|;
{
  if |kw| == 0 then (
    Some(("", s))
  ) else (
    var t := Ch(kw[0], s);
    if t.None? then None else (
      var r := KW(kw[1..], t.val.1);
      if r.None? then None else Some(([kw[0]] + r.val.0, r.val.1))
    )
  )
}

function method Map<A,B>(i: Option<(A, string)>, f: A -> B):  Option<(B, string)>
reads f.reads;
requires forall a :: f.requires(a);
ensures Map(i, f).Some? <==> i.Some?;
ensures Map(i, f).Some? ==> |Map(i, f).val.1| == |i.val.1|;
{
  if i.Some? then Some((f(i.val.0), i.val.1)) else None
}

function method Or<A>(a: Option<(A, string)>, b: Option<(A, string)>):  Option<(A, string)>
ensures Or(a, b).Some? ==> a.Some? || b.Some?;
ensures Or(a, b).Some? && a.Some? ==> Or(a, b) == a;
ensures Or(a, b).Some? && !a.Some? ==> Or(a, b) == b;
{
  if a.Some? then a else b
}

function method ParseNumT(s: string): Option<(Type, string)>
ensures ParseNumT(s).Some? ==> |ParseNumT(s).val.1| < |s|;
{
  Map(KW("Num", s), (_) => NumT)
}

function method ParseBoolT(s: string): Option<(Type, string)>
ensures ParseBoolT(s).Some? ==> |ParseBoolT(s).val.1| < |s|;
{
  Map(KW("Bool", s), (_) => BoolT)
}

function method ParseType(s: string): Option<(Type, string)>
decreases |s|;
ensures ParseType(s).Some? ==> |ParseType(s).val.1| < |s|;
{
  var f := SkipWS(Or(KW("Ref", s), KW("Share", s)));
  if f.None? then Or(ParseBoolT(s), ParseNumT(s)) else (
    var l := SkipWS(Ch('[', f.val.1));
    if l.None? then None else (
      assert |l.val.1| < |s|;
      var t := ParseType(l.val.1);
      if t.None? then None else (
        var r := SkipWS(Ch(']', t.val.1));
        if r.None? then None else (
          if f.val.0 == "Ref" then (
            Some((RefT(t.val.0), r.val.1))
          ) else (
            Some((ShareT(t.val.0), r.val.1))
          )
        )
      )
    )
  )
}

function method ParseTrue(s: string): Option<(Value, string)>
ensures ParseTrue(s).Some? ==> |ParseTrue(s).val.1| < |s|;
{
  Map(KW("true", s), (_) => Bool(true))
}

function method ParseFalse(s: string): Option<(Value, string)>
ensures ParseFalse(s).Some? ==> |ParseFalse(s).val.1| < |s|;
{
  Map(KW("false", s), (_) => Bool(false))
}

function method ParseDigit(s: string): Option<(int, string)>
ensures ParseDigit(s).Some? ==> |ParseDigit(s).val.1| < |s|;
{
  Or(Or(Or(Or(Or(Or(Or(Or(Or(Map(Ch('0', s), c => 0),
                             Map(Ch('1', s), c => 1)),
                          Map(Ch('2', s), c => 2)),
                       Map(Ch('3', s), c => 3)),
                    Map(Ch('4', s), c => 4)),
                 Map(Ch('5', s), c => 5)),
              Map(Ch('6', s), c => 6)),
           Map(Ch('7', s), c => 7)),
        Map(Ch('8', s), c => 8)),
     Map(Ch('9', s), c => 9))
}

function method ParseNumRec(s: string, i: nat, n: int): (int, string)
decreases n;
requires n >= 0;
ensures |ParseNumRec(s, i, n).1| <= |s|;
{
  if n == 0 then (
    (i, s)
  ) else (
    var t := ParseDigit(s);
    if t.None? then (i, s) else ParseNumRec(t.val.1, i * 10 + t.val.0, n - 1)
  )
}

function method ParseNum(s: string): Option<(Value, string)>
ensures ParseNum(s).Some? ==> |ParseNum(s).val.1| < |s|;
{
  var t := ParseDigit(s);
  if t.None? then None else Map(Some(ParseNumRec(t.val.1, t.val.0, 10)), n => Num(n))
}

function method ParseVal(s: string): Option<(Expr, string)>
ensures ParseVal(s).Some? ==> |ParseVal(s).val.1| < |s|;
ensures ParseVal(s).Some? ==> LocsE(ParseVal(s).val.0) == {};
{
  Map(Or(Or(ParseTrue(s),
            ParseFalse(s)),
         ParseNum(s)), v => V(v))
}

function method ParseIdRec(s: string, n: nat): (string, string)
decreases n;
ensures |ParseIdRec(s, n).1| <= |s|;
{
  if n == 0 then (
    ("", s)
  ) else (
    var t := SatP(c => 'A' <= c <= 'Z' || 'a' <= c <= 'z' || c == '_' || '0' <= c <= '9', s);
    if t.None? then
      ("", s)
    else (
      var r := ParseIdRec(t.val.1, n - 1);
      ([t.val.0] + r.0, r.1)
    )
  )
}

function method ParseId(s: string): Option<(string, string)>
ensures ParseId(s).Some? ==> |ParseId(s).val.1| < |s|;
{
  var t := SatP(c => 'A' <= c <= 'Z' || 'a' <= c <= 'z' || c == '_', s);
  if t.None? then None else (
    var r := ParseIdRec(t.val.1, 10);
    Some(([t.val.0] + r.0, r.1))
  )
}

function method ParseVar(s: string): Option<(Expr, string)>
ensures ParseVar(s).Some? ==> |ParseVar(s).val.1| < |s|;
ensures ParseVar(s).Some? ==> LocsE(ParseVar(s).val.0) == {};
{
  Map(ParseId(s), s => Var(s))
}

function method SkipComment(s: string): string
decreases s;
ensures |SkipComment(s)| <= |s|;
{
  if |s| == 0 then
    ""
  else if s[0] == '\n' then
    s[1..]
  else
    SkipComment(s[1..])
}

function method SkipS(s: string): string
decreases |s|;
ensures |SkipS(s)| <= |s|;
{
  if |s| > 3 && s[0] == '/' && s[1] == '/' then
    SkipS(SkipComment(s[2..]))
  else if |s| > 0 && (s[0] == ' ' || s[0] == '\n' || s[0] == '\t') then
    SkipS(s[1..])
  else
    s
}

function method SkipWS<A>(s: Option<(A,string)>): Option<(A,string)>
ensures s.Some? <==> SkipWS(s).Some?;
ensures SkipWS(s).Some? ==> |SkipWS(s).val.1| <= |s.val.1| &&
                            SkipWS(s).val.0 == s.val.0;
{
  if s.None? then None else Some((s.val.0, SkipS(s.val.1)))
}

function method ParseDeref(s: string, n: nat): Option<(Expr, string)>
decreases |s|, n;
requires n >= 1;
ensures ParseDeref(s, n).Some? ==> |ParseDeref(s, n).val.1| < |s|;
ensures ParseDeref(s, n).Some? ==> LocsE(ParseDeref(s, n).val.0) == {};
{
  var t := SkipWS(Ch('*', s));
  if t.None? then None else (
    var l := SkipWS(Ch('(', t.val.1));
    if l.None? then None else (
      assert |l.val.1| < |s|;
      var e := ParseExprRec(l.val.1, n - 1);
      if e.None? then None else (
        var r := SkipWS(Ch(')', e.val.1));
        if r.None? then None else (
          Some((Deref(e.val.0), r.val.1))
        )
      )
    )
  )
}

function method ParseAlloc(s: string, n: nat): Option<(Expr, string)>
decreases |s|, n;
requires n >= 1;
ensures ParseAlloc(s, n).Some? ==> |ParseAlloc(s, n).val.1| < |s|;
ensures ParseAlloc(s, n).Some? ==> LocsE(ParseAlloc(s, n).val.0) == {};
{
  var t := SkipWS(KW("ref", s));
  if t.None? then None else (
    var l := SkipWS(Ch('(', t.val.1));
    if l.None? then None else (
      assert |l.val.1| < |s|;
      var e := ParseExprRec(l.val.1, n - 1);
      if e.None? then None else (
        var r := SkipWS(Ch(')', e.val.1));
        if r.None? then None else (
          Some((Alloc(e.val.0), r.val.1))
        )
      )
    )
  )
}

function method ParseShare(s: string, n: nat): Option<(Expr, string)>
decreases |s|, n;
requires n >= 1;
ensures ParseShare(s, n).Some? ==> |ParseShare(s, n).val.1| < |s|;
ensures ParseShare(s, n).Some? ==> LocsE(ParseShare(s, n).val.0) == {};
{
  var t := SkipWS(KW("share", s));
  if t.None? then None else (
    var l := SkipWS(Ch('(', t.val.1));
    if l.None? then None else (
      assert |l.val.1| < |s|;
      var e := ParseExprRec(l.val.1, n - 1);
      if e.None? then None else (
        var r := SkipWS(Ch(')', e.val.1));
        if r.None? then None else (
          Some((Share(e.val.0), r.val.1))
        )
      )
    )
  )
}

function method ParseCopy(s: string, n: nat): Option<(Expr, string)>
decreases |s|, n;
requires n >= 1;
ensures ParseCopy(s, n).Some? ==> |ParseCopy(s, n).val.1| < |s|;
ensures ParseCopy(s, n).Some? ==> LocsE(ParseCopy(s, n).val.0) == {};
{
  var t := SkipWS(KW("copy", s));
  if t.None? then None else (
    var l := SkipWS(Ch('(', t.val.1));
    if l.None? then None else (
      assert |l.val.1| < |s|;
      var e := ParseExprRec(l.val.1, n - 1);
      if e.None? then None else (
        var r := SkipWS(Ch(')', e.val.1));
        if r.None? then None else (
          Some((Copy(e.val.0), r.val.1))
        )
      )
    )
  )
}

function method ParseReceive(s: string, n: nat): Option<(Expr, string)>
decreases |s|, n;
requires n >= 1;
ensures ParseReceive(s, n).Some? ==> |ParseReceive(s, n).val.1| < |s|;
ensures ParseReceive(s, n).Some? ==> LocsE(ParseReceive(s, n).val.0) == {};
{
  var k := SkipWS(KW("receive", s));
  if k.None? then None else (
    var l := SkipWS(Ch('(', k.val.1));
    if l.None? then None else (
      assert |l.val.1| < |s|;
      var e := ParseExprRec(l.val.1, n - 1);
      if e.None? then None else (
        var c := SkipWS(Ch(',', e.val.1));
        if c.None? then None else (
          var t := SkipWS(ParseType(c.val.1));
          if t.None? then None else (
            var r := SkipWS(Ch(')', t.val.1));
            if r.None? then None else (
              Some((Receive(e.val.0, t.val.0), r.val.1))
            )
          )
        )
      )
    )
  )
}

function method ParseAddRec(s: string, n: nat): Option<(Expr, string)>
decreases |s|, n;
ensures ParseAddRec(s, n).Some? ==> |ParseAddRec(s, n).val.1| < |s|;
ensures ParseAddRec(s, n).Some? ==> LocsE(ParseAddRec(s, n).val.0) == {};
{
  if n < 2 then None else (
    var t := SkipWS(Or(Or(Or(Or(Or(Or(ParseDeref(s, n - 1),
                                     ParseAlloc(s, n - 1)),
                                   ParseShare(s, n - 1)),
                                ParseCopy(s, n - 1)),
                             ParseReceive(s, n - 1)),
                          ParseVal(s)),
                       ParseVar(s)));
    if t.None? then None else (
      var p := SkipWS(Ch('+', t.val.1));
      if p.None? then t else (
        var r := ParseAddRec(p.val.1, n - 1);
        if r.None? then t else Some((Add(t.val.0, r.val.0), r.val.1))
      )
    )
  )
}

function method ParseExprRec(s: string, n: nat): Option<(Expr, string)>
decreases |s|, n;
ensures ParseExprRec(s, n).Some? ==> |ParseExprRec(s, n).val.1| < |s|;
ensures ParseExprRec(s, n).Some? ==> LocsE(ParseExprRec(s, n).val.0) == {};
{
  if n == 0 then None else (
    var t := ParseAddRec(s, n - 1);
    if t.None? then None else (
      var p := SkipWS(Or(KW(">", t.val.1), KW("==", t.val.1)));
      if p.None? then t else (
        var r := ParseExprRec(p.val.1, n - 1);
        if r.None? then t else Some((
          if p.val.0 == ">" then GT(t.val.0, r.val.0) else Eq(t.val.0, r.val.0),
          r.val.1))
      )
    )
  )
}

function method ParseExpr(s: string): Option<(Expr, string)>
decreases |s|;
ensures ParseExpr(s).Some? ==> |ParseExpr(s).val.1| < |s|;
ensures ParseExpr(s).Some? ==> LocsE(ParseExpr(s).val.0) == {};
{
  ParseExprRec(s, 10000)
}

function method ParseBlock(s: string, n: nat): Option<(Stmt, string)>
decreases |s|, n;
ensures ParseBlock(s, n).Some? ==> |ParseBlock(s, n).val.1| < |s|;
ensures ParseBlock(s, n).Some? ==> LocsS(ParseBlock(s, n).val.0) == {};
{
  var l := SkipWS(Ch('{', s));
  if l.None? then None else (
    assert |l.val.1| < |s|;
    var stmts := ParseProgRec(l.val.1, n);
    if stmts.None? then (
      var r := SkipWS(Ch('}', l.val.1));
      if r.None? then None else Some((Skip, r.val.1))
    ) else (
      var r := SkipWS(Ch('}', stmts.val.1));
      if r.None? then None else Some((stmts.val.0, r.val.1))
    )
  )
}

function method ParseVarDecl(s: string): Option<(Stmt, string)>
ensures ParseVarDecl(s).Some? ==> |ParseVarDecl(s).val.1| < |s|;
ensures ParseVarDecl(s).Some? ==> LocsS(ParseVarDecl(s).val.0) == {};
{
  var v := SkipWS(KW("var", s));
  if v.None? then None else (
    var id := SkipWS(ParseId(v.val.1));
    if id.None? then None else (
      var c := SkipWS(Ch(':', id.val.1));
      if c.None? then None else (
        var t := SkipWS(ParseType(c.val.1));
        if t.None? then None else (
          var e := SkipWS(Ch('=', t.val.1));
          if e.None? then None else (
            var i := ParseExpr(e.val.1);
            if i.None? then None else (
              var s := SkipWS(Ch(';', i.val.1));
              if s.None? then None else Some((VarDecl(id.val.0, t.val.0, i.val.0), s.val.1))))))))
}

function method ParseAssign(s: string): Option<(Stmt, string)>
ensures ParseAssign(s).Some? ==> |ParseAssign(s).val.1| < |s|;
ensures ParseAssign(s).Some? ==> LocsS(ParseAssign(s).val.0) == {};
{
  var id := SkipWS(ParseId(s));
  if id.None? then None else (
    var e := SkipWS(Ch('=', id.val.1));
    if e.None? then None else (
      var i := ParseExpr(e.val.1);
      if i.None? then None else (
        var s := SkipWS(Ch(';', i.val.1));
        if s.None? then None else Some((Assign(id.val.0, i.val.0), s.val.1)))))
}

function method ParseRefAssign(s: string): Option<(Stmt, string)>
ensures ParseRefAssign(s).Some? ==> |ParseRefAssign(s).val.1| < |s|;
ensures ParseRefAssign(s).Some? ==> LocsS(ParseRefAssign(s).val.0) == {};
{
  var t := SkipWS(Ch('*', s));
  if t.None? then None else (
    var id := SkipWS(ParseId(t.val.1));
    if id.None? then None else (
      var e := SkipWS(Ch('=', id.val.1));
      if e.None? then None else (
        var i := ParseExpr(e.val.1);
        if i.None? then None else (
          var s := SkipWS(Ch(';', i.val.1));
          if s.None? then None else Some((RefAssign(id.val.0, i.val.0), s.val.1))))))
}

function method ParseSend(s: string): Option<(Stmt, string)>
ensures ParseSend(s).Some? ==> |ParseSend(s).val.1| < |s|;
ensures ParseSend(s).Some? ==> LocsS(ParseSend(s).val.0) == {};
{
  var k := SkipWS(KW("send", s));
  if k.None? then None else (
    var l := SkipWS(Ch('(', k.val.1));
    if l.None? then None else (
      assert |l.val.1| < |s|;
      var e := ParseExpr(l.val.1);
      if e.None? then None else (
        var c := SkipWS(Ch(',', e.val.1));
        if c.None? then None else (
          var q := ParseExpr(c.val.1);
          if q.None? then None else (
            var r := SkipWS(Ch(')', q.val.1));
            if r.None? then None else (
              var s := SkipWS(Ch(';', r.val.1));
              if s.None? then None else Some((Send(e.val.0, q.val.0), s.val.1))))))))
}

function method ParseFork(s: string, n: nat): Option<(Stmt, string)>
decreases |s|, n;
ensures ParseFork(s, n).Some? ==> |ParseFork(s, n).val.1| < |s|;
ensures ParseFork(s, n).Some? ==> LocsS(ParseFork(s, n).val.0) == {};
{
  var k := SkipWS(KW("fork", s));
  if k.None? then None else (
    var body := ParseBlock(k.val.1, n);
    if body.None? then None else Some((Fork(body.val.0), body.val.1))
  )
}

function method ParseIf(s: string, n: nat): Option<(Stmt, string)>
decreases |s|, n;
ensures ParseIf(s, n).Some? ==> |ParseIf(s, n).val.1| < |s|;
ensures ParseIf(s, n).Some? ==> LocsS(ParseIf(s, n).val.0) == {};
{
  var ifk := SkipWS(KW("if", s));
  if ifk.None? then None else (
    var lc := SkipWS(Ch('(', ifk.val.1));
    if lc.None? then None else (
      var con := ParseExpr(lc.val.1);
      if con.None? then None else (
        var rc := SkipWS(Ch(')', con.val.1));
        if rc.None? then None else (
          var the := ParseBlock(rc.val.1, n);
          if the.None? then None else (
            var elskw := SkipWS(KW("else", the.val.1));
            assert LocsE(con.val.0) == {};
            assert LocsS(the.val.0) == {};
            if elskw.None? then (
              assert LocsS(Skip) == {};
              assert LocsS(If(con.val.0, the.val.0, Skip)) == {};
              Some((If(con.val.0, the.val.0, Skip), the.val.1))
            ) else (
              var els := ParseBlock(elskw.val.1, n);
              if els.None? then None else (
                assert LocsS(els.val.0) == {};
                assert LocsS(If(con.val.0, the.val.0, els.val.0)) == {};
                Some((If(con.val.0, the.val.0, els.val.0), els.val.1)))))))))
}

function method ParseWhile(s: string, n: nat): Option<(Stmt, string)>
decreases |s|, n;
ensures ParseWhile(s, n).Some? ==> |ParseWhile(s, n).val.1| < |s|;
ensures ParseWhile(s, n).Some? ==> LocsS(ParseWhile(s, n).val.0) == {};
{
  var wk := SkipWS(KW("while", s));
  if wk.None? then None else (
    var lc := SkipWS(Ch('(', wk.val.1));
    if lc.None? then None else (
      var con := ParseExpr(lc.val.1);
      if con.None? then None else (
        var rc := SkipWS(Ch(')', con.val.1));
        if rc.None? then None else (
          var body := ParseBlock(rc.val.1, n);
          if body.None? then None else Some((While(con.val.0, body.val.0), body.val.1))))))
}

function method ParseProgRec(s: string, n: nat): Option<(Stmt, string)>
decreases |s|, n;
ensures ParseProgRec(s, n).Some? ==> |ParseProgRec(s, n).val.1| < |s|;
ensures ParseProgRec(s, n).Some? ==> LocsS(ParseProgRec(s, n).val.0) == {};
{
  if n == 0 then None else (
    var s1 := Or(Or(Or(Or(Or(Or(ParseVarDecl(s),
                                ParseIf(s, n - 1)),
                             ParseWhile(s, n - 1)),
                          ParseFork(s, n - 1)),
                       ParseRefAssign(s)),
                    ParseSend(s)),
                 ParseAssign(s));
    if s1.None? then None else (
      var s2 := ParseProgRec(s1.val.1, n - 1);
      if s2.None? then s1 else Some((Seq(s1.val.0, s2.val.0), s2.val.1))
    )
  )
}

class FileSystem {
  extern static method ReadCmdLine() returns (contents: array<char>)
}

method Parse() returns (res: Option<Stmt>)
ensures res.Some? ==> LocsS(res.val) == {};
{
  var contents: array<char> := FileSystem.ReadCmdLine();
  if contents == null { return None; }
  var pres := SkipWS(ParseProgRec(SkipS(contents[..]), 10000));
  if pres.None? || |pres.val.1| > 0 { return None; }
  res := Some(pres.val.0);
}

// --------- Type Checking ---------

type Gamma = map<string, Type>

function method GammaJoin(g1: Gamma, g2: Gamma): Gamma
ensures GammaExtends(GammaJoin(g1, g2), g1);
ensures GammaExtends(GammaJoin(g1, g2), g2);
{
  map x | x in g1 && x in g2 && g1[x] == g2[x] :: g1[x]
}

function method GammaUnion(g1: Gamma, g2: Gamma): Gamma
ensures GammaExtends(g2, GammaUnion(g1, g2));
ensures forall x :: x in GammaUnion(g1, g2) ==> x in g1 || x in g2;
{
  var g1k: set<string> := (set x | x in g1);
  var g2k: set<string> := (set x | x in g2);
  map x | x in g1k + g2k :: if x in g2k then g2[x] else g1[x]
}

predicate GammaExtends(gamma1: Gamma, gamma2: Gamma)
ensures GammaExtends(gamma1, gamma2) ==> forall x :: x in gamma1 ==> x in gamma2;
{
  forall x :: x in gamma1 ==> x in gamma2 && gamma1[x] == gamma2[x]
}

predicate method MoveType(t: Type) {
  t.RefT?
}

predicate GammaDeclarationsE(g: Gamma, expr: Expr) {
  forall x :: x in ReferencedVarsE(expr) ==> x in g
}

predicate GammaDeclarationsS(g: Gamma, stmt: Stmt)
{
  forall x :: x in ReferencedVarsS(stmt) ==> x in g
}

function method DeclaredVars(stmt: Stmt): Gamma
decreases stmt;
{
  match stmt {
    case VarDecl(x, vtype, vinit) => map[x := vtype]
    case Assign(y, expr) => map[]
    case RefAssign(z, expr) => map[]
    case Send(ch, expr) => map[]
    case If(con, the, els) => GammaUnion(DeclaredVars(the), DeclaredVars(els))
    case CleanUp(g, refs, decls) => map[]
    case While(con, body) => map[]
    case Seq(s1, s2) => GammaUnion(DeclaredVars(s1), DeclaredVars(s2))
    case Fork(s) => DeclaredVars(s)
    case Skip => map[]
  }
}

function method ScopedVars(stmt: Stmt): Gamma
decreases stmt;
ensures forall x :: x in ScopedVars(stmt) ==> x in DeclaredVars(stmt);
{
  match stmt {
    case VarDecl(x, vtype, vinit) => map[x := vtype]
    case Assign(y, expr) => map[]
    case RefAssign(z, expr) => map[]
    case Send(ch, expr) => map[]
    case If(con, the, els) => map[]
    case CleanUp(g, refs, decls) => map[]
    case While(con, body) => map[]
    case Seq(s1, s2) => GammaUnion(GammaWithoutMovedS(ScopedVars(s1), s2), ScopedVars(s2))
    case Fork(s) => map[]
    case Skip => map[]
  }
}

function method ReferencedVarsE(expr: Expr): set<string>
{
  match expr {
    case V(val) => {}
    case Var(x) => {x}
    case Deref(re) => ReferencedVarsE(re)
    case Alloc(ie) => ReferencedVarsE(ie)
    case Share(se) => ReferencedVarsE(se)
    case Copy(ce) => ReferencedVarsE(ce)
    case Receive(ch, t) => ReferencedVarsE(ch)
    case Add(l, r) => ReferencedVarsE(l) + ReferencedVarsE(r)
    case GT(l, r) => ReferencedVarsE(l) + ReferencedVarsE(r)
    case Eq(l, r) => ReferencedVarsE(l) + ReferencedVarsE(r)
  }
}

function method ReferencedVarsS(stmt: Stmt): set<string>
decreases stmt;
{
  ReferencedVarsSDec(stmt, 0)
}

function method ReferencedVarsSDec(stmt: Stmt, n: nat): set<string>
decreases stmt, n;
{
  match stmt {
    case VarDecl(x, vtype, vinit) =>
      ReferencedVarsE(vinit)
    case Assign(y, expr) => ReferencedVarsE(expr) - {y}
    case RefAssign(z, expr) => ReferencedVarsE(expr)
    case Send(ch, expr) => ReferencedVarsE(ch) + ReferencedVarsE(expr)
    case If(con, the, els) =>
      ReferencedVarsE(con) + ReferencedVarsS(the) + ReferencedVarsS(els)
    case CleanUp(g, refs, decls) => {}
    case While(con, body) =>
      ReferencedVarsE(con) + ReferencedVarsS(body)
    case Seq(s1, s2) =>
      ReferencedVarsS(s1) +
      (set x | x in ReferencedVarsS(s2) && x !in ScopedVars(s1) :: x)
    case Fork(s) => ReferencedVarsS(s)
    case Skip => {}
  }
}

predicate ConsumedVarsSInv(stmt: Stmt, n: nat, n2: nat)
ensures ConsumedVarsS(stmt, n) == ConsumedVarsS(stmt, n2);
{
  var res := ConsumedVarsS(stmt, n);
  var res2 := ConsumedVarsS(stmt, n2);
  match stmt {
    case VarDecl(x, vtype, vinit) => (
      assert res == res2;
      true
    )
    case Assign(y, expr) => (
      assert res == res2;
      true
    )
    case RefAssign(z, expr) => (
      assert res == res2;
      true
    )
    case Send(ch, expr) => (
      assert res == res2;
      true
    )
    case If(con, the, els) => (
      assert res == res2;
      true
    )
    case CleanUp(g, refs, decls) => (
      assert res == res2;
      true
    )
    case While(con, body) => (
      assert res == res2;
      true
    )
    case Seq(s1, s2) => (
      assert res == res2;
      true
    )
    case Fork(s) => (
      assert res == res2;
      true
    )
    case Skip => (
      assert res == res2;
      true
    )
  }
}

lemma ConsumedVarsSInvA(stmt: Stmt)
ensures forall i:nat , j:nat :: ConsumedVarsS(stmt, i) == ConsumedVarsS(stmt, j);
{
  assert forall i:nat, j:nat :: ConsumedVarsSInv(stmt, i, j);
}

function method ConsumedVarsS(stmt: Stmt, n: nat): set<string>
decreases stmt, n;
{
  match stmt {
    case VarDecl(x, vtype, vinit) => {}
    case Assign(y, expr) => {}
    case RefAssign(z, expr) => {}
    case Send(ch, expr) => {}
    case If(con, the, els) => ConsumedVarsS(the, 1) + ConsumedVarsS(els, 1)
    case CleanUp(g, refs, decls) =>
      (set x | x in ScopedVars(decls)) + (set x | x in ReferencedVarsS(refs) && x in g && MoveType(g[x]))
                                       + ConsumedVarsS(refs, 1)
    case While(con, body) => ConsumedVarsS(body, 1)
    case Seq(s1, s2) => ConsumedVarsS(s1, 1) + ConsumedVarsS(s2, 1)
    case Fork(s) => ConsumedVarsS(s, 1) + UpdatedVarsS(s)
    case Skip => {}
  }
}

function method UpdatedVarsS(stmt: Stmt): set<string>
decreases stmt;
{
  match stmt {
    case VarDecl(x, vtype, vinit) => {}
    case Assign(y, expr) => {}
    case RefAssign(z, expr) => {z}
    case Send(ch, expr) => {}
    case If(con, the, els) => UpdatedVarsS(the) + UpdatedVarsS(els)
    case CleanUp(g, refs, decls) => {}
    case While(con, body) => UpdatedVarsS(body)
    case Seq(s1, s2) =>
      UpdatedVarsS(s1) +
      (set x | x in UpdatedVarsS(s2) && x !in ScopedVars(s1) :: x)
    case Fork(s) => UpdatedVarsS(s)
    case Skip => {}
  }
}

function GammaWithoutMovedE(g: Gamma, expr: Expr): Gamma
ensures GammaExtends(GammaWithoutMovedE(g, expr), g);
{
  map x | x in g && (x !in ReferencedVarsE(expr) || !MoveType(g[x])) :: g[x]
}

function method GammaWithoutMovedS(g: Gamma, stmt: Stmt): Gamma
ensures GammaExtends(GammaWithoutMovedS(g, stmt), g);
decreases stmt;
{
  map x | x in g && !(x in ReferencedVarsSDec(stmt, 0) && MoveType(g[x]))
                 && !(x in ConsumedVarsS(stmt, 0)):: g[x]
}

function method GammaWithoutUpdatedS(g: Gamma, stmt: Stmt): Gamma
ensures GammaExtends(GammaWithoutUpdatedS(g, stmt), g);
{
  map x | x in g && x !in UpdatedVarsS(stmt):: g[x]
}

predicate GammaWithoutMovedSeqDistributionStr1(g: Gamma, s1: Stmt, s2: Stmt, x: string)
requires x in GammaWithoutMovedS(GammaWithoutMovedS(g, s1), s2);
ensures x in GammaWithoutMovedS(g, Seq(s1,s2));
{
  assert x in g;
  assert x !in ConsumedVarsS(s1, 0);
  assert x !in ConsumedVarsS(s2, 0);
  assert x !in ConsumedVarsS(Seq(s1, s2), 0);

  if MoveType(g[x]) then (
    assert x !in ReferencedVarsSDec(s1, 0);
    assert x !in ReferencedVarsSDec(s2, 0);
    assert x !in (set y | y in ReferencedVarsS(s2) && y !in ScopedVars(s1) :: y);
    assert x !in ReferencedVarsSDec(Seq(s1, s2), 0);
    assert x in GammaWithoutMovedS(g, Seq(s1,s2));
    true
  ) else (
    assert x in GammaWithoutMovedS(g, Seq(s1,s2));
    true
  )
}

predicate GammaWithoutMovedSeqDistributionStr2(g: Gamma, s1: Stmt, s2: Stmt, x: string)
requires g !! ScopedVars(s1);
requires x in GammaWithoutMovedS(g, Seq(s1,s2));
ensures x in GammaWithoutMovedS(GammaWithoutMovedS(g, s1), s2);
{
  assert x in g;
  assert x !in ConsumedVarsS(Seq(s1, s2), 0);
  assert x !in ConsumedVarsS(s1, 1) + ConsumedVarsS(s2, 1);
  assert x !in ConsumedVarsS(s1, 0) + ConsumedVarsS(s2, 0);
  assert x !in ConsumedVarsS(s1, 0);
  assert x !in ConsumedVarsS(s2, 0);

  if MoveType(g[x]) then (
    assert x !in ReferencedVarsSDec(Seq(s1, s2), 0);
    assert x !in ReferencedVarsS(s1) + (set x | x in ReferencedVarsS(s2) && x !in ScopedVars(s1) :: x);

    assert x !in ReferencedVarsS(s1);
    assert x in GammaWithoutMovedS(g, s1);
    assert x !in ReferencedVarsS(s2) || x in ScopedVars(s1);
    assert x !in ScopedVars(s1);
    assert x !in ReferencedVarsS(s2);
    assert x in GammaWithoutMovedS(GammaWithoutMovedS(g, s1), s2);
    true
  ) else (
    assert x in GammaWithoutMovedS(GammaWithoutMovedS(g, s1), s2);
    true
  )
}

lemma GammaWithoutMovedSeqDistribution(g: Gamma, s1: Stmt, s2: Stmt)
requires g !! ScopedVars(s1);
ensures GammaWithoutMovedS(g, Seq(s1,s2)) == GammaWithoutMovedS(GammaWithoutMovedS(g, s1), s2);
{
  assert forall x :: x in GammaWithoutMovedS(GammaWithoutMovedS(g, s1), s2)
                 ==> GammaWithoutMovedSeqDistributionStr1(g, s1, s2, x)
                 ==> x in GammaWithoutMovedS(g, Seq(s1,s2));
  assert forall x :: x in GammaWithoutMovedS(g, Seq(s1,s2))
                 ==> GammaWithoutMovedSeqDistributionStr2(g, s1, s2, x)
                 ==> x in GammaWithoutMovedS(GammaWithoutMovedS(g, s1), s2);
}

predicate GammaWithoutMovedWhileDistributionStr1(g: Gamma, con: Expr, body: Stmt, x: string)
requires x in GammaJoin(GammaWithoutMovedE(g, con), GammaWithoutMovedS(GammaWithoutMovedE(g, con), body));
ensures x in GammaWithoutMovedS(g, While(con, body));
{
  assert x in GammaWithoutMovedE(g, con);
  assert x in g;
  assert x !in ConsumedVarsS(body, 0);
  assert x !in ConsumedVarsS(While(con, body), 0);
  if MoveType(g[x]) then (
    assert x !in ReferencedVarsE(con);
    assert x !in ReferencedVarsS(body);
    assert x in GammaWithoutMovedS(g, While(con, body));
    true
  ) else (
    assert x in GammaWithoutMovedS(g, While(con, body));
    true
  )
}

predicate GammaWithoutMovedWhileDistributionStr2(g: Gamma, con: Expr, body: Stmt, x: string)
requires x in GammaWithoutMovedS(g, While(con, body));
ensures x in GammaJoin(GammaWithoutMovedE(g, con), GammaWithoutMovedS(GammaWithoutMovedE(g, con), body));
{
  assert x in g;
  assert x !in ConsumedVarsS(While(con, body), 0);
  assert x !in ConsumedVarsS(body, 1);
  assert x !in ConsumedVarsS(body, 0);
  if MoveType(g[x]) then (
    assert x !in ReferencedVarsS(While(con, body));
    assert x !in ReferencedVarsSDec(While(con, body), 0);
    assert x !in ReferencedVarsE(con) + ReferencedVarsS(body);
    assert x !in ReferencedVarsE(con);
    assert x !in ReferencedVarsS(body);
    assert x in GammaWithoutMovedE(g, con);
    assert x in GammaWithoutMovedS(GammaWithoutMovedE(g, con), body);
    assert x in GammaJoin(GammaWithoutMovedE(g, con), GammaWithoutMovedS(GammaWithoutMovedE(g, con), body));
    true
  ) else (
    assert x in GammaJoin(GammaWithoutMovedE(g, con), GammaWithoutMovedS(GammaWithoutMovedE(g, con), body));
    true
  )
}

lemma GammaWithoutMovedWhileDistribution(g: Gamma, con: Expr, body: Stmt)
ensures GammaJoin(GammaWithoutMovedE(g, con), GammaWithoutMovedS(GammaWithoutMovedE(g, con), body))
     == GammaWithoutMovedS(g, While(con, body));
{
  assert forall x :: x in GammaJoin(GammaWithoutMovedE(g, con), GammaWithoutMovedS(GammaWithoutMovedE(g, con), body))
                 ==> GammaWithoutMovedWhileDistributionStr1(g, con, body, x)
                 ==> x in GammaWithoutMovedS(g, While(con, body));
  assert forall x :: x in GammaWithoutMovedS(g, While(con, body))
                 ==> GammaWithoutMovedWhileDistributionStr2(g, con, body, x)
                 ==> x in GammaJoin(GammaWithoutMovedE(g, con), GammaWithoutMovedS(GammaWithoutMovedE(g, con), body));
}

predicate GammaWithoutMovedIfDistributionStr1(g: Gamma, cond: Expr, the: Stmt, els: Stmt, x: string)
requires x in GammaWithoutMovedS(GammaWithoutMovedS(GammaWithoutMovedE(g, cond), the), els);
ensures x in GammaWithoutMovedS(g, If(cond, the, els));
{
  assert x in g;
  assert x !in ConsumedVarsS(the, 0);
  assert x !in ConsumedVarsS(els, 0);
  assert x !in ConsumedVarsS(If(cond, the, els), 0);
  if MoveType(g[x]) then (
    assert x !in ReferencedVarsE(cond);
    assert x !in ReferencedVarsS(the);
    assert x !in ReferencedVarsS(els);
    assert x !in ReferencedVarsS(If(cond, the, els));
    assert x in GammaWithoutMovedS(g, If(cond, the, els));
    true
  ) else (
    assert x in GammaWithoutMovedS(g, If(cond, the, els));
    true
  )
}

predicate GammaWithoutMovedIfDistributionStr2(g: Gamma, cond: Expr, the: Stmt, els: Stmt, x: string)
requires x in GammaWithoutMovedS(g, If(cond, the, els));
ensures x in GammaWithoutMovedS(GammaWithoutMovedS(GammaWithoutMovedE(g, cond), the), els);
{
  assert x in g;
  assert x !in ConsumedVarsS(If(cond, the, els), 0);
  assert x !in ConsumedVarsS(the, 1) + ConsumedVarsS(els, 1);
  assert x !in ConsumedVarsS(the, 0) + ConsumedVarsS(els, 0);
  assert x !in ConsumedVarsS(the, 0);
  assert x !in ConsumedVarsS(els, 0);
  if MoveType(g[x]) then (
    assert x !in ReferencedVarsS(If(cond, the, els));
    assert x !in ReferencedVarsSDec(If(cond, the, els), 0);
    assert x !in ReferencedVarsE(cond) + ReferencedVarsS(the) + ReferencedVarsS(els);
    assert x !in ReferencedVarsE(cond);
    assert x !in ReferencedVarsS(the);
    assert x !in ReferencedVarsS(els);
    assert x in GammaWithoutMovedS(GammaWithoutMovedS(GammaWithoutMovedE(g, cond), the), els);
    true
  ) else (
    assert x in GammaWithoutMovedS(GammaWithoutMovedS(GammaWithoutMovedE(g, cond), the), els);
    true
  )
}

lemma GammaWithoutMovedIfDistribution(g: Gamma, cond: Expr, the: Stmt, els: Stmt)
ensures GammaWithoutMovedS(g, If(cond, the, els)) ==
        GammaWithoutMovedS(GammaWithoutMovedS(GammaWithoutMovedE(g, cond), the), els);
{
  assert forall x :: x in GammaWithoutMovedS(GammaWithoutMovedS(GammaWithoutMovedE(g, cond), the), els)
                 ==> GammaWithoutMovedIfDistributionStr1(g, cond, the, els, x)
                 ==> x in GammaWithoutMovedS(g, If(cond, the, els));
  assert forall x :: x in GammaWithoutMovedS(g, If(cond, the, els))
                 ==> GammaWithoutMovedIfDistributionStr2(g, cond, the, els, x)
                 ==> x in GammaWithoutMovedS(GammaWithoutMovedS(GammaWithoutMovedE(g, cond), the), els);
}

datatype TypeCheckERes = Fail | Type(gamma: Gamma, typ: Type)
function method TypeCheckV(val: Value): Type
{
  match val {
    case Num(_) => NumT
    case Bool(_) => BoolT
    case Ref(l) => RefT(l.t)
    case SRef(l) => ShareT(l.t)
  }
}

function method TypeCheckE(g: Gamma, expr: Expr): TypeCheckERes
decreases expr;
ensures TypeCheckE(g, expr).Type? ==>
        GammaDeclarationsE(g, expr);
ensures TypeCheckE(g, expr).Type? ==>
        TypeCheckE(g, expr).gamma == GammaWithoutMovedE(g, expr);
ensures TypeCheckE(g, expr).Type? && expr.Deref? ==>
        TypeCheckE(g, expr.re).Type? &&
        (TypeCheckE(g, expr.re).typ.RefT? || TypeCheckE(g, expr.re).typ.ShareT?) &&
        (TypeCheckE(g, expr.re).typ.RefT? ==> TypeCheckE(g, expr).typ == TypeCheckE(g, expr.re).typ.t) &&
        (TypeCheckE(g, expr.re).typ.ShareT? ==> TypeCheckE(g, expr).typ == TypeCheckE(g, expr.re).typ.st);
ensures TypeCheckE(g, expr).Type? && expr.Alloc? ==>
        TypeCheckE(g, expr.ie).Type? &&
        TypeCheckE(g, expr).typ == RefT(TypeCheckE(g, expr.ie).typ);
ensures TypeCheckE(g, expr).Type? && expr.Share? ==>
        TypeCheckE(g, expr.se).Type? &&
        TypeCheckE(g, expr.se).typ.RefT? &&
        TypeCheckE(g, expr).typ == ShareT(TypeCheckE(g, expr.se).typ.t);
ensures TypeCheckE(g, expr).Type? && expr.Copy? ==>
        TypeCheckE(g, expr.ce).Type? &&
        TypeCheckE(g, expr.ce).typ.ShareT? &&
        TypeCheckE(g, expr).typ == RefT(TypeCheckE(g, expr.ce).typ.st);
ensures TypeCheckE(g, expr).Type? && expr.Receive? ==>
        TypeCheckE(g, expr.ch).Type? &&
        TypeCheckE(g, expr.ch).typ.NumT? &&
        TypeCheckE(g, expr).typ == expr.t;
ensures TypeCheckE(g, expr).Type? && expr.Add? ==>
        TypeCheckE(g, expr).typ.NumT? &&
        TypeCheckE(g, expr.leftA).Type? &&
        TypeCheckE(g, expr.leftA).typ.NumT? &&
        TypeCheckE(GammaWithoutMovedE(g, expr.leftA), expr.rightA).Type? &&
        TypeCheckE(GammaWithoutMovedE(g, expr.leftA), expr.rightA).typ.NumT?;
ensures TypeCheckE(g, expr).Type? && expr.GT? ==>
        TypeCheckE(g, expr).typ.BoolT? &&
        TypeCheckE(g, expr.leftG).Type? &&
        TypeCheckE(g, expr.leftG).typ.NumT? &&
        TypeCheckE(GammaWithoutMovedE(g, expr.leftG), expr.rightG).Type? &&
        TypeCheckE(GammaWithoutMovedE(g, expr.leftG), expr.rightG).typ.NumT?;
ensures TypeCheckE(g, expr).Type? && expr.Eq? ==>
        TypeCheckE(g, expr).typ.BoolT? &&
        TypeCheckE(g, expr.leftE).Type? &&
        (TypeCheckE(g, expr.leftE).typ.NumT? || TypeCheckE(g, expr.leftE).typ.BoolT?) &&
        TypeCheckE(GammaWithoutMovedE(g, expr.leftE), expr.rightE).Type? &&
        TypeCheckE(g, expr.leftE).typ ==
        TypeCheckE(GammaWithoutMovedE(g, expr.leftE), expr.rightE).typ;
{
  match expr {

    case V(val) => (
      Type(g, TypeCheckV(val))
    )

    case Var(x) =>
      if x in g then (
        if MoveType(g[x]) then (
          var g2 :=  (map y | y in g && x != y :: g[y]);
          assert g2 == GammaWithoutMovedE(g, expr);
          Type(g2, g[x])
        ) else (
          Type(g, g[x])
        )
      ) else (
        Fail
      )

    case Deref(re) =>
      match TypeCheckE(g, re) {
        case Type(g2, rt) =>
          if rt.RefT? then
            Type(g2, rt.t)
          else if rt.ShareT? then
            Type(g2, rt.st)
          else
            Fail
        case Fail => Fail
      }

    case Alloc(ie) =>
      match TypeCheckE(g, ie) {
        case Type(g2, it) => Type(g2, RefT(it))
        case Fail => Fail
      }

    case Share(se) =>
      match TypeCheckE(g, se) {
        case Type(g2, st) => if !st.RefT? then Fail else (
          Type(g2, ShareT(st.t))
        )
        case Fail => Fail
      }

    case Copy(ce) =>
      match TypeCheckE(g, ce) {
        case Type(g2, ct) => if !ct.ShareT? then Fail else Type(g2, RefT(ct.st))
        case Fail => Fail
      }

    case Receive(ch, t) =>
      match TypeCheckE(g, ch) {
        case Type(g2, ct) => if !ct.NumT? then Fail else Type(g2, t)
        case Fail => Fail
      }

    case Add(l, r) =>
      match TypeCheckE(g, l) {
        case Type(g1, lt) => if !lt.NumT? then Fail else match TypeCheckE(g1, r) {
          case Type(g2, rt) => if !rt.NumT? then Fail else (
            Type(g2, NumT)
          )
          case Fail => Fail
        }
        case Fail => Fail
      }

    case GT(l, r) =>
      match TypeCheckE(g, l) {
        case Type(g1, lt) => if !lt.NumT? then Fail else match TypeCheckE(g1, r) {
          case Type(g2, rt) => if !rt.NumT? then Fail else (
            Type(g2, BoolT)
          )
          case Fail => Fail
        }
        case Fail => Fail
      }

    case Eq(l, r) =>
      match TypeCheckE(g, l) {
        case Type(g1, lt) => match TypeCheckE(g1, r) {
          case Type(g2, rt) => if !lt.ShareT? && !lt.RefT? && lt == rt then (
            Type(g2, BoolT)
          ) else (
            Fail
          )
          case Fail => Fail
        }
        case Fail => Fail
      }

  }
}

function method TypeCheckS(g: Gamma, stmt: Stmt): Option<Gamma>
decreases stmt;
ensures TypeCheckS(g, stmt).Some? ==> GammaDeclarationsS(g, stmt);
ensures TypeCheckS(g, stmt).Some? ==> g !! DeclaredVars(stmt);
ensures TypeCheckS(g, stmt).Some? ==> g !! ScopedVars(stmt);
ensures TypeCheckS(g, stmt).Some? ==>
        TypeCheckS(g, stmt).val ==
        GammaUnion(GammaWithoutMovedS(g, stmt), ScopedVars(stmt));
ensures TypeCheckS(g, stmt).Some? && stmt.VarDecl? ==>
        stmt.x !in g &&
        TypeCheckE(g, stmt.vinit).Type? && TypeCheckE(g, stmt.vinit).typ == stmt.vtype;
ensures TypeCheckS(g, stmt).Some? && stmt.Assign? ==>
        TypeCheckE(g, stmt.expr).Type? &&
        stmt.y in TypeCheckE(g, stmt.expr).gamma &&
        TypeCheckE(g, stmt.expr).typ == TypeCheckE(g, stmt.expr).gamma[stmt.y];
ensures TypeCheckS(g, stmt).Some? && stmt.RefAssign? ==>
        TypeCheckE(g, stmt.rexpr).Type? &&
        stmt.z in TypeCheckE(g, stmt.rexpr).gamma &&
        TypeCheckE(g, stmt.rexpr).gamma[stmt.z].RefT? &&
        TypeCheckE(g, stmt.rexpr).gamma[stmt.z].t == TypeCheckE(g, stmt.rexpr).typ;
ensures TypeCheckS(g, stmt).Some? && stmt.Send? ==>
        TypeCheckE(g, stmt.ch).Type? &&
        TypeCheckE(g, stmt.ch).typ.NumT? &&
        TypeCheckE(TypeCheckE(g, stmt.ch).gamma, stmt.send).Type? &&
        TypeCheckS(g, stmt).val == TypeCheckE(TypeCheckE(g, stmt.ch).gamma, stmt.send).gamma;
ensures TypeCheckS(g, stmt).Some? && stmt.If? ==>
        TypeCheckE(g, stmt.cond).Type? &&
        TypeCheckE(g, stmt.cond).typ == BoolT &&
        TypeCheckS(TypeCheckE(g, stmt.cond).gamma, stmt.the).Some? &&
        TypeCheckS(TypeCheckE(g, stmt.cond).gamma, stmt.els).Some? &&
        DeclaredVars(stmt.the) !! DeclaredVars(stmt.els) &&
        g !! DeclaredVars(stmt.els);
ensures TypeCheckS(g, stmt).Some? && stmt.While? ==>
        TypeCheckE(g, stmt.wcond).Type? &&
        TypeCheckE(g, stmt.wcond).typ.BoolT? &&
        TypeCheckS(TypeCheckE(g, stmt.wcond).gamma, stmt.wbody).Some? &&
        GammaWithoutMovedS(GammaWithoutMovedE(g, stmt.wcond), stmt.wbody) == g &&
        DeclaredVars(stmt.wbody) == map[];
ensures TypeCheckS(g, stmt).Some? && stmt.Fork? ==>
        TypeCheckS(g, stmt.fork).Some? &&
        g !! DeclaredVars(stmt.fork);
ensures TypeCheckS(g, stmt).Some? && stmt.Seq? ==>
        TypeCheckS(g, stmt.s1).Some? &&
        TypeCheckS(TypeCheckS(g, stmt.s1).val, stmt.s2).Some? &&
        DeclaredVars(stmt.s1) !! DeclaredVars(stmt.s2);
ensures TypeCheckS(g, stmt).Some? && stmt.Skip? ==> g == TypeCheckS(g, stmt).val;
{
  match stmt {

    case VarDecl(x, vtype, vinit) =>
      if x in g then
        None
      else
        match TypeCheckE(g, vinit) {
          case Type(g2, vt) =>
            if vt == vtype then (
              assert g !! DeclaredVars(stmt);
              assert GammaDeclarationsS(g, stmt);
              assert g2[x := vt] == GammaUnion(GammaWithoutMovedS(g, stmt), ScopedVars(stmt));
              Some(g2[x := vt])
            ) else None
          case Fail => None
        }

    case Assign(y, expr) =>
      match TypeCheckE(g, expr) {
        case Type(g2, ct) => (
          if y !in g2 || g2[y] != ct then None else
            Some(g2[y := ct])
        )
        case Fail => None
      }

    case RefAssign(z, expr) =>
      match TypeCheckE(g, expr) {
        case Type(g2, ct) => (
          if z !in g2 || !g2[z].RefT? || g2[z].t != ct then None else
            Some(g2)
        )
        case Fail => None
      }

    case Send(ch, expr) =>
      match TypeCheckE(g, ch) {
        case Type(g2, ct) => if !ct.NumT? then None else (
          match TypeCheckE(g2, expr) {
            case Type(g3, _) => Some(g3)
            case Fail => None
          }
        )
        case Fail => None
      }

    case If(con, the, els) =>
      match TypeCheckE(g, con) {
        case Type(g2, ct) => if !ct.BoolT? then None else match TypeCheckS(g2, the) {
          case Some(g3) => match TypeCheckS(g2, els) {
            case Some(g4) => if !(g !! DeclaredVars(the)) || !(g !! DeclaredVars(els)) || !(DeclaredVars(the) !! DeclaredVars(els)) then None else (
              assert g !! DeclaredVars(stmt);
              assert GammaDeclarationsE(g, con);
              assert GammaDeclarationsS(g2, the);
              assert GammaDeclarationsS(g2, els);
              assert GammaDeclarationsS(g, stmt);

              assert g2 == GammaWithoutMovedE(g, con);
              assert g3 == GammaUnion(GammaWithoutMovedS(g2, the), ScopedVars(the));
              assert g4 == GammaUnion(GammaWithoutMovedS(g2, els), ScopedVars(els));

              assert GammaJoin(g2, g3) == GammaWithoutMovedS(GammaWithoutMovedE(g, con), the);

              assert GammaJoin(GammaJoin(g2, g3), g4) ==
                     GammaWithoutMovedS(GammaWithoutMovedS(GammaWithoutMovedE(g, con), the), els);

              GammaWithoutMovedIfDistribution(g, con, the, els);

              assert GammaJoin(GammaJoin(g2, g3), g4) ==
                     GammaWithoutMovedS(g, stmt);
              assert GammaJoin(GammaJoin(g2, g3), g4) == GammaUnion(GammaWithoutMovedS(g, stmt), ScopedVars(stmt));
              Some(GammaJoin(GammaJoin(g2, g3), g4))
            )
            case None => None
          }
          case None => None
        }
        case Fail => None
      }

    case CleanUp(gs, refs, decls) => (
      assert g !! DeclaredVars(stmt);
      assert GammaWithoutMovedS(g, stmt) == GammaUnion(GammaWithoutMovedS(g, stmt), ScopedVars(stmt));
      Some(GammaWithoutMovedS(g, stmt)))

    case While(con, body) =>
      match TypeCheckE(g, con) {
        case Type(g2, ct) => if !ct.BoolT? then None else match TypeCheckS(g2, body) {
          case Some(g3) => if GammaJoin(g2, g3) != g || DeclaredVars(body) != map[] then None else (
            assert g3 == GammaUnion(GammaWithoutMovedS(GammaWithoutMovedE(g, con), body), ScopedVars(body));
            assert GammaJoin(g2, g3) == GammaWithoutMovedS(GammaWithoutMovedE(g, con), body);
            assert ScopedVars(stmt) == map[];
            assert GammaUnion(GammaWithoutMovedS(g, stmt), ScopedVars(stmt)) == GammaWithoutMovedS(g, stmt);
            GammaWithoutMovedWhileDistribution(g, con, body);
            assert GammaJoin(g2, g3) == GammaWithoutMovedS(g, stmt);
            Some(GammaJoin(g2, g3)))
          case None => None
        }
        case Fail => None
      }

    case Fork(s) =>
      match TypeCheckS(g, s) {
        case Some(g2) => if !(g !! DeclaredVars(s)) then None else (
          assert GammaJoin(g, g2) ==
            GammaJoin(g, GammaUnion(GammaWithoutMovedS(g, s), ScopedVars(s)));
          assert GammaJoin(g, g2) == GammaWithoutMovedS(g, s);
          assert ReferencedVarsSDec(s, 0) == ReferencedVarsSDec(stmt, 0);
          assert ConsumedVarsS(s, 0) + UpdatedVarsS(s) == ConsumedVarsS(stmt, 0);
          assert GammaWithoutUpdatedS(GammaWithoutMovedS(g, s), s) == GammaWithoutMovedS(g, stmt);
          assert GammaWithoutUpdatedS(GammaJoin(g, g2), s) == GammaWithoutMovedS(g, stmt);
          assert ScopedVars(stmt) == map[];
          assert GammaWithoutUpdatedS(GammaJoin(g, g2), s) ==
            GammaUnion(GammaWithoutMovedS(g, stmt), ScopedVars(stmt));
          Some(GammaWithoutUpdatedS(GammaJoin(g, g2), s))
        )
        case None => None
      }

    case Seq(s1, s2) =>
      match TypeCheckS(g, s1) {
        case Some(g2) => match TypeCheckS(g2, s2) {
          case Some(g3) => if !(DeclaredVars(s1) !! DeclaredVars(s2)) then (
            None
          ) else if !(g !! DeclaredVars(s2)) then (
            None
          ) else (
            assert g !! DeclaredVars(stmt);
            assert GammaDeclarationsS(g, stmt);
            assert g2 == GammaUnion(GammaWithoutMovedS(g, s1), ScopedVars(s1));
            assert g3 == GammaUnion(GammaWithoutMovedS(g2, s2), ScopedVars(s2));

            assert g3 == GammaUnion(
              GammaWithoutMovedS(GammaUnion(GammaWithoutMovedS(g, s1), ScopedVars(s1)), s2),
              ScopedVars(s2));
            assert g3 == GammaUnion(
              GammaWithoutMovedS(GammaUnion(GammaWithoutMovedS(g, s1), ScopedVars(s1)), s2),
              ScopedVars(s2));
            assert g3 == GammaUnion(
              GammaWithoutMovedS(GammaWithoutMovedS(g, s1), s2),
              ScopedVars(stmt));

            GammaWithoutMovedSeqDistribution(g, s1, s2);

            assert g3 == GammaUnion(GammaWithoutMovedS(g, stmt), ScopedVars(stmt));
            Some(g3)
          )
          case None => None
        }
        case None => None
      }

    case Skip => (
      assert g == GammaUnion(GammaWithoutMovedS(g, stmt), ScopedVars(stmt));
      Some(g)
    )
  }
}

// --------- Evaluating ---------

type Sigma = map<string, Value>
type Heap = map<Loc, Value>
type Channels = map<int, seq<Value>>

function LocsH(h: Heap): set<Loc> {
  (set x | x in h && h[x].Ref? :: h[x].l) +
  (set x | x in h && h[x].SRef? :: h[x].sl)
}

function LocsChR(c: Channels): set<Loc>
ensures forall l: Loc ::
       (exists n, m :: n in c && m in c[n] && m.Ref? && m.l == l)
   ==> l in LocsChR(c);
{
  set x, y | x in c && y in c[x] && y.Ref? :: y.l
}

function LocsChS(c: Channels): set<Loc>
ensures forall l: Loc ::
       (exists n, m :: n in c && m in c[n] && m.SRef? && m.sl == l)
   ==> l in LocsChS(c);
{
  set x, y | x in c && y in c[x] && y.SRef? :: y.sl
}

function LocsCh(c: Channels): set<Loc>
ensures forall l: Loc ::
       (exists n, m :: n in c && 0 <= m < |c[n]| && ((c[n][m].Ref? && c[n][m].l == l) ||
                                                     (c[n][m].SRef? && c[n][m].sl == l)))
   ==> l in LocsCh(c);
{
  LocsChR(c) + LocsChS(c)
}

function LocsSig(sig: Sigma): set<Loc> {
  (set x | x in sig && sig[x].Ref? :: sig[x].l) +
  (set x | x in sig && sig[x].SRef? :: sig[x].sl)
}

function method SigmaWithoutMovedS(s: Sigma, stmt: Stmt): Sigma
decreases stmt;
ensures forall x :: x in SigmaWithoutMovedS(s, stmt) ==> x in s;
{
  map x | x in s && !(x in ReferencedVarsSDec(stmt, 0) && MoveType(TypeCheckV(s[x])))
                 && !(x in ConsumedVarsS(stmt, 0)) :: s[x]
}

function method TypeSigma(s: Sigma): Gamma
ensures forall x :: x in s <==> x in TypeSigma(s);
ensures forall x :: x in s ==> TypeCheckV(s[x]) == TypeSigma(s)[x];
{
  map x | x in s :: TypeCheckV(s[x])
}

predicate HeapWellDefined(h: Heap)
{
  forall x :: x in h ==> x.t == TypeCheckV(h[x])
}

predicate HeapDeclarationsE(c: Channels, h: Heap, sig: Sigma, e: Expr)
ensures HeapDeclarationsE(c, h, sig, e) ==> forall x :: x in LocsH(h) ==> x in h;
ensures HeapDeclarationsE(c, h, sig, e) ==> forall x :: x in LocsSig(sig) ==> x in h;
ensures HeapDeclarationsE(c, h, sig, e) ==> forall x :: x in LocsE(e) ==> x in h;
ensures HeapDeclarationsE(c, h, sig, e) ==> forall x :: x in LocsCh(c) ==> x in h;
{
  forall x :: x in LocsCh(c) + LocsH(h) + LocsSig(sig) + LocsE(e) ==> x in h
}

predicate HeapDeclarationsAlloc(h: Heap, ie: Expr, newL: Loc, x: Loc)
requires ie.V?;
requires forall y :: y in LocsH(h) ==> y in h;
requires forall y :: y in LocsE(ie) ==> y in h;
requires newL == Loc(|h|, TypeCheckV(ie.val));
requires x in LocsH(h[newL := ie.val]);
ensures x in h[newL := ie.val];
{
  if x == newL then (
    assert x in h[newL := ie.val];
    true
  ) else if x in LocsH(h) then (
    assert x in h;
    assert x in h[newL := ie.val];
    true
  ) else if ie.val.Ref? then (
    assert x == ie.val.l;
    assert x in LocsE(ie);
    assert x in h;
    assert x in h[newL := ie.val];
    true
  ) else (
    assert x == ie.val.sl;
    assert x in LocsE(ie);
    assert x in h;
    assert x in h[newL := ie.val];
    true
  )
}

function method EvalE(c: Channels, h: Heap, sig: Sigma, expr: Expr): (Channels, Heap, Sigma, Expr)
requires !expr.V?;
requires TypeCheckE(TypeSigma(sig), expr).Type?;
requires HeapWellDefined(h);
requires HeapDeclarationsE(c, h, sig, expr);
ensures HeapWellDefined(EvalE(c, h, sig, expr).1);
ensures HeapDeclarationsE(EvalE(c, h, sig, expr).0, EvalE(c, h, sig, expr).1, EvalE(c, h, sig, expr).2, EvalE(c, h, sig, expr).3);
ensures forall l :: l in h ==> l in EvalE(c, h, sig, expr).1;
ensures forall x :: x in EvalE(c, h, sig, expr).2 ==> x in sig && EvalE(c, h, sig, expr).2[x] == sig[x];
ensures TypeCheckE(TypeSigma(sig), expr) ==
        TypeCheckE(TypeSigma(EvalE(c, h, sig, expr).2), EvalE(c, h, sig, expr).3);
{

  ghost var g := TypeCheckE(TypeSigma(sig), expr);

  match expr {

    case Var(x) => (
      assert x in sig;
      if MoveType(TypeSigma(sig)[x]) then (
        var sig2 := map y | y in sig && x != y :: sig[y];
        assert TypeCheckE(TypeSigma(sig2), V(sig[x])).Type?;
        assert TypeCheckE(TypeSigma(sig2), V(sig[x])).gamma == TypeSigma(sig2);
        assert x in ReferencedVarsE(expr);
        assert x !in g.gamma;
        assert x !in sig2;
        assert x !in TypeSigma(sig2);
        assert g.gamma == TypeSigma(sig2);
        assert g == TypeCheckE(TypeSigma(sig2), V(sig[x]));
        assert HeapDeclarationsE(c, h, sig2, V(sig[x]));
        (c, h, sig2, V(sig[x]))
      ) else (
        assert TypeCheckE(TypeSigma(sig), V(sig[x])).Type?;
        assert g == TypeCheckE(TypeSigma(sig), V(sig[x]));
        assert HeapDeclarationsE(c, h, sig, Var(x));
        assert forall l :: l in LocsSig(sig) ==> l in h;
        assert forall l :: l in LocsE(V(sig[x])) ==> l in LocsSig(sig);
        assert forall l :: l in LocsE(V(sig[x])) ==> l in LocsSig(sig) && l in h;
        assert HeapDeclarationsE(c, h, sig, V(sig[x]));
        (c, h, sig, V(sig[x]))
      )
    )

    case Deref(re) => (
      if !re.V? then (
        assert TypeCheckE(TypeSigma(sig), re).Type?;
        var (c2, h2, sig2, re2) := EvalE(c, h, sig, re);
        assert g == TypeCheckE(TypeSigma(sig2), Deref(re2));
        assert HeapDeclarationsE(c2, h2, sig2, Deref(re2));
        (c2, h2, sig2, Deref(re2))
      ) else if re.val.Ref? then (
        assert TypeCheckE(TypeSigma(sig), re).typ.RefT?;
        assert TypeCheckE(TypeSigma(sig), re).typ.t == g.typ;
        assert re.val.Ref?;
        assert re.val.l in LocsE(expr);
        assert re.val.l in h;
        assert TypeCheckV(h[re.val.l]) == re.val.l.t;
        assert g == TypeCheckE(TypeSigma(sig), V(h[re.val.l]));
        assert HeapDeclarationsE(c, h, sig, V(h[re.val.l]));
        (c, h, sig, V(h[re.val.l]))
      ) else (
        assert TypeCheckE(TypeSigma(sig), re).typ.ShareT?;
        assert TypeCheckE(TypeSigma(sig), re).typ.st == g.typ;
        assert re.val.SRef?;
        assert re.val.sl in LocsE(expr);
        assert re.val.sl in h;
        assert TypeCheckV(h[re.val.sl]) == re.val.sl.t;
        assert g == TypeCheckE(TypeSigma(sig), V(h[re.val.sl]));
        assert HeapDeclarationsE(c, h, sig, V(h[re.val.sl]));
        (c, h, sig, V(h[re.val.sl]))
      )
    )

    case Alloc(ie) => (
      if !ie.V? then (
        assert TypeCheckE(TypeSigma(sig), ie).Type?;
        var (c2, h2, sig2, ie2) := EvalE(c, h, sig, ie);
        assert g == TypeCheckE(TypeSigma(sig2), Alloc(ie2));
        assert HeapDeclarationsE(c2, h2, sig2, Alloc(ie2));
        (c2, h2, sig2, Alloc(ie2))
      ) else (
        var newL: Loc := Loc(|h|, TypeCheckV(ie.val));
        assert g == TypeCheckE(TypeSigma(sig), V(Ref(newL)));
        assert HeapDeclarationsE(c, h, sig, Alloc(ie));
        assert forall x :: x in LocsH(h) ==> x in h[newL := ie.val];
        assert forall x :: x in LocsE(V(ie.val)) ==> x in h;
        assert forall x :: x in LocsE(V(ie.val)) ==> x in h[newL := ie.val];
        assert forall x :: x in LocsH(h[newL := ie.val]) ==>
                           HeapDeclarationsAlloc(h, ie, newL, x) &&
                           x in h[newL := ie.val];
        assert forall x :: x in LocsSig(sig) ==> x in h[newL := ie.val];
        assert forall x :: x in LocsE(V(Ref(newL))) ==> x in h[newL := ie.val];
        assert HeapDeclarationsE(c, h[newL := ie.val], sig, V(Ref(newL)));
        (c, h[newL := ie.val], sig, V(Ref(newL)))
      )
    )

    case Share(se) =>
      if !se.V? then (
        assert TypeCheckE(TypeSigma(sig), se).Type?;
        var (c2, h2, sig2, se2) := EvalE(c, h, sig, se);
        assert g == TypeCheckE(TypeSigma(sig2), Share(se2));
        assert HeapDeclarationsE(c2, h2, sig2, Share(se2));
        (c2, h2, sig2, Share(se2))
      ) else (
        assert se.val.Ref?;
        assert HeapDeclarationsE(c, h, sig, Share(se));
        assert {se.val.l} == LocsE(Share(se));
        assert se.val.l in h;
        assert {se.val.l} == LocsE(V(SRef(se.val.l)));
        assert HeapDeclarationsE(c, h, sig, V(SRef(se.val.l)));
        (c, h, sig, V(SRef(se.val.l)))
      )

    case Copy(ce) => (
      assert g == TypeCheckE(TypeSigma(sig), Alloc(Deref(ce)));
      assert HeapDeclarationsE(c, h, sig, Alloc(Deref(ce)));
      (c, h, sig, Alloc(Deref(ce)))
    )

    case Receive(ch, t) => (
      if !ch.V? then (
        assert TypeCheckE(TypeSigma(sig), ch).Type?;
        var (c2, h2, sig2, ch2) := EvalE(c, h, sig, ch);
        assert g == TypeCheckE(TypeSigma(sig2), Receive(ch2, t));
        assert HeapDeclarationsE(c2, h2, sig2, Receive(ch2, t));
        (c2, h2, sig2, Receive(ch2, t))
      ) else (
        assert ch.V?;
        assert ch.val.Num?;
        if ch.val.nval !in c || |c[ch.val.nval]| < 1 || TypeCheckV(c[ch.val.nval][0]) != t then (
          (c, h, sig, Receive(ch, t))
        ) else (
          var c2 := c[ch.val.nval := c[ch.val.nval][1..]];
          assert g == TypeCheckE(TypeSigma(sig), V(c[ch.val.nval][0]));
          assert HeapDeclarationsE(c, h, sig, expr);

          assert forall l :: l in LocsCh(c) ==> l in h;
          assert forall l :: l in LocsH(h) ==> l in h;
          assert forall l :: l in LocsSig(sig) ==> l in h;
          assert forall l :: l in LocsE(expr) ==> l in h;

          assert forall n :: n in c2 ==> n in c;
          assert forall n, b :: n in c2 && b in c2[n] ==> b in c[n];
          assert forall l :: l in LocsCh(c2) ==> l in LocsCh(c);

          ghost var v := c[ch.val.nval][0];
          assert if v.Ref? then (
            assert LocsE(V(v)) == {v.l};
            assert v.l in LocsCh(c);
            assert v.l in h;
            true
          ) else if v.SRef? then (
            assert LocsE(V(v)) == {v.sl};
            assert v.sl in LocsCh(c);
            assert v.sl in h;
            true
          ) else (
            assert LocsE(V(v)) == {};
            true
          );
          assert forall l :: l in LocsE(V(c[ch.val.nval][0])) ==> l in h;

          assert forall l :: l in LocsCh(c2) ==> l in h;
          assert forall l :: l in LocsH(h) ==> l in h;
          assert forall l :: l in LocsSig(sig) ==> l in h;
          assert forall l :: l in LocsE(V(c[ch.val.nval][0])) ==> l in h;

          assert HeapDeclarationsE(c2, h, sig, V(c[ch.val.nval][0]));
          (c2, h, sig, V(c[ch.val.nval][0]))
        )
      )
    )

    case Add(l, r) =>
      if !l.V? then (
        assert TypeCheckE(TypeSigma(sig), l).Type?;
        var (c2, h2, sig2, l2) := EvalE(c, h, sig, l);
        assert g == TypeCheckE(TypeSigma(sig2), Add(l2, r));
        assert HeapDeclarationsE(c2, h2, sig2, Add(l2, r));
        (c2, h2, sig2, Add(l2, r))
      ) else if !r.V? then (
        var (c2, h2, sig2, r2) := EvalE(c, h, sig, r);
        assert g == TypeCheckE(TypeSigma(sig2), Add(l, r2));
        assert HeapDeclarationsE(c2, h2, sig2, Add(l, r2));
        (c2, h2, sig2, Add(l, r2))
      ) else (
        assert g == TypeCheckE(TypeSigma(sig), V(Num(l.val.nval + r.val.nval)));
        assert HeapDeclarationsE(c, h, sig, V(Num(l.val.nval + r.val.nval)));
        (c, h, sig, V(Num(l.val.nval + r.val.nval)))
      )

    case GT(l, r) =>
      if !l.V? then (
        assert TypeCheckE(TypeSigma(sig), l).Type?;
        var (c2, h2, sig2, l2) := EvalE(c, h, sig, l);
        assert g == TypeCheckE(TypeSigma(sig2), GT(l2, r));
        assert HeapDeclarationsE(c2, h2, sig2, GT(l2, r));
        (c2, h2, sig2, GT(l2, r))
      ) else if !r.V? then (
        var (c2, h2, sig2, r2) := EvalE(c, h, sig, r);
        assert g == TypeCheckE(TypeSigma(sig2), GT(l, r2));
        assert HeapDeclarationsE(c2, h2, sig2, GT(l, r2));
        (c2, h2, sig2, GT(l, r2))
      ) else (
        assert g == TypeCheckE(TypeSigma(sig), V(Bool(l.val.nval > r.val.nval)));
        assert HeapDeclarationsE(c, h, sig, V(Bool(l.val.nval > r.val.nval)));
        (c, h, sig, V(Bool(l.val.nval > r.val.nval)))
      )

    case Eq(l, r) =>
      if !l.V? then (
        var (c2, h2, sig2, l2) := EvalE(c, h, sig, l);
        assert g == TypeCheckE(TypeSigma(sig2), Eq(l2, r));
        assert HeapDeclarationsE(c2, h2, sig2, Eq(l2, r));
        (c2, h2, sig2, Eq(l2, r))
      ) else if !r.V? then (
        var (c2, h2, sig2, r2) := EvalE(c, h, sig, r);
        assert g == TypeCheckE(TypeSigma(sig2), Eq(l, r2));
        assert HeapDeclarationsE(c2, h2, sig2, Eq(l, r2));
        (c2, h2, sig2, Eq(l, r2))
      ) else if l.val.Num? && r.val.Num? then (
        assert g == TypeCheckE(TypeSigma(sig), V(Bool(l.val.nval == r.val.nval)));
        assert HeapDeclarationsE(c, h, sig, V(Bool(l.val.nval == r.val.nval)));
        (c, h, sig, V(Bool(l.val.nval == r.val.nval)))
      ) else (
        assert g == TypeCheckE(TypeSigma(sig), V(Bool(l.val.bval == r.val.bval)));
        assert HeapDeclarationsE(c, h, sig, V(Bool(l.val.bval == r.val.bval)));
        (c, h, sig, V(Bool(l.val.bval == r.val.bval)))
      )

  }
}

predicate HeapDeclarationsS(c: Channels, h: Heap, sig: Sigma, s: Stmt) {
  forall x :: x in LocsCh(c) + LocsH(h) + LocsSig(sig) + LocsS(s) ==> x in h
}

predicate IfConversion1(g: Gamma, x: string, the: Stmt, els: Stmt)
requires x !in ScopedVars(the);
requires x in GammaWithoutMovedS(g, If(V(Bool(true)), the, els));
ensures x in GammaWithoutMovedS(
          GammaUnion(GammaWithoutMovedS(g, the), ScopedVars(the)),
          CleanUp(g, els, the))
{
  var stmt := If(V(Bool(true)), the, els);
  assert x in g;
  assert !(x in ConsumedVarsS(stmt, 0));
  assert x !in ConsumedVarsS(the, 1) + ConsumedVarsS(els, 1);
  assert x !in ConsumedVarsS(the, 1);
  assert x !in ConsumedVarsS(the, 0);
  assert x !in ConsumedVarsS(els, 1);
  assert x !in ConsumedVarsS(els, 0);

  if MoveType(g[x]) then (
    assert x !in ReferencedVarsS(stmt);
    assert x !in ReferencedVarsSDec(stmt, 0);
    assert x !in ReferencedVarsE(V(Bool(true))) + ReferencedVarsS(the) + ReferencedVarsS(els);
    assert x !in ReferencedVarsS(the) + ReferencedVarsS(els);
    assert x !in ReferencedVarsS(the);
    assert x !in ReferencedVarsS(els);
    assert x !in ReferencedVarsS(CleanUp(g, els, the));
    assert x !in (ReferencedVarsS(els) - ReferencedVarsS(the));
    assert x !in ConsumedVarsS(CleanUp(g, els, the), 0);

    assert x in GammaWithoutMovedS(g, the);
    assert x in GammaUnion(GammaWithoutMovedS(g, the), ScopedVars(the));
    true
  ) else (
    assert x !in ConsumedVarsS(CleanUp(g, els, the), 0);
    assert x in GammaWithoutMovedS(g, the);
    assert x in GammaUnion(GammaWithoutMovedS(g, the), ScopedVars(the));
    true
  )
}

predicate IfConversion2(g: Gamma, x: string, the: Stmt, els: Stmt)
requires x in GammaWithoutMovedS(
          GammaUnion(GammaWithoutMovedS(g, the), ScopedVars(the)),
          CleanUp(g, els, the))
ensures x in GammaWithoutMovedS(g, If(V(Bool(true)), the, els));
{
  var stmt := If(V(Bool(true)), the, els);
  assert x !in ConsumedVarsS(CleanUp(g, els, the), 0);

  assert ConsumedVarsS(CleanUp(g, els, the), 0) ==
      (set x | x in ScopedVars(the)) + (set x | x in ReferencedVarsS(els) && x in g && MoveType(g[x]))
                                     + ConsumedVarsS(els, 1);
  assert x !in (set x | x in ScopedVars(the))
             + (set x | x in ReferencedVarsS(els) && x in g && MoveType(g[x]))
             + ConsumedVarsS(els, 1);
  assert x !in (set x | x in ScopedVars(the));
  assert x !in ScopedVars(the);

  assert x in GammaWithoutMovedS(g, the);

  assert x !in ConsumedVarsS(els, 0);

  assert x in GammaUnion(GammaWithoutMovedS(g, the), ScopedVars(the));
  assert x in GammaWithoutMovedS(g, the);
  assert x !in ConsumedVarsS(the, 0);
  assert x !in ConsumedVarsS(the, 0) + ConsumedVarsS(els, 0);
  assert x !in ConsumedVarsS(stmt, 0);
  assert x in g;

  if MoveType(g[x]) then (
    assert x !in ReferencedVarsSDec(the, 0);
    assert x !in ReferencedVarsSDec(CleanUp(g, els, the), 0);
    assert x !in ReferencedVarsS(the);
    assert x !in ReferencedVarsS(els);
    assert x !in ReferencedVarsS(the) + ReferencedVarsS(els);
    assert x !in ReferencedVarsS(stmt);
    assert x in GammaWithoutMovedS(g, stmt);
    true
  ) else (
    assert x !in ConsumedVarsS(els, 0);
    assert !(x in ConsumedVarsS(stmt, 0));
    assert x in GammaWithoutMovedS(g, stmt);
    true
  )
}

predicate IfConversionE1(g: Gamma, x: string, the: Stmt, els: Stmt)
requires x !in ScopedVars(els);
requires x in GammaWithoutMovedS(g, If(V(Bool(false)), the, els));
ensures x in GammaWithoutMovedS(
          GammaUnion(GammaWithoutMovedS(g, els), ScopedVars(els)),
          CleanUp(g, the, els))
{
  var stmt := If(V(Bool(false)), the, els);
  assert x in g;
  assert !(x in ConsumedVarsS(stmt, 0));
  assert x !in ConsumedVarsS(the, 1) + ConsumedVarsS(els, 1);
  assert x !in ConsumedVarsS(the, 1);
  assert x !in ConsumedVarsS(the, 0);
  assert x !in ConsumedVarsS(els, 1);
  assert x !in ConsumedVarsS(els, 0);


  if MoveType(g[x]) then (
    assert x !in ReferencedVarsS(stmt);
    assert ReferencedVarsS(stmt) == ReferencedVarsE(V(Bool(false))) + ReferencedVarsS(the) + ReferencedVarsS(els);
    assert x !in ReferencedVarsE(V(Bool(false))) + ReferencedVarsS(the) + ReferencedVarsS(els);
    assert x !in ReferencedVarsS(the);
    assert x !in ReferencedVarsS(els);
    assert x !in ReferencedVarsS(CleanUp(g, the, els));
    assert x !in ReferencedVarsS(els);
    assert x !in ConsumedVarsS(CleanUp(g, the, els), 0);

    assert x in GammaWithoutMovedS(g, els);
    assert x in GammaUnion(GammaWithoutMovedS(g, els), ScopedVars(els));
    true
  ) else (
    assert x !in ConsumedVarsS(CleanUp(g, the, els), 0);
    assert x in GammaWithoutMovedS(g, els);
    assert x in GammaUnion(GammaWithoutMovedS(g, els), ScopedVars(els));
    true
  )
}

predicate IfConversionE2(g: Gamma, x: string, the: Stmt, els: Stmt)
requires x in GammaWithoutMovedS(
          GammaUnion(GammaWithoutMovedS(g, els), ScopedVars(els)),
          CleanUp(g, the, els))
ensures x in GammaWithoutMovedS(g, If(V(Bool(false)), the, els));
{
  var stmt := If(V(Bool(false)), the, els);
  assert x !in ConsumedVarsS(CleanUp(g, the, els), 0);

  assert  ConsumedVarsS(CleanUp(g, the, els), 0) ==
      (set x | x in ScopedVars(els)) + (set x | x in ReferencedVarsS(the) && x in g && MoveType(g[x]))
                                     + ConsumedVarsS(the, 1);
  assert x !in (set x | x in ScopedVars(els))
             + (set x | x in ReferencedVarsS(the) && x in g && MoveType(g[x]))
             + ConsumedVarsS(the, 1);
  assert x !in (set x | x in ScopedVars(els));
  assert x !in ScopedVars(els);
  assert x !in ConsumedVarsS(the, 0);

  assert x in GammaUnion(GammaWithoutMovedS(g, els), ScopedVars(els));
  assert x in GammaWithoutMovedS(g, els);
  assert x !in ConsumedVarsS(els, 0);
  assert x !in ConsumedVarsS(stmt, 0);
  assert x in g;

  if MoveType(g[x]) then (
    assert x !in ReferencedVarsSDec(CleanUp(g, the, els), 0);
    assert x !in ReferencedVarsS(CleanUp(g, the, els));
    assert x !in ReferencedVarsE(V(Bool(false)));
    assert x !in ReferencedVarsS(the);
    assert x !in ReferencedVarsS(els);
    assert x !in ReferencedVarsE(V(Bool(false))) + ReferencedVarsS(the) + ReferencedVarsS(els);
    assert x !in ReferencedVarsS(stmt);
    assert x in GammaWithoutMovedS(g, stmt);
    true
  ) else (
    assert x !in ConsumedVarsS(the, 0);
    assert !(x in ConsumedVarsS(stmt, 0));
    assert x in GammaWithoutMovedS(g, stmt);
    true
  )
}

predicate LocsWhile(cond: Expr, body: Stmt, x: Loc)
requires x in LocsS(If(cond, Seq(If(V(Bool(true)), body, Skip), While(cond, body)), Skip));
ensures x in LocsS(While(cond, body));
{
  assert x in LocsS(If(cond, Seq(If(V(Bool(true)), body, Skip), While(cond, body)), Skip));
  assert x in LocsE(cond) + LocsS(Seq(If(V(Bool(true)), body, Skip), While(cond, body))) + LocsS(Skip);
  if x in LocsE(cond) then (
    assert x in LocsE(cond) + LocsS(body);
    assert x in LocsS(While(cond, body));
    true
  ) else (
    assert x in LocsS(Seq(If(V(Bool(true)), body, Skip), While(cond, body)));
    assert x in LocsS(If(V(Bool(true)), body, Skip)) + LocsS(While(cond, body));
    if x in LocsS(If(V(Bool(true)), body, Skip)) then (
      assert x in LocsE(V(Bool(true))) + LocsS(body) + LocsS(Skip);
      assert x in LocsS(body);
      assert x in LocsE(cond) + LocsS(body);
      assert x in LocsS(While(cond, body));
      true
    ) else (
      true
    )
  )
}

function method EvalS(c: Channels, h: Heap, sig: Sigma, stmt: Stmt): (Channels, Heap, Sigma, Stmt, Option<Stmt>)
decreases stmt;
requires !stmt.Skip?;
requires TypeCheckS(TypeSigma(sig), stmt).Some?;
requires HeapWellDefined(h);
requires HeapDeclarationsS(c, h, sig, stmt);
ensures HeapWellDefined(EvalS(c, h, sig, stmt).1);
ensures HeapDeclarationsS(EvalS(c, h, sig, stmt).0, EvalS(c, h, sig, stmt).1, EvalS(c, h, sig, stmt).2, EvalS(c, h, sig, stmt).3);
ensures forall l :: l in h ==> l in EvalS(c, h, sig, stmt).1;
ensures forall x :: x in EvalS(c, h, sig, stmt).2 ==> x in sig || x in DeclaredVars(stmt);
ensures forall x :: x in DeclaredVars(EvalS(c, h, sig, stmt).3) ==> x in DeclaredVars(stmt);
ensures TypeCheckS(TypeSigma(sig), stmt) ==
        TypeCheckS(TypeSigma(EvalS(c, h, sig, stmt).2), EvalS(c, h, sig, stmt).3);
ensures EvalS(c, h, sig, stmt).4.Some? ==>
        TypeCheckS(TypeSigma(sig), EvalS(c, h, sig, stmt).4.val).Some? &&
        HeapDeclarationsS(c, h, sig, EvalS(c, h, sig, stmt).4.val) &&
        !EvalS(c, h, sig, stmt).4.val.Skip?;
{
  ghost var g := TypeCheckS(TypeSigma(sig), stmt).val;

  match stmt {

    case VarDecl(x, vt, vinit) =>
      if !vinit.V? then (
        var (c2, h2, sig2, vinit2) := EvalE(c, h, sig, vinit);
        ghost var vet := TypeCheckE(TypeSigma(sig2), vinit2);
        assert vet.Type?;
        assert vet.typ == TypeCheckE(TypeSigma(sig), vinit).typ;
        assert vet.gamma == TypeCheckE(TypeSigma(sig), vinit).gamma;

        assert vt == vet.typ;
        assert stmt.x !in TypeSigma(sig);
        assert stmt.x !in TypeSigma(sig2);

        ghost var g2 := TypeCheckS(TypeSigma(sig2), VarDecl(x, vt, vinit2));
        assert g2.Some?;
        assert g == g2.val;
        assert forall x :: x in sig2 ==> x in sig || x in DeclaredVars(stmt);
        assert HeapDeclarationsS(c2, h2, sig2, VarDecl(x, vt, vinit2));
        (c2, h2, sig2, VarDecl(x, vt, vinit2), None)
      ) else (
        ghost var g2 := TypeCheckS(TypeSigma(sig[x := vinit.val]), Skip);
        assert g2.Some?;
        assert g == g2.val;
        assert forall z :: z in sig[x := vinit.val] ==> z in sig || z in DeclaredVars(stmt);
        assert HeapDeclarationsS(c, h, sig[x := vinit.val], Skip);
        (c, h, sig[x := vinit.val], Skip, None)
      )

    case Assign(y, expr) =>
      if !expr.V? then (
        var (c2, h2, sig2, expr2) := EvalE(c, h, sig, expr);
        ghost var vet := TypeCheckE(TypeSigma(sig2), expr2);
        assert vet.Type?;
        assert vet.typ == TypeCheckE(TypeSigma(sig), expr).typ;
        assert vet.gamma == TypeCheckE(TypeSigma(sig), expr).gamma;
        assert stmt.y in TypeSigma(sig);
        assert TypeSigma(sig)[y] == vet.typ;
        assert TypeSigma(sig2)[y] == vet.typ;
        ghost var g2 := TypeCheckS(TypeSigma(sig2), Assign(y, expr2));
        assert g2.Some?;
        assert g == g2.val;
        assert forall x :: x in sig2 ==> x in sig || x in DeclaredVars(stmt);
        assert HeapDeclarationsS(c2, h2, sig2, Assign(y, expr2));
        (c2, h2, sig2, Assign(y, expr2), None)
      ) else (
        ghost var g2 := TypeCheckS(TypeSigma(sig[y := expr.val]), Skip);
        assert g2.Some?;
        assert g == g2.val;
        assert forall z :: z in sig[y := expr.val] ==> z in sig || z in DeclaredVars(stmt);
        assert HeapDeclarationsS(c, h, sig, stmt);
        assert forall l :: l in LocsCh(c) ==> l in h;
        assert forall l :: l in LocsH(h) ==> l in h;
        assert forall l :: l in LocsE(expr) ==> l in h;
        assert forall l :: l in LocsS(Skip) ==> l in h;
        assert forall l :: l in LocsSig(sig) ==> l in h;
        assert forall l :: l in LocsSig(sig[y := expr.val]) ==> l in h;
        assert HeapDeclarationsS(c, h, sig[y := expr.val], Skip);
        (c, h, sig[y := expr.val], Skip, None)
      )

    case RefAssign(z, expr) =>
      if !expr.V? then (
        var (c2, h2, sig2, expr2) := EvalE(c, h, sig, expr);
        ghost var vet := TypeCheckE(TypeSigma(sig2), expr2);
        assert vet.Type?;
        assert vet.typ == TypeCheckE(TypeSigma(sig), expr).typ;
        assert vet.gamma == TypeCheckE(TypeSigma(sig), expr).gamma;
        assert stmt.z in TypeSigma(sig);
        assert TypeSigma(sig)[z].RefT? && TypeSigma(sig)[z].t == vet.typ;
        assert TypeSigma(sig2)[z].RefT? && TypeSigma(sig2)[z].t == vet.typ;
        ghost var g2 := TypeCheckS(TypeSigma(sig2), RefAssign(z, expr2));
        assert g2.Some?;
        assert g == g2.val;
        assert forall x :: x in sig2 ==> x in sig || x in DeclaredVars(stmt);
        assert HeapDeclarationsS(c2, h2, sig2, RefAssign(z, expr2));
        (c2, h2, sig2, RefAssign(z, expr2), None)
      ) else (
        ghost var g2 := TypeCheckS(TypeSigma(sig), Skip);
        assert g2.Some?;
        assert g == g2.val;
        assert forall x :: x in sig ==> x in sig || x in DeclaredVars(stmt);
        assert HeapDeclarationsS(c, h, sig, stmt);
        assert forall l :: l in LocsCh(c) ==> l in h;
        assert forall l :: l in LocsH(h) ==> l in h;
        assert forall l :: l in LocsE(expr) ==> l in h;
        assert forall l :: l in LocsSig(sig) ==> l in h;
        assert LocsS(Skip) == {};
        assert forall l :: l in LocsS(Skip) ==> l in h;
        assert z in sig;
        assert sig[z].Ref?;
        var l: Loc := sig[z].l;
        assert l in h;
        assert forall l :: l in h ==> l in h[l := expr.val];
        assert forall l :: l in LocsH(h[l := expr.val]) ==> l in h;
        assert forall l :: l in LocsCh(c) + LocsH(h[l := expr.val]) + LocsSig(sig) + LocsS(Skip)
               ==> l in h ==> l in h[l := expr.val];
        assert HeapDeclarationsS(c, h[l := expr.val], sig, Skip);
        (c, h[l := expr.val], sig, Skip, None)
      )

    case Send(ch, expr) =>
      if !ch.V? then (
        var (c2, h2, sig2, ch2) := EvalE(c, h, sig, ch);
        ghost var g2 := TypeCheckS(TypeSigma(sig2), Send(ch2, expr));
        assert g2.Some?;
        assert g == g2.val;
        assert HeapDeclarationsS(c2, h2, sig2, Send(ch2, expr));
        (c2, h2, sig2, Send(ch2, expr), None)
      ) else if !expr.V? then (
        var (c2, h2, sig2, expr2) := EvalE(c, h, sig, expr);
        ghost var g2 := TypeCheckS(TypeSigma(sig2), Send(ch, expr2));
        assert g2.Some?;
        assert g == g2.val;
        assert HeapDeclarationsS(c2, h2, sig2, Send(ch, expr2));
        (c2, h2, sig2, Send(ch, expr2), None)
      ) else (
        ghost var g2 := TypeCheckS(TypeSigma(sig), Skip);
        assert g2.Some?;
        assert g == g2.val;
        assert ch.V?;
        assert ch.val.Num?;
        assert expr.V?;
        var cc := if ch.val.nval in c then c[ch.val.nval] else [];
        var c2: Channels := c[ch.val.nval := cc + [expr.val]];
        assert HeapDeclarationsS(c2, h, sig, Skip);
        (c2, h, sig, Skip, None)
      )

    case If(cond, the, els) =>
      if !cond.V? then (
        var (c2, h2, sig2, cond2) := EvalE(c, h, sig, cond);
        ghost var g2 := TypeCheckS(TypeSigma(sig2), If(cond2, the, els));
        assert g2.Some?;
        assert g == g2.val;
        assert forall x :: x in sig2 ==> x in sig || x in DeclaredVars(stmt);
        assert HeapDeclarationsS(c2, h2, sig2, If(cond2, the, els));
        (c2, h2, sig2, If(cond2, the, els), None)
      ) else if cond.val.bval then (
        ghost var gs := TypeSigma(sig);
        assert g == GammaWithoutMovedS(gs, If(V(Bool(true)), the, els));
        ghost var g2 := TypeCheckS(gs, Seq(the, CleanUp(gs, els, the)));

        assert TypeCheckE(gs, cond).Type?;
        assert TypeCheckE(gs, cond).gamma == gs;
        assert TypeCheckS(gs, the).Some?;
        ghost var g3 := TypeCheckS(gs, the).val;
        assert TypeCheckS(g3, CleanUp(gs, els, the)).Some?;
        assert g2 == TypeCheckS(g3, CleanUp(gs, els, the));
        assert g2.Some?;
        assert g2.val == GammaWithoutMovedS(
          GammaUnion(GammaWithoutMovedS(gs, the), ScopedVars(the)),
          CleanUp(gs, els, the));

        assert g !! ScopedVars(the);
        assert forall x :: x in g ==> IfConversion1(gs, x, the, els) && x in g2.val;
        assert forall x :: x in g2.val ==> IfConversion2(gs, x, the, els) && x in g;

        assert g == g2.val;
        assert HeapDeclarationsS(c, h, sig, Seq(the, CleanUp(TypeSigma(sig), els, the)));
        (c, h, sig, Seq(the, CleanUp(TypeSigma(sig), els, the)), None)

      ) else (
        ghost var gs := TypeSigma(sig);
        assert g == GammaWithoutMovedS(gs, If(V(Bool(false)), the, els));
        ghost var g2 := TypeCheckS(gs, Seq(els, CleanUp(gs, the, els)));

        assert TypeCheckE(gs, cond).Type?;
        assert TypeCheckE(gs, cond).gamma == gs;
        assert TypeCheckS(gs, els).Some?;
        ghost var g3 := TypeCheckS(gs, els).val;
        assert TypeCheckS(g3, CleanUp(gs, the, els)).Some?;
        assert g2 == TypeCheckS(g3, CleanUp(gs, the, els));
        assert g2.Some?;
        assert g2.val == GammaWithoutMovedS(
          GammaUnion(GammaWithoutMovedS(gs, els), ScopedVars(els)),
          CleanUp(gs, the, els));

        assert g !! ScopedVars(els);
        assert forall x :: x in g ==> IfConversionE1(gs, x, the, els) && x in g2.val;
        assert forall x :: x in g2.val ==> IfConversionE2(gs, x, the, els) && x in g;

        assert g == g2.val;
        assert HeapDeclarationsS(c, h, sig, Seq(els, CleanUp(TypeSigma(sig), the, els)));
        (c, h, sig, Seq(els, CleanUp(TypeSigma(sig), the, els)), None)
      )

    case While(cond, body) => (
      ghost var gs := TypeSigma(sig);
      assert TypeCheckE(gs, cond).Type?;
      assert TypeCheckE(gs, cond).typ == BoolT;
      ghost var g2 := TypeCheckE(gs, cond).gamma;
      assert g2 == GammaWithoutMovedE(gs, cond);
      // can type check cond

      assert TypeCheckE(g2, V(Bool(true))).Type?;
      assert TypeCheckE(g2, V(Bool(true))).typ == BoolT;
      assert TypeCheckE(g2, V(Bool(true))).gamma == g2;
      // can type check V(Bool(true))

      assert TypeCheckS(g2, body).Some?;
      // can type check body

      assert TypeCheckS(g2, Skip).Some?;
      assert TypeCheckS(g2, Skip).val == g2;
      assert TypeCheckS(g2, If(V(Bool(true)), body, Skip)).Some?;
      ghost var g3 := TypeCheckS(g2, If(V(Bool(true)), body, Skip)).val;
      assert g3 == GammaWithoutMovedS(g2, body);
      // can type check    If(V(Bool(true)), body, Skip)

      assert TypeCheckS(gs, While(cond, body)).Some?;
      assert g == GammaWithoutMovedS(g, stmt);

      assert g3 ==
        GammaJoin(GammaWithoutMovedE(g, stmt.wcond),
                  GammaWithoutMovedS(GammaWithoutMovedE(g, stmt.wcond), stmt.wbody));



      assert TypeCheckS(g2, stmt.wbody).val ==
        GammaUnion(GammaWithoutMovedS(g, stmt), ScopedVars(body));
      assert gs == g3;

      assert TypeCheckS(g3, While(cond, body)).Some?;
      assert TypeCheckS(g3, While(cond, body)).val == g3;

      // can type check   While(cond, body)

      assert DeclaredVars(If(V(Bool(true)), body, Skip)) !! DeclaredVars(While(cond, body));
      assert g !! DeclaredVars(While(cond, body));
      assert TypeCheckS(g2, Seq(If(V(Bool(true)), body, Skip),
                                While(cond, body))).Some?;

      // can typo check the
      // can type check else
      // can type check if

      ghost var g4 := TypeCheckS(gs, If(cond,
               Seq(If(V(Bool(true)), body, Skip),
                   While(cond, body)), Skip));

      assert g4.Some?;
      assert g == g4.val;
      assert DeclaredVars(stmt) == DeclaredVars(body);
      assert DeclaredVars(body) == DeclaredVars(If(V(Bool(true)), body, Skip));
      assert DeclaredVars(stmt) == DeclaredVars(If(cond,
               Seq(If(V(Bool(true)), body, Skip),
                   While(cond, body)),
               Skip));
      assert HeapDeclarationsS(c, h, sig, While(cond, body));
      assert forall x :: x in LocsCh(c) ==> x in h;
      assert forall x :: x in LocsH(h) + LocsSig(sig) + LocsS(While(cond, body)) ==> x in h;
      assert forall x :: x in LocsH(h) ==> x in h;
      assert forall x :: x in LocsSig(sig) ==> x in h;
      assert forall x :: x in LocsS(While(cond, body)) ==> x in h;
      assert forall x :: x in LocsS(If(cond, Seq(If(V(Bool(true)), body, Skip), While(cond, body)), Skip)) ==> LocsWhile(cond, body, x) && x in LocsS(While(cond, body)) && x in h;
      assert forall x :: x in LocsCh(c) + LocsH(h) + LocsSig(sig) + LocsS(If(cond, Seq(If(V(Bool(true)), body, Skip), While(cond, body)), Skip)) ==> x in h;
      assert HeapDeclarationsS(c, h, sig, If(cond,
               Seq(If(V(Bool(true)), body, Skip),
                   While(cond, body)),
               Skip));
      (c, h, sig, If(cond,
               Seq(If(V(Bool(true)), body, Skip),
                   While(cond, body)),
               Skip), None)
    )

    case CleanUp(gs, refs, decls) => (
      ghost var g2 := TypeCheckS(TypeSigma(SigmaWithoutMovedS(sig, stmt)), Skip);
      assert g2.Some?;
      assert g == g2.val;
      assert forall x :: x in SigmaWithoutMovedS(sig, stmt) ==> x in sig || x in DeclaredVars(stmt);
      assert HeapDeclarationsS(c, h, SigmaWithoutMovedS(sig, stmt), Skip);
      (c, h, SigmaWithoutMovedS(sig, stmt), Skip, None)
    )

    case Fork(s) =>
      if s.Skip? then (
        ghost var g2 := TypeCheckS(TypeSigma(sig), Skip);
        assert g2.Some?;
        assert g == g2.val;
        (c, h, sig, Skip, None)
      ) else (
        ghost var g2 := TypeCheckS(TypeSigma(SigmaWithoutMovedS(sig, stmt)), Skip);
        assert g2.Some?;
        assert g2.val == TypeSigma(SigmaWithoutMovedS(sig, stmt));
        assert g2.val == GammaWithoutMovedS(TypeSigma(sig), stmt);
        assert g == g2.val;
        assert HeapDeclarationsS(c, h, sig, Fork(s));
        assert forall l :: l in LocsS(Fork(s)) ==> l in h;
        assert LocsS(Fork(s)) == LocsS(s);
        assert forall l :: l in LocsS(s) ==> l in h;
        assert HeapDeclarationsS(c, h, sig, s);
        (c, h, SigmaWithoutMovedS(sig, stmt), Skip, Some(s))
      )

    case Seq(s1, s2) =>
      if s1.Skip? then (
        ghost var g2 := TypeCheckS(TypeSigma(sig), s2);
        assert g2.Some?;
        assert HeapDeclarationsS(c, h, sig, s2);
        (c, h, sig, s2, None)
      ) else (
        var (c2, h2, sig2, s12, spawn) := EvalS(c, h, sig, s1);
        assert TypeCheckS(TypeSigma(sig), s1).Some?;
        ghost var g2 := TypeCheckS(TypeSigma(sig), s1).val;
        assert TypeCheckS(g2, s2).Some?;

        assert TypeCheckS(TypeSigma(sig2), s12).Some?;
        ghost var g3 := TypeCheckS(TypeSigma(sig2), s12).val;
        assert GammaExtends(g2, g3);
        assert TypeSigma(sig) !! DeclaredVars(s2);
        assert TypeSigma(sig2) !! DeclaredVars(s2);
        assert DeclaredVars(s12) !! DeclaredVars(s2);

        ghost var g4 := TypeCheckS(TypeSigma(sig2), Seq(s12, s2));
        assert g4.Some?;
        assert g == g4.val;
        assert forall x :: x in sig2 ==> x in sig || x in DeclaredVars(stmt);
        assert HeapDeclarationsS(c2, h2, sig2, Seq(s12, s2));
        (c2, h2, sig2, Seq(s12, s2), spawn)
      )

  }
}

type Thread = (Sigma, Stmt)
type Threads = seq<Thread>

predicate HeapDeclarationsP(c: Channels, h: Heap, threads: Threads) {
  /* var slocs := (set t, l | t in threads && l in LocsSig(t.0) :: l); */
  /* var tlocs := (set t, l | t in threads && l in LocsS(t.1) :: l); */
  /* forall l :: l in LocsCh(c) + LocsH(h) + slocs + tlocs ==> l in h */
  forall t :: t in threads ==> HeapDeclarationsS(c, h, t.0, t.1)
}

function method EvalP(c: Channels, h: Heap, threads: Threads): (Channels, Heap, Threads)
requires threads != [];
requires forall t :: t in threads ==> !t.1.Skip?;
requires forall t :: t in threads ==> TypeCheckS(TypeSigma(t.0), t.1).Some?;
requires HeapWellDefined(h);
requires HeapDeclarationsP(c, h, threads);
ensures HeapWellDefined(EvalP(c, h, threads).1);
ensures HeapDeclarationsP(EvalP(c, h, threads).0, EvalP(c, h, threads).1, EvalP(c, h, threads).2);
ensures forall l :: l in h ==> l in EvalP(c, h, threads).1;
ensures forall t :: t in EvalP(c, h, threads).2 ==> TypeCheckS(TypeSigma(t.0), t.1).Some?;
ensures forall t :: t in EvalP(c, h, threads).2 ==> !t.1.Skip?;
{
  var t := threads[0];
  var others := threads[1..];
  var step := EvalS(c, h, t.0, t.1);
  var newT := if step.3.Skip? then [] else [(step.2, step.3)];
  var spawnT := if step.4.None? then [] else [(t.0, step.4.val)];
  assert HeapDeclarationsS(step.0, step.1, step.2, step.3);
  assert step.4.Some? ==> HeapDeclarationsS(step.0, step.1, step.2, step.4.val);
  (step.0, step.1, others + newT + spawnT)
}

// --------- No Data Races ---------

lemma WriteReq(g: Gamma, s: Stmt, x: string)
decreases s;
requires x in UpdatedVarsS(s);
requires TypeCheckS(g, s).Some?;
ensures x in g;
ensures g[x].RefT?;
{
  assert !s.VarDecl?;
  assert !s.Assign?;
  assert !s.Send?;
  assert !s.CleanUp?;
  assert !s.Skip?;
  match s {
    case RefAssign(z, expr) => {
      assert x == z;
      assert x in TypeCheckE(g, expr).gamma;
      assert TypeCheckE(g, expr).gamma[x].RefT?;
      assert x in g;
      assert g[x].RefT?;
    }
    case If(con, the, els) => {
      if x in UpdatedVarsS(the) {
        WriteReq(TypeCheckE(g, con).gamma, the, x);
      } else {
        WriteReq(TypeCheckE(g, con).gamma, els, x);
      }
      assert x in g;
      assert g[x].RefT?;
    }
    case While(con, body) => {
      WriteReq(TypeCheckE(g, con).gamma, body, x);
      assert x in g;
      assert g[x].RefT?;
    }
    case Seq(s1, s2) => {
      if x in UpdatedVarsS(s1) {
        WriteReq(g, s1, x);
      } else {
        WriteReq(TypeCheckS(g, s1).val, s2, x);
      }
      assert x in g;
      assert g[x].RefT?;
    }
    case Fork(s) => {
      WriteReq(g, s, x);
      assert x in g;
      assert g[x].RefT?;
    }
  }
}

lemma WriteReqContra(g: Gamma, s: Stmt, x: string)
requires x !in g || !g[x].RefT?;
ensures x !in UpdatedVarsS(s) || !TypeCheckS(g, s).Some?;
{
  if x in UpdatedVarsS(s) && TypeCheckS(g, s).Some? {
    WriteReq(g, s, x);
    assert false;
  }
}

lemma NoReadWriteRaces(g: Gamma, s1: Stmt, s2: Stmt, x: string)
requires x in ReferencedVarsS(s1);
requires TypeCheckS(g, Seq(Fork(s1), s2)).Some?;
ensures x !in UpdatedVarsS(s2);
{
  assert TypeCheckS(g, Fork(s1)).Some?;
  assert TypeCheckS(g, s1).Some?;
  ghost var g2 := GammaWithoutMovedS(g, Fork(s1));
  assert g2 == TypeCheckS(g, Fork(s1)).val;
  assert TypeCheckS(g2, s2).Some?;
  assert x in g;
  assert x in ReferencedVarsS(s1);
  if g[x].RefT? {
    assert x !in g2;
    WriteReqContra(g2, s2, x);
    assert x !in UpdatedVarsS(s2);
  } else {
    WriteReqContra(g2, s2, x);
    assert x !in UpdatedVarsS(s2);
  }
}

lemma NoWriteReadRaces(g: Gamma, s1: Stmt, s2: Stmt, x: string)
requires x in UpdatedVarsS(s1);
requires TypeCheckS(g, Seq(Fork(s1), s2)).Some?;
ensures x !in ReferencedVarsS(s2);
{
  assert TypeCheckS(g, Fork(s1)).Some?;
  assert TypeCheckS(g, s1).Some?;
  ghost var g2 := GammaWithoutMovedS(g, Fork(s1));
  assert g2 == TypeCheckS(g, Fork(s1)).val;
  assert TypeCheckS(g2, s2).Some?;
  assert x in ConsumedVarsS(Fork(s1), 0);
  assert x !in g2;
}

lemma NoWriteWriteRaces(g: Gamma, s1: Stmt, s2: Stmt, x: string)
requires x in UpdatedVarsS(s1);
requires TypeCheckS(g, Seq(Fork(s1), s2)).Some?;
ensures x !in UpdatedVarsS(s2);
{
  assert TypeCheckS(g, Fork(s1)).Some?;
  assert TypeCheckS(g, s1).Some?;
  ghost var g2 := GammaWithoutMovedS(g, Fork(s1));
  assert g2 == TypeCheckS(g, Fork(s1)).val;
  assert TypeCheckS(g2, s2).Some?;
  assert x in ConsumedVarsS(Fork(s1), 0);
  assert x !in g2;
  WriteReqContra(g2, s2, x);
}

// --------- Testing ---------

method TestVars() {
  assert TypeCheckE(map[], Var("x")).Fail?;
  ghost var t1 := TypeCheckE(map["x" := BoolT], Var("x"));
  assert t1.Type?;
  assert t1.typ == BoolT;
  assert t1.gamma == map["x" := BoolT];
}

method TestAdd() {
  assert TypeCheckE(map[], Add(V(Num(12)), V(Bool(false)))).Fail?;
  ghost var t1 := TypeCheckE(map[], Add(V(Num(12)), V(Num(23))));
  assert t1.Type?;
  assert t1.typ == NumT;
}

method TestVarDecl() {
  assert TypeCheckS(map[], VarDecl("x", NumT, V(Bool(false)))).None?;
  ghost var t1 := TypeCheckS(map[], VarDecl("x", NumT, V(Num(12))));
  assert t1.Some?;
  assert t1.val == map["x" := NumT];
}

// --------- Running ---------

method Main() {
  var prog: Option<Stmt> := Parse();
  if prog.None? || prog.val.Skip? {
    print "Parse error!\n";
    return;
  }
  var t: Option<Gamma> := TypeCheckS(TypeSigma(map[]), prog.val);
  if t.None? {
    print "Type error!\n";
    return;
  }
  print "Type checking succesful.\nEvaluating...\n";
  var n:nat := 0;
  var c: Channels := map[];
  var h: Heap := map[];
  var threads: Threads := [(map[], prog.val)];
  while n < 100000 && threads != []
  invariant HeapWellDefined(h);
  invariant HeapDeclarationsP(c, h, threads);
  invariant forall t :: t in threads ==> TypeCheckS(TypeSigma(t.0), t.1).Some? && !t.1.Skip?;
  {
    var res := EvalP(c, h, threads);
    c := res.0;
    h := res.1;
    threads := res.2;
    n := n + 1;
  }
  print "Ran ";
  print n;
  print "\n\nFinal heap:\n";
  print h;
  print "\n\nFinal channels:\n";
  print c;
  print "\n";
}

