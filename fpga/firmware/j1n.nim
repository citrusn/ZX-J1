import terminal, strformat
import dissasm

const 
  stackSz: int8 = 31

type
  j1Cpu* = ref j1CpuObj
  j1CpuObj = object
    top* : uint16    
    ds*: array[0..stackSz.int, uint16]
    rs*: array[0..stackSz.int, uint16]
    dsp*: int8
    rsp*: int8
    pc*: uint16
    start*: bool
    memory*: array[0..0x3fff, uint16]
    getch*: proc:uint16
    putch*: proc(c:uint16)

proc `<s` (u161, u162: uint16): bool =
  if (u162 > 32767) and (u161 > 32767) : # < 0
    result = u161 > u162
  elif (u162 > 32767) and (u161 < 32768): # top<0
    result = false
  elif  (u162 < 32768) and (u161 > 32767): # s<0
    result = true
  else:
    result = u161 < u162

proc push(cpu: j1Cpu, v: uint16) = 
  cpu.dsp = stackSz and (cpu.dsp + 1)
  cpu.ds[cpu.dsp]= cpu.top
  cpu.top = v

proc pop(cpu: j1Cpu) : uint16 = 
  result = cpu.top#.int16
  cpu.top = cpu.ds[cpu.dsp]
  cpu.dsp = stackSz and (cpu.dsp - 1)

proc executeCommand*(cpu: j1Cpu, insn: uint16) =
  var
    pc, top  : uint16
    sx: array[0..3, int8] = [0'i8, 1'i8, -2'i8, -1'i8]
  pc = cpu.pc
  if (insn and 0x8000)>0: # literal
    push(cpu, insn and 0x7fff)
  else:
    var target = insn and 0x1fff
    var op = insn shr 13
    case (op)
    of 0: # jump
      pc=target
    of 1:  # conditional jump
      if cpu.pop() == 0:
        pc= target
    of 2: # call
      cpu.rsp = stackSz and (cpu.rsp + 1)
      cpu.rs[cpu.rsp] = pc shl 1
      pc= target
    of 3: #alu
        if (insn and 0x1000)>0: #  r->pc 
          pc = cpu.rs[cpu.rsp] shr 1
        var s = cpu.ds[cpu.dsp]  
        var alu = (insn shr 8) and 0xf
        case alu
        of 0: top = cpu.top   # noop
        of 1: top = s         # copy
        of 2: top = cpu.top + s   # +
        of 3: top = cpu.top and s # and
        of 4: top = cpu.top or s  # or
        of 5: top = cpu.top xor s # xor
        of 6: top = not cpu.top   # invert
        of 7: top = if cpu.top == s: 65535 else: 0 # =          
        of 8:                     # < as signed
          if `<s`(s, cpu.top): top = 65535 else: top = 0
        of 9: top = s shr cpu.top     # rshift
        of 10: top = cpu.top - 1      # 1-
        of 11: top = cpu.rs[cpu.rsp]  # r@          
        of 12: top =                  # @
            case cpu.top    
            of 0xf001: 1'u16
            of 0xf000: cpu.getch()
            else: 
              cpu.memory[cpu.top shr 1]
        of 13: top = s shl cpu.top                  # lshift          
        of 14: top = 
          (cpu.rsp shl 8).uint16 + cpu.dsp.uint16   # dsp
        of 15: top = if s < cpu.top: 65535 else: 0  # u<
        else: 
          raiseAssert "No correct ALU code"
        
        cpu.dsp = stackSz and (cpu.dsp + sx[insn and 3'u16])     # dstack +-
        cpu.rsp = stackSz and (cpu.rsp + sx[(insn shr 2) and 3]) # rstack +-
        
        if (insn and 0x80)>0: # top->second
          cpu.ds[cpu.dsp]=cpu.top
        
        if (insn and 0x40)>0: # top->return
          cpu.rs[cpu.rsp]=cpu.top
        
        if (insn and 0x20)>0: # second->[t]
          if cpu.top == 0xf002: cpu.start = false #cpu.rsp = 0
          else:
            if cpu.top == 0xf000: cpu.putch s
            else: cpu.memory[cpu.top shr 1] = s # !                    
        cpu.top = top
    else:
      raiseAssert "No correct INSN code"
    cpu.pc = pc

proc getchar*: uint16 =
  ord(getch()).uint16

proc putchar*(c: uint16) =
  stdout.write $(chr c and 0xff)

proc execute (cpu: j1Cpu, entrypoint: uint16, logging: bool=false) =
  var
    insn: uint16
    log: File
  
  if logging:
    log = open("j1nim.log", fmWrite)
    log.write "Nim\r\n"

  insn = 0x0000 or entrypoint
  cpu.start = true
  cpu.getch = getchar
  cpu.putch = putchar
  while cpu.start:    
    if logging:
      log.write( fmt("{cpu.pc:04x}({cpu.pc*2:04x}) {insn:04x} ") & disasm(insn) & "\r\n")
    cpu.pc = cpu.pc + 1
    executeCommand(cpu, insn)    
    insn = cpu.memory[cpu.pc]
    if logging:
      log.write( fmt("\t\ttop={cpu.top:#04x} dsp={cpu.dsp:#d} rsp={cpu.rsp:#d}\r\n"))    
  echo "\ncpu stopped"

proc main =
  var
    f: File
    j1: j1Cpu

  initDissasm("j1.bin", 0x1b3e)
  
  j1 = new j1Cpu
  f = open("j1.bin")
  echo f.readBuffer(j1.memory[0].addr, f.getFileSize() )
  f.close()

  j1.execute(0)

if isMainModule:
  main()
