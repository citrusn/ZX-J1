#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/stat.h>

static unsigned short t;
static unsigned short s;
static unsigned short d[0x20]; /* data stack */
static unsigned short r[0x20]; /* return stack */
static unsigned short pc;      /* program counter, counts cells */
static unsigned char dsp, rsp; /* point to top entry */
static unsigned short* memory; /* ram */
static int sx[4] = { 0, 1, -2, -1 }; /* 2-bit sign extension */

static void push(int v) // push v on the data stack
{
  dsp = 0x1f & (dsp + 1);
  d[dsp] = t;
  t = v;
}

static int pop(void) // pop value from the data stack and return it
{
  int v = t;
  t = d[dsp];
  dsp = 0x1f & (dsp - 1);
  return v;
}

static void execute(int entrypoint)
{
  int _pc, _t;
  int insn = 0x4000 | entrypoint; // first insn: "call entrypoint"
  FILE *log = fopen("j1c.log", "w");
  fprintf(log, "C\n");
  //pcapdev_init();
  do {
    _pc = pc + 1;
    if (insn & 0x8000) { // literal
      push(insn & 0x7fff);
    } else {
      int target = insn & 0x1fff;
      switch (insn >> 13) {
      case 0: // jump
        _pc = target;
        break;
      case 1: // conditional jump
		    if (pop() == 0)
          _pc = target;
        break;
      case 2: // call
        rsp = 31 & (rsp + 1);
        r[rsp] = _pc << 1;
        _pc = target;
        break;
      case 3: // alu
		    if (insn & 0x1000) {/* r->pc */
			    _pc = r[rsp] >> 1;
		    }
        s = d[dsp];
        int alu=(insn >> 8) & 0xf;
        switch (alu) {
          case 0:   _t = t; break; /* noop */
          case 1:   _t = s; break; /* copy */
          case 2:   _t = t+s; break; /* + */
          case 3:   _t = t&s; break; /* and */
          case 4:   _t = t|s; break; /* or */
          case 5:   _t = t^s; break; /* xor */
          case 6:   _t = ~t; break; /* invert */
          case 7:   _t = -(t==s); break; /* = */
          case 8:   _t = -((signed short)s < (signed short)t); break; /* < */
          case 9:   _t = s>>t; break; /* rshift */
          case 0xa:  _t = t-1; break; /* 1- */
          case 0xb:  _t = r[rsp];  break; /* r@ */
          case 0xc:  _t = /*(t==0xf008)? eth_poll():*/ /* @ */
                          (t==0xf001)? 1:
                            (t==0xf000)? getch():
                              memory[t>>1]; break; 
          case 0xd:  _t = s<<t; break; /* lshift */
          case 0xe:  _t = (rsp<<8) + dsp; printf("top=%d\r\n", _t); getch();  break; /* dsp */
          case 0xf:  _t = -(s<t); break; /* u< */
        }
        dsp = 31 & (dsp + sx[insn & 3]); /* dstack+- */
        rsp = 31 & (rsp + sx[(insn >> 2) & 3]); /* rstack+- */
        if (insn & 0x80) /* t->s */
           d[dsp] = t;
        if (insn & 0x40) /* t->r */
           r[rsp] = t;
        if (insn & 0x20) /* s->[t] */
          /*(t==0xf008)? eth_transmit():*/
            (t==0xf002)? (rsp=0):
              (t==0xf000)? putch(s):
                (memory[t>>1]=s); /* ! */
		    t = _t;
        break;
      }
    }
    pc = _pc;
    insn = memory[pc];
    if (pc >  0x4000) 
      printf("Error address!!! %x", pc);
    //fprintf(log, "%d-%d %d\n", pc, insn, t);
    fprintf(log, "%d-%d top=%d dsp=%d rsp=%d\n", pc, insn, t, dsp, rsp);
  } while (1);
}
/* end of cpu */

/* start of i/o demo */


int main(int argc , char *argv[])
{
  unsigned short m[0x4000]; /* 32kb or RAM */
  FILE *f = fopen("j1.bin", "rb");
  fread(m, 0x2000, sizeof(m[0]), f); /* 0kb - 16kb data and code */
  fclose(f);
  if (argc>1) {  // program name is counted as one
   struct stat st;
   f = fopen(argv[1], "r");
   stat(argv[1], &st);
   (&m[0x2000])[0] = st.st_size; /* 16kb - 32kb memory mapped i/o */
   fread(&m[0x2001], 0x2000, sizeof(m[0]), f);
   fclose(f);
  }
  memory = m;
  execute(0x00);
  return 0;
}
