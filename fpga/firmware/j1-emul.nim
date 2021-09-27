



proc main(): void =
  var
    f: File
    memory: array[0..3fff, uint8]

  f.open("j1.bin")
  f. readBuffer(memory)

main()