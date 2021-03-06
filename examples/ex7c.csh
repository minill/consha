// Example 3: Share reference via scope

var incr: Share[Num] = share(ref(0));

fork {
  var n: Num = 0;
  var res: Num = 0;
  while (3 > n) {
    res = res + receive(1, Num) + *(incr);
    n = n + 1;
  }
  send(2, res);
}

send(1, 4);
send(1, 24);
send(1, 1);

// write incr:
// *incr = 2;

var result: Ref[Num] = ref(receive(2, Num));
