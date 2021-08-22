( Time access                                JCB 13:27 08/24/10)

t: timeh create 0 literal , 0 literal , t;     ( high 32 bits of time)

t: time@  ( -- time. )   
    begin
        time literal 2@ 
        time literal 2@ 
        2over d<>
    while
        2drop
    repeat
t;

t: timeq     ( -- d d ) ( 64-bit time)
    time@ timeh 2@ t;

t: setalarm ( d a -- ) ( \ set alarm a for d microseconds hence)
    >r time@ d+ r> 2! t;
t: isalarm ( a -- f )
    2@ time@ d- d0<= t;

( 2variable sleeper )
t: sleeper create 0 literal , 0 literal , t; 

t: sleepus   sleeper setalarm begin sleeper isalarm until t;
t: sleep.1   3 literal 1699 literal sleepus t;    ( 100000.)
t: sleep1    30 literal 16990 literal  sleepus t; ( 1000000. )

( t: took ( d -- )
( time@ 2swap d- s" took " type d. cr t; )

t: uptime
    time@ 
    ( 1 literal 1000 literal m*/ )
    ( 1 literal 1000 literal m*/ )
t;