## Bare-bones SDL2 example
import sdl2

const
  width = 256*2
  height = 192*2  
  zxcolor = [ 
    (r:0'u8,    g:0'u8,   b:0'u8,   a:0'u8) # 0 black
  , (r:0'u8,    g:0'u8,   b:192'u8, a:0'u8) # 1 blue
  , (r:192'u8,  g:0'u8,   b:0'u8,   a:0'u8) # 2 red
  , (r:192'u8,  g:0'u8,   b:192'u8, a:0'u8) # 3 magenta
  , (r:0'u8,    g:192'u8, b:0'u8,   a:0'u8) # 4 green
  , (r:0'u8,    g:192'u8, b:192'u8, a:0'u8) # 5 cyan
  , (r:192'u8,  g:192'u8, b:0'u8,   a:0'u8) # 6 yellow
  , (r:192'u8,  g:192'u8, b:192'u8, a:0'u8) # 7 white  
  , (r:0'u8,    g:0'u8,   b:0'u8,   a:0'u8) # 8 black
  , (r:0'u8,    g:0'u8,   b:255'u8, a:0'u8) # 9 blue
  , (r:255'u8,  g:0'u8,   b:0'u8,   a:0'u8) # 10 red
  , (r:255'u8,  g:0'u8,   b:255'u8, a:0'u8) # 11 magenta
  , (r:0'u8,    g:255'u8, b:0'u8,   a:0'u8) # 12 green
  , (r:0'u8,    g:255'u8, b:255'u8, a:0'u8) # 13 cyan
  , (r:255'u8,  g:255'u8, b:0'u8,   a:0'u8) # 14 yellow
  , (r:255'u8,  g:255'u8, b:255'u8, a:0'u8) # 15 white
  ]

var
  window: WindowPtr
  render: RendererPtr
  texture: TexturePtr
  scr: File
  fileBuf: array[0..6911, uint8] 
  zxScr: array[0..width*height-1, uint8]
  sdlBuf: array[0..width*height-1, Color]

proc getVideoAdr(x, y : int): int =
  (x shr 3)        or         # Помещение X в биты 0..4
  ((y and 7) shl 8) or        # Y[0..2] в биты 8..10
  (((y shr 3) and 7) shl 5) or  # Y[3..5] в биты 5..7
  (((y shr 6) and 3) shl 11) 

proc getAttrAdr(x,y: int): int =
  6144 + ((y shr 3) shl 5 or (x shr 3))

proc colorByPixel (x, y: int, px: uint8, flash: bool ): Color =
  var adr = getAttrAdr(x,y)
  var c = fileBuf[adr]
  # смещение цвета при бите яркости 
  var offset = if (c and 64'u8) > 0: 7'u8 else: 0'u8 
  var fl = if (c and 128'u8) > 0 and flash: true  else: false
  if (px > 0 and not fl) or (px==0 and fl) :
    zxcolor[ (c and 7'u8) + offset ] # цвет чернил
  else: 
    zxcolor[ ((c and 56'u8) shr 3'u8) + offset ] # цвет бумаги

scr = open("SpaceRaiders.scr")
assert scr.readBuffer(fileBuf[0].addr, 6912)==6912, "Неполный файл"
scr.close

for x in 0..255:
  for y in 0..191:    
    var pixel = fileBuf[getVideoAdr(x,y)]
    zxScr[y*256+x] = pixel and (1 shl (7 - (x and 7))).uint8

discard sdl2.init(INIT_EVERYTHING)
window = createWindow("SDL Skeleton", 100, 100, 
                      0+width.cint,0+height.cint, SDL_WINDOW_SHOWN)
render = createRenderer(window, -1,
                        Renderer_Accelerated or Renderer_PresentVsync or
                        Renderer_TargetTexture)
texture = render.createTexture(SDL_PIXELFORMAT_ABGR8888, 
                              SDL_TEXTUREACCESS_TARGET, 
                              width.cint, height.cint )

var
  evt = sdl2.defaultEvent
  runGame = true
  flash = false

  dt: float32
  counter: uint64
  previousCounter: uint64

counter = getPerformanceCounter()
echo getPerformanceFrequency().float
counter = getTicks()

while runGame:
  #previousCounter = counter
  #counter = getPerformanceCounter()
  #dt = (counter - previousCounter).float / getPerformanceFrequency().float

  while pollEvent(evt):
    if evt.kind == QuitEvent:
      runGame = false
      break
    
  for x in 0..255:
    for y in 0..191:
      var i = y*(256)+x
      var pixel = zxScr[i]
      var color = colorByPixel(x, y, pixel, flash)
      sdlBuf[    2*y*width+2*x]=color
      sdlBuf[    2*y*width+2*x+1]=color
      sdlBuf[(2*y+1)*width+2*x]=color
      sdlBuf[(2*y+1)*width+2*x+1]=color

      #render.setDrawColor color
      #render.drawPoint (2*x-1).cint, 2*y.cint
      #render.drawPoint 2*x.cint    , 2*y.cint
      #render.drawPoint (2*x-1).cint, (2*y-1).cint
      #render.drawPoint 2*x.cint    , (2*y-1).cint

  texture.updateTexture(nil, sdlBuf[0].addr, width*sizeof(Color))
  render.copy(texture, nil, nil)    
  render.present
  if getTicks()-counter > 300:
    flash = not flash
    counter = getTicks()  

destroy texture
destroy render
destroy window
sdl2.quit()
