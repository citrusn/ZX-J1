type
  J1Cpu* = ref J1CpuObj
  J1CpuObj = object of RootObj
    top*: uint16
    #next*: uint16
    ds*: array[0..0x1f, uint16]
    rs*: array[0..0x1f, uint16]
    pc*: uint
    dsp*: uint8
    rsp*: uint8
    memory*: array[0..0x3fff, uint8]

proc push(cpu:J1CPU, v: uint16) =
  cpu.dsp = 0x1f'u8 and (cpu.dsp + 1)
  cpu.ds[cpu.dsp]=cpu.top
  cpu.top = v

proc pop(cpu: J1Cpu) : uint16 =
  let
    v = cpu.top
  cpu.top = cpu.ds[cpu.dsp];
  cpu.dsp = 0x1f and (cpu.dsp - 1);
  return v

proc execute(cpu: J1Cpu, entryPoint: uint16) = 
  var
    pc, top: uint16
    insn: uint16 = 0x4000 or entryPoint
  pc = pc + 1
  if ((insn and 0x8000) > 0):
    cpu.push(insn and 0x7fff)
  else:
    var
      target = insn and 0x1fff
    case (insn shr 13)
    of 0: 
      pc = target
    else:
      pc = 0
    
proc main(): void =
  var
    f: File    
    cpu: J1Cpu
  
  cpu = new(J1Cpu)
  assert f.open("j1.bin") == true
  echo f.readBuffer(cpu.memory[0].addr, 0x4000)
  f.close


main()