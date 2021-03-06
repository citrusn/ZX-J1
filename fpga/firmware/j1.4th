(
   eForth 1.04 for j1 Simulator by Edward A., July 2014
   Much of the code is derived from the following sources:
      j1 Cross-compiler by James Bowman August 2010
     8086 eForth 1.0 by Bill Muench and C. H. Ting, 1990
)

(
  LINK -  => NFA pred word
  NFA - len even => tlast pointer 
  NFA return by  >name 
  ...
  CFA return by '
  PFA return by  >body
)

only forth definitions hex

( Create a new, empty word list represented by wid. )
wordlist constant meta.1
wordlist constant target.1
wordlist constant assembler.1

: (order) ( w wid*n n -- wid*n w n )
  dup if
    1- swap >r recurse over r@ xor if
      1+ r> -rot exit then r> drop 
  then ;
: -order ( wid -- )
  get-order (order) nip set-order ;
: +order ( wid -- )
  dup >r -order get-order r> swap 1+ set-order ;

: ]asm ( -- ) assembler.1 +order ; immediate

\ variable hd
\ s" head.txt" w/o create-file throw hd !
\ s" yjdsq afqk" hd @ write-line throw
\ 30 hd @ emit-file throw

( wid is the identifier of the current compilation word list. )
( Set the compilation word list to the word list identified by wid. )
get-current meta.1 set-current

: [a] ( "name" -- )
  parse-word assembler.1 search-wordlist 0=
   abort" [a]?" compile, ; immediate
: a: ( "name" -- )
  get-current >r  assembler.1 set-current
  : r> set-current ;

target.1 +order meta.1 +order

a: asm[ ( -- ) 
  assembler.1 -order ; immediate

create tflash 1000 cells ( 4) here over erase allot

variable tdp

: there tdp @ ;
: tc! tflash + c! ;
: tc@ tflash + c@ ;
: t! over ff and over tc! swap 8 rshift swap 1+ tc! ;
: t@ dup tc@ swap 1+ tc@ 8 lshift or ;
( выравнивание на 0 адрес - четный)
: talign there 1 and tdp +! ;  
: tc, there tc! 1 tdp +! ;
: t, there t! 2 tdp +! ;
: $literal [char] " word count dup tc, 0 ?do
	count tc, loop drop talign ;
: tallot tdp +! ;
: org dup ." org=" . tdp ! ;

a: t    0000 ;
a: n    0100 ;
a: t+n  0200 ;
a: t&n  0300 ;
a: t|n  0400 ;
a: t^n  0500 ;
a: ~t   0600 ;
a: n==t 0700 ;
a: n<t  0800 ;
a: n>>t 0900 ;
a: t-1  0a00 ;
a: rt   0b00 ;
a: [t]  0c00 ;
a: n<<t 0d00 ;
a: dsp  0e00 ;
a: nu<t 0f00 ;

a: t->n 0080 or ; ( copy T to N)
a: t->r 0040 or ; ( copy T to R)
a: n->[t] 0020 or ; ( RAM write)
a: d-1  0003 or ;
a: d+1  0001 or ;
a: r-1  000c or ;
a: r-2  0008 or ;
a: r+1  0004 or ;

a: alu  6000 or t, ;

a: return [a] t 1000 or [a] r-1 [a] alu ; ( copy R to the PC)
a: branch  2/ 0000 or t, ;
a: ?branch 2/ 2000 or t, ; ( jump if t=0 )
a: call    2/ 4000 or t, ;

a: literal
   dup 8000 and if
    ffff xor recurse
     [a] ~t [a] alu
   else
    8000 or t,
   then ;

variable tlast        ( point to the last name in the name dictionary
                      ( адрес NFA последнего слова в tflash )
variable tuser        ( содержит  адрес user области)

0001 constant =ver    ( номер версии)
0004 constant =ext    ( минорный номер версии)
0040 constant =comp   ( признак "только компиляция"  6 бит)
0080 constant =imed   ( признак немедленного исполнения 7 бит)
7f1f constant =mask   ( 0111_1111 0001_1111)
0002 constant =cell   ( 2 байта размер ячейки)
0010 constant =base   ( система исчисления)
0008 constant =bksp   ( backspace)
000a constant =lf     ( перевод строки )
000d constant =cr     ( возврат каретки)

4000 constant =em     ( верхний адрес памяти)
0000 constant =cold   ( cold start vector)

   8 constant =vocs    ( число словарей)
  80 constant =us      ( user area size in cells)

( Memory allocation)
( 0//code>--//--<name//up>--<sp//tib>--rp//em )
( 0//=cold--2//=uzero>--80//=pick>--180//=code> )
( --3E80//=up>--3F00//tib>--3FFF//=em)

=em 100 - constant =tib ( =3F00  terminal input buffer)
=tib =us - constant =up ( =3E80 start of user area )
=cold =us + constant =pick ( =80  )
=pick 100 + constant =code ( =180 code dictionary)

( список слов)
: thead
  talign
  tlast @ t, ( la) 
  there tlast ! ( na нового слова )
  \ s" " hd @ write-line
	parse-word dup  ( c-addr u u )
  tc, 0 ?do ( c-addr)
    count \ dup  hd @ emit-file
    tc, ( берем символ имени и пишем в tflash )
  loop drop talign ;

: twords ( вывод списка слов)
  cr tlast @ 
  begin
    dup tflash + count 1f and type space =cell - t@
  ?dup 0= until ;

: [t]
  parse-word target.1 search-wordlist 0=
    abort" [t]? not found"
  >body @ ; immediate
: [last] tlast @ ; immediate
: ( [char] ) parse 2drop ; immediate
: literal [a] literal ;
: lookback there =cell - t@ ; ( назад на 1 слово)
: call? ( пред слово - call ?)
  lookback e000 and 4000 = ; ( =call)
: call>goto ( ) 
  there =cell - dup t@ 
  1fff and 
  swap t! ;

: safe? ( предыд. команда=АЛУ  )
  lookback e000 and 6000 = ( =alu)
  lookback 004c and 0= and ( и не изменяется RS)  ;

( общая команда alu & return)
: alu>return 
    there =cell - dup t@ 1000 or ( пред слово + bit return)
    [a] r-1 swap t! ;
: t:
  >in @ ( создается заголовок в tflash )
  thead (  и входной поток откатывается назад)
  >in ! 
  get-current >r target.1 set-current 
  create ( в target.1 такое же слово )
	r> set-current 947947 ( вернули прежний список слов ) 
  talign there  ( в стек положили адрес cfa вновь созданного слова )
  , ( сохранили в словарь )
  does> 
  ( при вызове слова в коде на стеке будет cfa слова в target словаре  )
  ( который  компилируется в вызов слова на таргет машине )
  @ [a] call 
  ;
: exit
  call? if call>goto
        else safe? if alu>return 
                   else [a] return
  then then ;
: t;
  947947 <> if abort" unstructured" then 
  true if exit
       else [a] return then ;
: u:
  >in @ thead >in ! \ создать заголовок в tflash
  get-current >r target.1 set-current create \ 
  r> set-current  \ вернуть словарь
  talign 
  tuser @ \ адрес свободной ячейки
  dup , 
	[a] literal exit \ компилируем в tflash адрес ячейки и слово exit
  =cell tuser +! \ следующая свободная ячейка в tuser
  does> @ [a] literal ;
: [u] \ 
  parse-word target.1 search-wordlist 0=
  abort" [t]?" 
  >body @ \ адрес ячейки в tflash
   =up - =cell + ; immediate
: immediate    tlast @ tflash + dup c@ =imed or swap c! ; ( 7 бит =1)
: compile-only tlast @ tflash + dup c@ =comp or swap c! ; ( 6 бит =1)

      0 tlast !
    =up tuser !

: hex# ( u -- addr len )
  0 <# base @ >r hex =lf hold # # # # r> base ! #> ;

: save-hex ( <name> -- )
  parse-word w/o create-file throw
  there 0 do i t@  over >r hex# r> write-file throw 2 +loop
   close-file throw ;

: save-target ( <name> -- )
  parse-word w/o create-file throw >r
   tflash there r@ write-file throw r> close-file drop ;

: save-label ( <name> -- )
  parse-word w/o create-file throw >r
  cr tlast @ 
  begin
    dup dup hex# r@ write-file throw
    tflash + count 1f and r@ write-line throw =cell - t@
  ?dup 0= until 
  r> close-file ;
 
\ IF ( compiles ?branch and address after THEN ) <true clause> THEN
\ IF ( compiles ?branch and address after ELSE ) <true clause>
\   ELSE ( compiles branch and address after THEN ) <false clause>
\   THEN
\ BEGIN (marks current address ) <loop clause>
\   AGAIN ( compiles branch and address after BEGIN )
\ BEGIN ( mark current address ) <loop clause>
\   UNTIL ( compiles ?branch and address after BEGIN )
\ BEGIN ( mark current address ) <loop clause>
\   WHILE ( compiles ?branch and address after REPEAT ) <true clause>
\   REPEAT ( compile branch and address after BEGIN )
\ FOR ( set up loop, mark current address ) <loop clause>
\   NEXT ( compile next and address after FOR )
\ FOR ( set up loop, mark current address ) <loopclause>
\   AFT ( change marked address to current address,
\       compile branch and address after THEN ) <skip clause>
\   THEN <loop clause> NEXT ( compile next and address after AFT
\ AFT jumps to THEN in a FOR-AFT-THEN-NEXT loop the first time through.
\ It compiles a BRANCH address literal and leaves its address field on stack.
\ This address will be resolved by THEN. It also replaces address A left by FOR
\ by the address of next token so that NEXT will compile a DONEXT 
\ address literal to jump back here at run time.

( marks current address )
: begin  there ;
: until  [a] ?branch ;
: if     there 0 [a] ?branch ;
: skip   there 0 [a] branch ;
: then   begin 2/ over t@ or swap t! ;
: else   skip swap then ;
: while  if swap ;
: repeat [a] branch then ;
: again  [a] branch ;
: aft    drop skip begin swap ;

: noop  ]asm t alu asm[ ;
: +     ]asm t+n d-1 alu asm[ ;
: xor   ]asm t^n d-1 alu asm[ ;
: and   ]asm t&n d-1 alu asm[ ;
: or    ]asm t|n d-1 alu asm[ ;
: invert ]asm ~t alu asm[ ;
: =     ]asm n==t d-1 alu asm[ ;
: <     ]asm n<t d-1 alu asm[ ;
: u<    ]asm nu<t d-1 alu asm[ ;
: swap  ]asm n t->n alu asm[ ;
: dup   ]asm t t->n d+1 alu asm[ ;
: drop  ]asm n d-1 alu asm[ ;
: over  ]asm n t->n d+1 alu asm[ ;
: nip   ]asm t d-1 alu asm[ ;
: >r    ]asm n  t->r r+1 d-1 alu asm[ ;
: r>    ]asm rt t->n r-1 d+1 alu asm[ ;
: r@    ]asm rt t->n     d+1 alu asm[ ;
: @     ]asm [t] alu asm[ ; ( get from memory)
: !     ]asm  ( n t -- [t]=n put to memory)    
    ( Убрать t, n. t=n1-второе значение после n)
    t n->[t] d-1 alu  (    )
    n        d-1 alu asm[ ;
: dsp   ]asm dsp t->n d+1 alu asm[ ;
: lshift ]asm n<<t d-1 alu asm[ ;
: rshift ]asm n>>t d-1 alu asm[ ;
: 1-    ]asm t-1 alu asm[ ;
: 2r> 
  ]asm rt t->n r-1 d+1 alu ( r>)
       rt t->n r-1 d+1 alu ( r>)
        n t->n alu asm[ ; ( swap)
: 2>r
    ]asm
      n t->n alu ( swap)
      n t->r r+1 d-1 alu  ( >r)
      n t->r r+1 d-1 alu asm[ ; ( >r)
: 2r@
  ]asm
    rt t->n r-1 d+1 alu
    rt t->n r-1 d+1 alu
    n t->n d+1 alu
    n t->n d+1 alu
    n t->r r+1 d-1 alu
    n t->r r+1 d-1 alu
    n t->n alu asm[ ;
: unloop
    ]asm 
      t r-1 alu
      t r-1 alu asm[ ;

: dup@  ]asm [t] t->n d+1 alu asm[ ;
: dup>r ]asm t t->r r+1 alu asm[ ;
: 2dupxor ]asm t^n t->n d+1 alu asm[ ;
: 2dup= ]asm n==t t->n d+1 alu asm[ ;
: !nip  ]asm t n->[t] d-1 alu asm[ ;
: 2dup! ]asm t n->[t] alu asm[ ;

: up1   ]asm t d+1 alu asm[ ; ( =6001 t=t указатель данных+1 )
: down1 ]asm t d-1 alu asm[ ; ( =6003 t=t указатель данных-1)
: copy  ]asm n     alu asm[ ;  ( =6100 t=n )

a: down e for down1 next copy exit ; ( e=14)
a: up e for up1 next noop exit ;  ( цикл исполняется 15 раз)

: for ( counter -- thereF) ( RS: counter)
  >r begin ; 
: next ( thereF--) 
  r@ ( thereW thereF )   ( RS: counter)
  ( compiles ?branch after repeat)
  while ( thereF counter thereW )
  r> 1- >r  ( thereW thereF) ( RS: counter-1)
  ( compiles branch to thereF,  )
  repeat
  r> drop ; ( RS: empty)

=pick org ( =80 address)

    ]asm down up asm[
	
there constant =pickbody
  =pickbody ." pickbody=" .
	copy ]asm return asm[
	9c ]asm call asm[ bc ]asm branch asm[
	9a ]asm call asm[ ba ]asm branch asm[
	98 ]asm call asm[ b8 ]asm branch asm[
	96 ]asm call asm[ b6 ]asm branch asm[
	94 ]asm call asm[ b4 ]asm branch asm[
	92 ]asm call asm[ b2 ]asm branch asm[
	90 ]asm call asm[ b0 ]asm branch asm[
	8e ]asm call asm[ ae ]asm branch asm[
	8c ]asm call asm[ ac ]asm branch asm[
	8a ]asm call asm[ aa ]asm branch asm[
	88 ]asm call asm[ a8 ]asm branch asm[
	86 ]asm call asm[ a6 ]asm branch asm[
	84 ]asm call asm[ a4 ]asm branch asm[
	82 ]asm call asm[ a2 ]asm branch asm[
	80 ]asm call asm[ a0 ]asm branch asm[
	]asm return asm[

=cold org ( =0 )

0 t,

there constant =uzero ( =2 начало user области)
   =base t, ( base )
   0 t,     ( temp )
   0 t,     ( >in )
   0 t,     ( #tib )
   =tib t,  ( tib )
   0 t,     ( 'eval )
   0 t,     ( 'abort )
   0 t,     ( hld )

            ( context 8 словарей)

   0 t, 0 t, 0 t, 0 t, 0 t, 0 t, 0 t, 0 t, 0 t,

            ( forth-wordlist )

   0 t,     ( na, of last definition, linked )
   0 t,     ( wid|0, next or last wordlist in chain )
   0 t,     ( na, wordlist name pointer )

            ( current )

   0 t,     ( wid, new definitions )
   0 t,     ( wid, head of chain )

   0 t,     ( dp - free memory pointer )
   0 t,     ( last )
   0 t,     ( '?key )
   0 t,     ( 'emit )
   0 t,     ( 'boot )
   0 t,     ( '\ )
   0 t,     ( '?name )
   0 t,     ( '$,n )
   0 t,     ( 'overt )
   0 t,     ( '; )
   0 t,     ( 'create )
there dup ." ulast=" . constant =ulast 
( размер usr области )
=ulast =uzero - constant =udiff 
=code org ( =180)
( Слово в таргет словаре создается при исполнении кода )
t: noop noop t;
t: + + t;
t: xor xor t;
t: and and t;
t: or or t;
t: invert invert t;
t: = = t;
t: < < t;
t: u< u< t;
t: swap swap t;
t: u> swap u< t;
t: dup dup t;
t: drop drop t;
t: over over t;
t: nip nip t;
t: lshift lshift t;
t: rshift rshift t;
t: 1- 1- t;
t: >r r> swap >r >r t; compile-only
t: r> r> r> swap >r t; compile-only
t: r@ r> r> dup >r swap >r t; compile-only
t: @ ( a -- w ) @ t;
t: ! ( w a -- ) ! t;

t: <> = invert t;
t: 0< 0 literal < t;
t: 0= 0 literal = t;
t: > swap < t;
t: 0> 0 literal swap < t;
t: >= < invert t;
t: tuck swap over t;
t: -rot swap >r swap r> t;
t: 2/ 1 literal rshift t;
t: 2* 1 literal lshift t;
t: 1+ 1 literal + t;
t: sp@ dsp ff literal and t;
t: execute ( ca -- ) >r t;
t: bye ( -- ) f002 literal ! t;
t: c@ ( b -- c )
  dup @ swap 1 literal and if
   8 literal rshift else ff literal and then exit t;
t: c! ( c b -- )
  swap ff literal and dup 8 literal lshift or swap
   tuck dup @ swap 1 literal and 0 literal = ff literal xor
   >r over xor r> and xor swap ! t;
t: um+ ( w w -- w cy )
  over over + >r
   r@ 0 literal >= >r
    over over and
	 0< r> or >r
   or 0< r> and invert 1+
  r> swap t;

t: dovar ( -- a ) 
  \ при вызове в стеке возврата находится адрес 
  \ следующей ячейки, значение её это адрес,
  \ по которому лежит значение переменной 
  r> t; compile-only

t: up ( Pointer to the user area )
  \ при компиляции в словарь запишется значение константы =up,
  \ адрес, которой затем при исполнении в стек положит dovar  
  dovar =up t, t;

t: douser ( -- a ) 
  up @ r> @ + t; compile-only

( user variables)
u: base
u: temp
u: >in
u: #tib
u: tib
u: 'eval
u: 'abort
u: hld ( hold a pointer in building a numeric output string)
u: context ( 8 элементов словарей)
	=vocs =cell * tuser +!
u: forth-wordlist
  =cell tuser +!
	=cell tuser +!
u: current
	=cell tuser +!
u: dp
u: last
u: '?key
u: 'emit
u: 'boot
u: '\
u: 'name?
u: '$,n ( builds a new entry in the name dictionary)
u: 'overt ( links a new definition to the current vocabulary )
          ( and thus makes it available for dictionary searches)
u: ';
u: 'create
t: ?dup ( w -- w w | 0 ) dup if dup then exit t;
t: rot ( w1 w2 w3 -- w2 w3 w1 ) >r swap r> swap t;
t: 2dup ( w1 w2 -- w1 w2 w1 w2 )
  over over t;
t: 2swap ( w1 w2 w3 w4 – w3 w4 w1 w2)
  rot >r rot r> t;
t: 2over ( w1 w2 w3 w4 – w1 w2 w3 w4 w1 w2)
  >r >r 2dup r> r> 2swap t;
t: 2nip  ( w1 w2 w3 w4 -– w3 w4 )
  >r >r  drop drop r> r> swap t;
t: 2rot ( d1 d2 d3 -- d2 d3 d1 )
  2>r 2swap 2r> 2swap t;
t: negate ( n -- -n ) invert 1+ t;
t: dnegate ( d -- -d )
   invert >r invert 1 literal um+ r> + t;

t: dinvert  invert swap invert swap t;
t: 2drop ( w w -- ) drop drop t;
t: d<           ( al ah bl bh -- flag )
    rot         ( al bl bh ah )
    2dup = if 2drop u<
          else 2nip >
    then
t;

t: d> 2swap d< t;
t: d0<= 0 literal 0 literal d> invert t;
t: d<= d> invert t;
t: d>= d< invert t;
t: d0= or 0= t;
t: d=                       ( a b c d -- f )
    >r                      ( a b c )
    rot xor                 ( b a^c )
    swap r> xor             ( a^c b^d )
    or 0=
t;
t: d0<> d0= invert t;
t: d<> d= invert t;
t: d+                             ( augend . addend . -- sum . )
    rot + >r                      ( augend addend)
    over +                        ( augend sum)
    dup rot                       ( sum sum augend)
    u< if                         ( sum)
        r> 1+
    else
        r>
    then                          ( sum . )
t;
t: d- dnegate d+ t;

t: - ( n1 n2 -- n1-n2 ) negate + t;
t: abs ( n -- n ) dup 0< if negate then exit t;
t: max ( n n -- n ) 
    ( n1 n2 n1 n2 ) 2dup 
    ( n1 n2 n1>n2 ) > if
    ( n1)  drop exit then
    ( n2) nip t;
t: min ( n n -- n ) 2dup < if drop exit then nip t;
t: within ( u ul uh -- t )
    ( u ul uh-ul)  over -
    ( u-ul ) >r -
    ( u-ul uh-ul ) r>
    ( u-ul < uh-ul ) u< t;
t: um/mod ( udl udh u -- ur uq )
   2dup u< if
    negate f literal
     for >r dup um+ >r >r dup um+ r> + dup
     r> r@ swap >r um+ r> or if
      >r drop 1+ r>
     else
      drop
     then r>
     next drop swap exit
   then drop 2drop -1 literal dup t;
t: m/mod ( d n -- r q )
   dup 0< dup >r if
    negate >r dnegate r>
   then >r dup 0< if
    r@ +
   then r> um/mod r> if
    swap negate swap then exit t;
t: /mod ( n n -- r q ) over 0< swap m/mod t;
t: mod ( n n -- r ) /mod drop t;
t: / ( n n -- q ) /mod nip t;
t: um* ( u u -- ud )
   0 literal swap f literal
    for dup um+ >r >r dup um+ r> + r> if
    >r over um+ r> + then
    next rot drop t;
t: * ( n n -- n ) um* drop t;
t: m* ( n n -- d )
   2dup xor 0< >r abs swap abs um* r> if
    dnegate then exit t;
t: */mod ( n1 n2 n3 -- r q ) 
  >r m* r> m/mod t;
t: */ ( n1 n2 n3 -- q ) 
  */mod nip t;
\ t: m*/mod
\    divisor !
\    tuck um* 2swap um*   ( hi. lo. )
\                         ( m0 h l m1 )
\    swap >r 0 literal d+ r>   ( m h l )
\    -rot                 ( l m h )
\    32 literal 0 literal do
\        t2*
\        dup divisor @ >= if
\            divisor @ -
\            rot 1+ -rot
\        then
\   loop
\ t;

\ t: m*/ m*/mod drop t;
t: cell+ ( a -- a ) =cell literal + t;
t: cell- ( a -- a ) =cell literal - t;
t: cells ( n -- n ) 1 literal lshift t;
t: bl ( -- 32 ) 20 literal t;
t: >char ( c -- c )
   \ ff literal and ( 7 бит в 0 )
   dup ff literal bl within  ( между 7f и пробелом)
   if drop 5f literal then ( ascii _  )
   exit t;
t: +! ( n a -- ) tuck @ + swap ! t;
t: 2! ( d a -- ) swap over ! cell+ ! t;
t: 2@ ( a -- d ) dup cell+ @ swap @ t;
( converts a string array address to the address-length representation)
( of a counted string)
t: count ( b -- b +n )
  dup 1+ swap c@ t;
( Return the top of the code dictionary.)
t: here ( -- a ) dp @ t;
t: aligned ( b -- a )
   dup 0 literal =cell literal um/mod drop dup if
    =cell literal swap - then + t;
( выравнивает адрес свободный и кладет в dp)    
t: align ( -- ) here aligned dp ! t;
( the address of the text buffer where numbers are constructed)
( and text strings are stored temporarily)
t: pad ( -- a ) here 50 literal + aligned t;
t: @execute ( a -- ) @ ?dup if execute then exit t;
t: fill ( b u c -- )
   swap for swap aft 2dup c! 1+ then next 2drop t;
t: erase 0 literal fill t;
t: digit ( u -- c ) 
  9 literal over < 7 literal and + 30 literal + t;
t: extract ( n base -- n c ) 0 literal swap um/mod swap digit t;
t: <# ( -- ) pad hld ! t;
t: hold ( c -- ) hld @ 1- dup hld ! c! t;
t: # ( u -- u ) base @ extract hold t;
t: #s ( u -- 0 )  begin # dup while repeat t;
t: sign ( n -- ) 0< if 2d literal hold then exit t; ( 2d = ascii -)
t: #> ( w -- b u ) drop hld @ pad over - t;
t: str ( n -- b u ) dup >r abs <# #s r> sign #> t;
t: hex ( -- ) 10 literal base ! t;
t: decimal ( -- ) a literal base ! t;
t: digit? ( c base -- u t )
   >r 30 literal - 9 literal  over < if
    dup 20 literal > if
	 20 literal  -
	then
	7 literal - dup a literal  < or
  then dup r> u< t;
t: number? ( a -- n t | a f )
   base @ >r 0 literal over count
   over c@ 24 literal = if
    hex swap 1+ swap 1- then
   over c@ 2d literal = >r
   swap r@ - swap r@ + ?dup if
    1-
     for dup >r c@ base @ digit?
       while swap base @ * + r> 1+
     next r@ nip if
	  negate then swap
     else r> r> 2drop 2drop 0 literal
      then dup
   then r> 2drop r> base ! t;
t: ?rx ( -- c t | f ) f001 literal @ 1 literal and 0= invert t;
t: tx! ( c -- )
   begin
    f001 literal @ 2 literal and 0=
   until f000 literal ! t;
t: ?key ( -- c ) '?key @execute t;
t: emit ( c -- ) 'emit @execute t;
t: key ( -- c )
    begin
     ?key
	until f000 literal @ t;
t: nuf? ( -- t ) ?key dup if drop key =cr literal = then exit t;
t: space ( -- ) bl emit t;
t: spaces ( +n -- ) 0 literal max  for aft space then next t;
t: type ( b u -- ) 
  for aft count emit then next drop t;
t: cr ( -- ) 
  =cr literal emit =lf literal emit t;
t: do$ ( -- a )
   r> r@ r> count + aligned >r swap >r t; compile-only
t: $"| ( -- a ) do$ noop t; compile-only
t: .$ ( a -- ) count type t;
t: ."| ( -- ) do$ .$ t; compile-only
t: .r ( n +n -- ) >r str r> over - spaces type t;
t: u.r ( u +n -- ) >r <# #s #> r> over - spaces type t;
t: u. ( u -- ) <# #s #> space type t;
t: . ( w -- ) base @ a literal xor if u. exit then str space type t;
t: cmove ( b1 b2 u -- ) for aft >r dup c@ r@ c! 1+ r> 1+ then next 2drop t;
t: pack$ ( b u a -- a ) dup >r 2dup ! 1+ swap cmove r> t;
t: ? ( a -- ) @ . t;
t: (parse) ( b u c -- b u delta ; <string> )
  temp ! over >r dup if
    1- temp @ bl = if
      for
	  count temp @ swap - 0< invert r@ 0> and
	   while next r> drop 0 literal dup exit
	 then 1- r>
    then over swap
      for
	  count temp @ swap - temp @ bl = if
	   0< then
	    while next dup >r else r> drop dup >r 1-
     then over - r> r> - exit
   then over r> - t;

t: parse ( c -- b u ; <string> )
   >r
   tib @ >in @ +
   #tib @ >in @ - r>
   (parse)
   >in +! t;
t: .( ( -- ) 29 literal parse type t; immediate
t: ( ( -- ) 29 literal parse 2drop t; immediate
t: <\> ( -- )  \ начало ввода
  #tib @ >in ! t; immediate 
t: \ ( -- ) '\ @execute t; immediate
t: word ( c -- a ; <string> ) parse here cell+ pack$ t;
t: token ( -- a ; <string> ) bl word t;

( )
t: name> ( na -- ca ) ( NFA -- CFA)
  count 1f literal and + aligned t;

t: same? ( a a u -- a a f \ -0+ )
   1-
    for aft over r@ + c@
     over r@ + c@ - ?dup
   if r> drop exit then then
    next 0 literal t;

t: find ( a va -- ca na | a f )
   swap
   dup c@ temp !
   dup @ >r
   cell+ swap
    begin @ dup
      if dup @ =mask literal and r@ xor
       if cell+ -1 literal else cell+ temp @ same? then
      else r> drop swap cell- swap exit
      then
    while 2 literal cells -
    repeat r> drop nip cell- dup name> swap t;

t: <name?> ( a -- ca na | a f )
    context dup 2@ xor if cell- then >r
    begin
	    r> cell+ dup >r @ ?dup
    while
	    find ?dup
    until r> drop exit then r> drop 0 literal t;

( search dictionary for word just parsed )
t: name? ( a -- ca na | a f ) 
  'name? @execute t;

( processes the back-space character)
t: ^h ( bot eot cur -- bot eot cur )
   >r over r@ < dup if
    =bksp literal dup emit space
	emit then r> + t;

t: tap ( bot eot cur c -- bot eot cur )
   dup emit over c! 1+ t;

( processes a character c received from terminal)
t: ktap ( bot eot cur c -- bot eot cur )
   dup =cr literal xor 
   if =bksp literal xor 
    if bl tap exit then 
    ^h exit
   then drop nip dup t;

t: accept ( b u -- b u )
   over + over
    begin
      2dup xor
    while
      key dup bl - 7f literal u< if tap else ktap then
    repeat drop over - t;

( accepts text input and copies the text characters to the TIB)
t: query ( -- ) 
  tib @ 50 literal accept #tib ! drop 0 literal >in ! t;

t: abort2 do$ drop t;

t: abort1 
  space .$ 3f literal emit cr 'abort @execute abort2 t;

t: <?abort">
  if do$ abort1 exit then abort2 t; compile-only

( )
t: forget ( -- )
   token name? ?dup if
    cell- dup dp !
     @ dup context ! last !
     drop exit
   then abort1 t;
( Interpret a word. If failed, try to convert it to an integer.)
t: $interpret ( a -- )
   name? ?dup if
    @ =comp literal and
     <?abort"> $literal compile-only" execute exit
   else number? if
     exit then abort1 then t;

t: [ ( -- )
  [t] $interpret literal 'eval ! t; immediate

t: .ok ( -- )
  [t] $interpret literal 'eval @ = if
    ."| $literal  ok"
  then cr t;

t: eval ( -- )
  begin
    token dup c@
  while
	  'eval @execute \ $interpret
  repeat drop .ok t;

t: $eval ( a u -- )
  >in @ >r #tib @ >r tib @ >r
  [t] >in literal 0 literal swap !
  #tib ! tib ! eval r> tib ! r> #tib ! r> >in ! t; compile-only

t: preset ( -- ) \ установка #tib
  =tib literal
  #tib cell+ ! t;

t: quit ( -- )
  [ begin
	  query eval
  again t;

t: abort
  drop preset .ok quit t;

t: ' ( -- ca ) ( CFA следующего в строке слова)
  token name? if exit then abort1 t;

t: allot ( n -- ) ( )
  aligned dp +! t;

t: , ( w -- ) 
  here dup cell+ dp ! ! t;

t: call, ( ca -- )
  1 literal rshift 4000 literal or , t; compile-only

t: ?branch ( ca -- ) 
  1 literal rshift 2000 literal or , t; compile-only

t: branch ( ca -- )
  1 literal rshift 0000 literal or , t; compile-only

t: [compile] ( -- ; <string> ) ' call, t; immediate

t: compile ( -- ) r> dup @ , cell+ >r t; compile-only

t: recurse last @ name> call, t; immediate

t: pick dup 2* 2* =pickbody literal + >r t;

t: literal ( w -- )
   dup 8000 literal and if
    ffff literal xor [t] literal ]asm call asm[ compile invert
   else
    8000 literal or ,
   then exit t; immediate
t: ['] ' [t] literal ]asm call asm[ t; immediate
( compiles a string literal)
t: $," ( -- ) 22 literal parse here pack$ count + aligned dp ! t;
t: for ( -- a ) compile [t] >r ]asm call asm[ here t; compile-only immediate
t: begin ( -- a ) here t; compile-only immediate
t: (next) ( n -- ) r> r> ?dup if 1- >r @ >r exit then cell+ >r t; compile-only
t: next ( -- ) compile (next) , t; compile-only immediate
t: (do) ( limit index -- index ) r> dup >r swap rot >r >r cell+ >r t; compile-only
t: do ( limit index -- ) compile (do) 0 literal , here t; compile-only immediate
t: (leave) r> drop r> drop r> drop t; compile-only
t: leave compile (leave) noop t; compile-only immediate
t: (loop)
   r> r> 1+ r> 2dup <> if
    >r >r @ >r exit
   then >r 1- >r cell+ >r t; compile-only
t: (unloop) r> r> drop r> drop r> drop >r t; compile-only
t: unloop compile (unloop) noop t; compile-only immediate
t: (?do)
   2dup <> if
     r> dup >r swap rot >r >r cell+ >r exit
   then 2drop exit t; compile-only
t: ?do ( limit index -- ) 
  compile (?do) 0 literal , 
  here t; compile-only immediate
t: loop ( -- )
  compile (loop) dup ,
  compile (unloop) cell- here 1 literal 
  rshift swap ! t; compile-only immediate
t: (+loop)
   r> swap r> r> 2dup - >r
   2 literal pick r@ + r@ xor 0< 0=
   3 literal pick r> xor 0< 0= or if
    >r + >r @ >r exit
   then >r >r drop cell+ >r t; compile-only
t: +loop ( n -- )
  compile (+loop) dup ,
  compile (unloop) cell- here 1 literal
  rshift swap ! t; compile-only immediate
t: (i) ( -- index ) r> r> tuck >r >r t; compile-only
t: i ( -- index ) compile (i) noop t; compile-only immediate
t: until ( a -- ) ?branch t; compile-only immediate
t: again ( a -- ) branch t; compile-only immediate
t: if ( -- a ) here 0 literal ?branch t; compile-only immediate
t: then ( a -- ) here 1 literal rshift over @ or swap ! t; compile-only immediate
t: repeat ( a a -- ) branch [t] then ]asm call asm[ t; compile-only immediate
t: skip here 0 literal branch t; compile-only immediate
t: aft ( a -- a a ) drop [t] skip ]asm call asm[ [t] begin ]asm call asm[ swap t; compile-only immediate
t: else ( a -- a ) [t] skip ]asm call asm[ swap [t] then ]asm call asm[ t; compile-only immediate
t: while ( a -- a a ) [t] if ]asm call asm[ swap t; compile-only immediate

t: (case) r> swap >r >r	t; compile-only
t: case compile (case) 30 literal t; compile-only immediate
t: (of) r> r@ swap >r = t; compile-only
t: of compile (of) [t] if ]asm call asm[ t; compile-only immediate
t: endof [t] else ]asm call asm[ 31 literal t; compile-only immediate
t: (endcase) r> r> drop >r t;
t: endcase
  begin
    dup 31 literal =
  while
    drop			
    [t] then ]asm call asm[
  repeat
  30 literal <> <?abort"> $literal bad case construct."
  compile (endcase) noop t; compile-only immediate

( compiles a character string)
t: $" ( -- ; <string> )
  compile $"| $," t; compile-only immediate
t: ." ( -- ; <string> )
  compile ."| $," t; compile-only immediate
t: >body ( ca -- pa )  ( cfa -- pfa )
  cell+ t;
t: (to) ( n -- )
  r> dup cell+ >r @ ! t; compile-only
t: to ( n -- )
  compile (to) ' >body , t; compile-only immediate
t: (+to) ( n -- )
  r> dup cell+ >r @ +! t; compile-only
t: +to ( n -- )
  compile (+to) ' >body , t; compile-only immediate
t: get-current ( -- wid )
  current @ t;
t: set-current ( wid -- )
  current ! t;
t: definitions ( -- )
  context @ set-current t;
( display a warning message to show)
( that the name of a new word is a duplicate)
t: ?unique ( a -- a )
   dup get-current find if ."| $literal  redef " over .$ then drop t;

( builds a new entry in the name dictionary)   
t: <$,n> ( na -- )
   dup c@ if
    ?unique
	dup count + aligned
	dp !
    dup last !
    cell-
    get-current @
    swap ! exit
   then drop $"| $literal name" abort1 t;
t: $,n ( na -- ) '$,n @execute t;

( builds the body of a new colon definition)
t: $compile ( a -- )
   name? ?dup if
    @ =imed literal and if
	 execute exit
	 else call, exit
	then
   then
   number? if
     [t] literal ]asm call asm[ exit then abort1 t;
t: abort" compile <?abort"> $," t; immediate
( links a new definition to the current vocabulary and)
( thus makes it available for dictionary searches.)
t: <overt> ( -- )
  last @ get-current ! t;
t: overt ( -- ) 'overt @execute t;
t: exit r> drop t;
t: <;> ( -- )
   compile [t] exit ]asm call asm[
   [ overt 0 literal here ! t; compile-only immediate
t: ; ( -- ) '; @execute t; compile-only immediate
t: ] ( -- ) [t] $compile literal 'eval ! t;
t: : ( -- ; <string> ) token $,n ]  t;
t: immediate ( -- ) 
  =imed literal last @ @ or last @ ! t;
( creates a new user variable. The user variable contains)
( an user area offset, which is added to the beginning )
( address of the user area and to return the address of the)
( user variable in the user area) 
t: user ( u -- ; <string> ) 
  token $,n overt compile douser , t;
( creates a new array without allocating memory. Memory is)
( allocated using ALLOT.)
t: <create> ( -- ; <string> )
  token $,n overt [t] dovar ]asm literal asm[ call, t;

t: create ( -- ; <string> ) 
  'create @execute t;
t: variable ( -- ; <string> ) create 0 literal , t;
t: 2variable ( -- ; <string> ) create 0 literal , 0 literal , t;

t: (does>) ( -- )
   r> 1 literal rshift here 1 literal rshift
   last @ name> dup cell+ ]asm 8000 literal asm[ or , ! , t; compile-only
t: compile-only ( -- ) =comp literal last @ @ or last @ ! t;
t: does> ( -- ) compile (does>) noop t; immediate
t: char ( <char> -- char ) ( -- c ) bl word 1+ c@ t;
t: [char] char [t] literal ]asm call asm[ t; immediate
t: constant create , (does>) @ t;
t: defer create 0 literal , 
   (does>) 
    @ ?dup 0 literal =
   <?abort"> $literal uninitialized" execute t;
t: is ' >body ! t; immediate
( displays the name of a word, given the word's name field )
( address. It also replaces non-printable characters in a )
( name by under-scores.)
t: .id ( na -- )
   ?dup if
   count 1f literal and type exit then
   cr ."| $literal {noname}" t;
( 0x1b42 - 0x1b3c )
t: wordlist ( -- wid ) 
  align here 0 literal , dup current cell+ dup @ , ! 0 literal , 
  t;
t: order@ ( a -- u*wid u ) dup @ dup if >r cell+ order@ r> swap 1+ exit then nip t;
t: get-order ( -- u*wid u ) context order@ t;
t: >wid ( wid -- ) cell+ t;
t: .wid ( wid -- )
   space dup >wid cell+ @ ?dup if .id drop exit then 0 literal u.r t;
t: !wid ( wid -- ) >wid cell+ last @ swap ! t;
t: vocs ( -- ) ( list all wordlists )
   cr ."| $literal vocs:" current cell+
   begin
    @ ?dup
   while
    dup .wid >wid
   repeat t;
t: order ( -- ) ( list search order )
   cr ."| $literal search:" get-order
   begin
    ?dup
   while
    swap .wid 1-
   repeat
   cr ."| $literal define:" get-current .wid t;
t: set-order ( u*wid n -- ) ( 16.6.1.2197 )
   dup -1 literal = if
   drop forth-wordlist 1 literal then
   =vocs literal over u< <?abort"> $literal over size of #vocs"
   context swap
   begin
    dup
   while
    >r swap over ! cell+ r>
    1-
   repeat swap ! t;
t: only ( -- ) -1 literal set-order t;
t: also ( -- ) get-order over swap 1+ set-order t;
t: previous ( -- ) get-order swap drop 1- set-order t;
t: >voc ( wid 'name' -- )
   create dup , !wid
   (does>)
	 @ >r get-order swap drop r> swap set-order t;
t: widof ( "vocabulary" -- wid ) ' >body @ t;
t: vocabulary ( 'name' -- ) wordlist >voc t;
t: _type ( b u -- ) 
  for aft count >char emit then next drop t;  
t: dm+ ( a u -- a )
   over 4 literal u.r space
   for aft count 3 literal u.r then next t;
t: dump ( a u -- ) ( address unsigned_int )
   base @ >r hex 10 literal /
   for cr 10 literal 2dup dm+ -rot
   2 literal spaces _type
   next drop r> base ! t;
t: .s ( ... -- ... ) ( вывод стека на экран )
  cr sp@ 1- f literal and 
  for r@ pick . next
  ."| $literal <tos" t;
t: (>name) ( ca va -- na | f )
   begin
    @ ?dup
   while
    2dup name> xor
     while cell-
   repeat nip exit
   then drop 0 literal t;
t: >name ( ca -- na | f ) ( CFA -- NFA)
   >r get-order
   begin
	  ?dup
   while
	  swap
	  r@ swap
	  (>name)
	  ?dup if
		>r
		1- for aft drop then next
		r> r> drop
		exit
	  then
	  1-
   repeat
   r> drop 0 literal t;

t: see ( -- ; <string> )
   ' cr
   begin
    dup @ ?dup 700c literal xor
   while
    3fff literal and 1 literal lshift
	  >name ?dup if
      space .id
	  else
	    dup @ 7fff literal and u.
	  then
	  cell+
   repeat 2drop t;
( список слов)
t: (words) ( -- )
   cr
   begin
    @ ?dup
   while
    dup .id space cell-
   repeat t;
t: words
   get-order
   begin
	  ?dup
   while
	  swap
	  cr cr ."| $literal :" dup .wid cr
	  (words)
	  1-
   repeat t;
t: ver ( -- n ) =ver literal 100 literal * =ext literal + t;
t: hi ( -- ) ( = boot )
   cr ."| $literal eforth j1 v"
	base @ hex
	ver <# # # 2e literal hold # #> ( 2e .)
	type base ! cr t;
t: cold ( -- )
   =uzero literal \ откуда 
   =up literal    \ куда
   =udiff literal \ сколько
   cmove
   preset \ #tib set
   forth-wordlist dup context ! dup current 2! overt
   4000 literal cell+ \ 4002
   dup cell-  \ 4002 4000
   @ $eval
   'boot @execute \ "hi" word
   quit
   cold t;

t: border f005 literal t; 
t: rs232 there literal t; 

target.1 -order set-current

there 			[u] dp t!
[last] 			[u] last t!
[t] ?rx			[u] '?key t!
[t] tx!			[u] 'emit t!
[t] <\>			[u] '\ t!
[t] $interpret	[u] 'eval  t!
[t] abort		[u] 'abort t!
[t] hi			[u] 'boot t!
[t] <name?>	[u] 'name? t!
[t] <overt>	[u] 'overt t!
[t] <$,n>		[u] '$,n t!
[t] <;>			[u] '; t!
[t] <create>	[u] 'create t!
[t] cold 		2/ =cold t!

save-target j1.bin ( 0 лишний не стеке)
save-hex    j1.hex
\ save-label  j1.lbl
\ twords
tlast 
\ meta.1 -order  
s" last word address: " type @ . cr
 \ hd @ close-file throw
\  bye
