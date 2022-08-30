package snake

import "core:time"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:math"
import rl "vendor:raylib"
import la "core:math/linalg"
import rand "core:math/rand"

FPS :: 60
GAME_SPEED :u8: 10
/* W_WIDTH, W_HEIGHT :: 800, 600 */
W_WIDTH, W_HEIGHT :: 1280, 1024
CELL_COLUMNS, CELL_ROWS :: 20, 10
CELLS :: CELL_COLUMNS * CELL_ROWS
FOOD_TIMER :: i32(CELLS * .2)

GameState :: enum {Running, Paused, Death, Quit}
CellState :: enum {Empty, Fruit, Obstructed}

Snake :: struct {
    body: [dynamic][2]i32,
    direction: Direction,
    eaten: bool,
    moved: bool,
}
Direction :: enum{Right, Down, Left, Up}

Fruit :: struct {
    pos: [2]i32,
    type: FruitsTypes,
    timer: i32,
    opacity: u8,
}
FruitsTypes :: enum {Apple, Mango, Dragonfruit, Fossil, Box}


Colors := map[string]u32{
    "windowbg"   = 0x1F1F28,
    "gridbg"     = 0x2A2A37,
    "gridlines"  = 0xDCD7BA,
    "gridborder" = 0xC8C093,
    "infobg"     = 0xC8C093,
    "text"       = 0xDCD7BA,
    "snake"      = 0x7E9CD8,
    "snakedead"  = 0xE82424,
    "white"      = 0xFFFFFF,
    "grey"       = 0x2c3030,
}

Rgb :: struct {
    r, g, b, a, : u8
}

cellSize: rl.Vector2
gridPos:  rl.Vector2
gridSize: [2]i32

rng : rand.Rand
font, fontBold : rl.Font
apple: rl.Texture
mango: rl.Texture
box: rl.Texture
dragonfruit: rl.Texture
snakebody: rl.Texture
snaketail: rl.Texture
snakehead: rl.Texture
snakebend: rl.Texture

score:     int
snake:     Snake
fruits:    [dynamic]Fruit
timeAcc:   f32
gameState: GameState
moveSpeed: f32
scoreMultiplier: f32

main :: proc() {
    rl.InitWindow(W_WIDTH, W_HEIGHT, "Snake!")
    defer rl.CloseWindow()
    rl.SetTargetFPS(FPS)

    initGame()
    for gameState != .Quit {
        rl.BeginDrawing()
        defer rl.EndDrawing()
        updateGame()
        draw()
    }
}

initGame :: proc() {
    gameState = .Running
    /* Init Grid */
    size := f32(la.round(W_WIDTH * 0.8 / CELL_COLUMNS))
    cellSize.xy = size
    gridSize.x  = i32(cellSize.x) * CELL_COLUMNS
    gridSize.y  = i32(cellSize.y) * CELL_ROWS
    gridPos.x   = f32((W_WIDTH  - gridSize.x) / 2)
    gridPos.y   = f32((W_HEIGHT  - gridSize.y) / 2)

    rng = rand.create(u64(time.to_unix_nanoseconds(time.now())))
    score = 0
    moveSpeed = 1 / f32(GAME_SPEED)
    scoreMultiplier = math.pow(f32(GAME_SPEED), 1.5)
    font = rl.LoadFont("./fonts/8bitOperatorPlus-Regular.ttf")
    fontBold = rl.LoadFont("./fonts/8bitOperatorPlus-Bold.ttf")

    appleImg := rl.LoadImage("./textures/apple.png")
    rl.ImageResize(&appleImg, i32(cellSize.x * 0.6), i32(cellSize.y * 0.6))
    apple = rl.LoadTextureFromImage(appleImg)
    mangoImg := rl.LoadImage("./textures/mango.png")
    rl.ImageResize(&mangoImg, i32(cellSize.x * 0.8), i32(cellSize.y * 0.8))
    mango = rl.LoadTextureFromImage(mangoImg)
    dragonfruitImg := rl.LoadImage("./textures/dragonfruit.png")
    rl.ImageResize(&dragonfruitImg, i32(cellSize.x * 0.8), i32(cellSize.y * 0.8))
    dragonfruit = rl.LoadTextureFromImage(dragonfruitImg)
    boxImg := rl.LoadImage("./textures/box.png")
    rl.ImageResize(&boxImg, i32(cellSize.x * 1.1), i32(cellSize.y * 1.1))
    box = rl.LoadTextureFromImage(boxImg)
    snakebodyImg := rl.LoadImage("./textures/snake-body.png")
    rl.ImageResize(&snakebodyImg, i32(cellSize.x), i32(cellSize.y))
    snakebody = rl.LoadTextureFromImage(snakebodyImg)
    snaketailImg := rl.LoadImage("./textures/snake-tail.png")
    rl.ImageResize(&snaketailImg, i32(cellSize.x), i32(cellSize.y))
    snaketail = rl.LoadTextureFromImage(snaketailImg)
    snakeheadImg := rl.LoadImage("./textures/snake-head.png")
    rl.ImageResize(&snakeheadImg, i32(cellSize.x), i32(cellSize.y))
    snakehead = rl.LoadTextureFromImage(snakeheadImg)
    snakebendImg := rl.LoadImage("./textures/snake-bend.png")
    rl.ImageResize(&snakebendImg, i32(cellSize.x), i32(cellSize.y))
    snakebend = rl.LoadTextureFromImage(snakebendImg)

    snake.body = {}
    snake.direction = Direction.Right
    startPos: [2]i32 = {CELL_COLUMNS / 2 , CELL_ROWS / 2}
    for i in 0..<8 {
        vec : [2]i32 = {startPos.x - i32(i), startPos.y}
        append(&snake.body, vec)
    }
    fruits = {}
    append(&fruits, getFruit(.Apple))
}

updateGame :: proc() {
    /* Get Input */
    if gameState == .Death {
        if rl.IsKeyPressed(.ENTER) do initGame()
        if rl.IsKeyPressed(.Q) do gameState = .Quit
        return
    } else if gameState == .Paused {
        if rl.IsKeyPressed(.P) do gameState = .Running
        if rl.IsKeyPressed(.Q) do gameState = .Quit
        return
    }
    if rl.IsKeyPressed(.P) do gameState = .Paused
    if rl.IsKeyPressed(.ESCAPE)|| rl.IsKeyPressed(.Q) do gameState = .Quit

    if gameState != .Running {return}

    nextDir: Direction
    if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.E) do nextDir = .Up  
    else if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.D) do nextDir = .Down 
    else if rl.IsKeyPressed(.RIGHT)|| rl.IsKeyPressed(.F) do nextDir = .Right 
    else if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.S) do nextDir = .Left 
    else do nextDir = snake.direction

    nextPos :[2]i32
    #partial switch nextDir {
        case .Up:
            if snake.body[0].y != 0 {
                nextPos = {snake.body[0].x, snake.body[0].y - 1}
            } else {
                nextPos = {snake.body[0].x, CELL_ROWS - 1}
            }
        case .Down:
            if snake.body[0].y != CELL_ROWS - 1 {
                nextPos = {snake.body[0].x, snake.body[0].y + 1}
            } else {
                nextPos = {snake.body[0].x, 0}
            }
        case .Left:
            if snake.body[0].x != 0 {
                nextPos = {snake.body[0].x - 1, snake.body[0].y}
            } else {
                nextPos = {CELL_COLUMNS - 1, snake.body[0].y}
            }
        case .Right:
            if snake.body[0].x != CELL_COLUMNS - 1{
                nextPos = {snake.body[0].x + 1, snake.body[0].y}
            } else {
                nextPos = {0, snake.body[0].y}
            }
    }

    if nextPos == snake.body[1] do return
    snake.direction = nextDir

    if timeAcc >= moveSpeed {
        lastI := len(snake.body) - 1
        if snake.eaten == true {
            append(&snake.body, snake.body[lastI])
            snake.eaten = false
        }
        for i := lastI; i > 0; i-=1 {
            snake.body[i] = snake.body[i-1]
        }
        if isOccupied(nextPos) == .Obstructed {
            gameState = .Death 
            snake.body[0] = nextPos
            return
        } 
        snake.body[0] = nextPos
        timeAcc -= moveSpeed
        snake.moved = true
    }

    /* Handle Fruit */
    for fruit, it in &fruits {
        if fruit.type != .Apple && fruit.type != .Fossil {
            if snake.moved do fruit.timer -= 1
            if fruit.timer == 0 { 
                if fruit.type == .Dragonfruit do fruit.type = .Fossil
                else do unordered_remove(&fruits, it)
                continue
            } else if fruit.timer <= i32(math.floor(f32(FOOD_TIMER) * .3)) {
                fruit.opacity += 15
            } 
        }
        if snake.body[0] == fruit.pos {
            if fruit.type != .Box do snake.eaten = true
            if fruit.type == .Apple {
                score += int(math.round(1.0 * scoreMultiplier))
            } else if fruit.type == .Mango {
                score += int(math.round(3.0 * scoreMultiplier))
            } else if fruit.type == .Dragonfruit {
                score += int(math.round(5.0 * scoreMultiplier))
            } else if fruit.type == .Box do openBox()
            unordered_remove(&fruits, it)
        } 
    }
    eatable := 0
    for fruit in fruits {
        if fruit.type != .Box && fruit.type != .Fossil do eatable += 1 
    }
    if eatable == 0 {
        randNum := getRandNum(1,10) 
        fruit : Fruit
        if randNum <= 8 do fruit = getFruit(.Apple)
        else if randNum <= 9  do fruit = getFruit(.Mango)
        else do fruit = getFruit(.Box)
        append(&fruits, fruit)
    }
    snake.moved = false
    timeAcc += rl.GetFrameTime()
}

isOccupied :: proc(pos: [2]i32) -> CellState {
    for part in snake.body {
        if pos == part do return .Obstructed
    }
    for fruit in fruits {
        if pos == fruit.pos && fruit.type == .Fossil do return .Obstructed
        else if pos == fruit.pos do return .Fruit
    } 
    return .Empty
}

openBox :: proc () {
    foodSpawned:=false
    for i in 0..=5 {
        if getRandNum(0,4) == 0 {
            randNum := getRandNum(1,10)
            if randNum <= 4 do append(&fruits, getFruit(.Apple))
            else if randNum <= 7 do append(&fruits, getFruit(.Mango))
            else if randNum <= 8 do append(&fruits, getFruit(.Dragonfruit))
            foodSpawned = true
        }
    }
    if foodSpawned == false do append(&fruits, getFruit(.Apple))
}

getRandNum :: proc(low: int, high: int) -> i32 {
    return i32(rand.float32_range(f32(low), f32(high), &rng))
}

getFruit :: proc(type: FruitsTypes) -> Fruit {
    for {
        pos :[2]i32= {
            getRandNum(0, CELL_COLUMNS),
            getRandNum(0, CELL_ROWS),
        }
        if isOccupied(pos) == .Empty {
            if type == .Apple do return {pos, type, -1, 255}
            else do return {pos, type, FOOD_TIMER, 255}
        } 
    }
}

getColor :: proc(color: u32, alpha:u8= 255) -> rl.Color {
    red   := u8(color >> (2*8) & 0xFF)
    green := u8(color >> (1*8) & 0xFF)
    blue  := u8(color >> (0*8) & 0xFF)
    return {red, green, blue, alpha}
}

posToPixel :: proc(vec: [2]i32) -> rl.Vector2 {
    x := gridPos.x + f32(vec.x) * cellSize.x
    y := gridPos.y + f32(vec.y) * cellSize.y
    return {x, y}
}

drawSnake :: proc() {
    using snake
    c :rl.Color 
    if gameState == .Death {
        c = getColor(Colors["snakedead"], 255)
    } else {
        c = getColor(Colors["white"], 255)
    }
    for pos, it in body {
        vec2 := posToPixel(pos)
        rotation : int
        if it == 0 {
            back := normaliseForWrap(body[it], body[it+1])
            diff := body[it] - back
            if diff == {1,0} do rotation = 0
            else if diff == {0,1} do rotation = 90
            else if diff == {-1,0} do rotation = 180
            else if diff == {0,-1} do rotation = 270
            adjustForRotation(&vec2, rotation)
            rl.DrawTextureEx(snakehead, vec2, f32(rotation), 1, c)
            continue
        } 
        if it == len(body) - 1 {
            front := normaliseForWrap(body[it], body[it-1])
            diff := body[it] - front
            if diff == {-1,0} do rotation = 0
            else if diff == {0,-1} do rotation = 90
            else if diff == {1,0} do rotation = 180
            else if diff == {0,1} do rotation = 270
            adjustForRotation(&vec2, rotation)
            rl.DrawTextureEx(snaketail, vec2, f32(rotation), 1, c)
            continue
        } 
        front := normaliseForWrap(body[it], body[it-1])
        back := normaliseForWrap(body[it], body[it+1])
        if highAbs(front - back) == 2 {
            diff := front - back
            if diff == {2,0} do rotation = 0
            else if diff == {0,2} do rotation = 90
            else if diff == {-2,0} do rotation = 180
            else if diff == {0,-2} do rotation = 270
            adjustForRotation(&vec2, rotation)
            rl.DrawTextureEx(snakebody, vec2, f32(rotation), 1, c)
        } else {
            diff := (body[it] - front) + (body[it] - back)
            if diff == {1,1} do rotation = 0
            else if diff == {-1,1} do rotation = 90
            else if diff == {-1,-1} do rotation = 180
            else if diff == {1,-1} do rotation = 270
            adjustForRotation(&vec2, rotation)
            rl.DrawTextureEx(snakebend, vec2, f32(rotation), 1, c)
        }
    }
    adjustForRotation :: proc(pos: ^rl.Vector2, rotation: int) {
        if rotation == 90 do pos.x += cellSize.x
        else if rotation == 180 { pos.x += cellSize.x; pos.y += cellSize.y}
        else if rotation == 270 do pos.y += cellSize.y
    }

    highAbs :: proc(vec2: [2]i32) -> i32 {
        return abs(vec2.x) > abs(vec2.y) ? abs(vec2.x) : abs(vec2.y)
    }

    normaliseForWrap :: proc(primary: [2]i32, secondary: [2]i32) -> [2]i32 {
        normalised: [2]i32 = secondary
        if abs(normalised.x - primary.x) > 1 {
            if normalised.x > primary.x do normalised.x -= CELL_COLUMNS
            else do normalised.x += CELL_COLUMNS
        } else if abs(normalised.y - primary.y) > 1 {
            if normalised.y > primary.y do normalised.y -= CELL_ROWS
            else do normalised.y += CELL_ROWS
        }
        return normalised
    }
}

draw :: proc() {
    /* Draw Play Field */
    rl.ClearBackground(getColor(Colors["windowbg"]))
    outerRec := rl.Rectangle {
        f32(gridPos.x), f32(gridPos.y),
        f32(gridSize.x), f32(gridSize.y),
    }
    gridbg := getColor(Colors["gridbg"], 255)
    rl.DrawRectangleRec( outerRec, gridbg)
    inLineC := getColor(Colors["gridlines"], 255)
    rl.DrawRectangleLinesEx( outerRec, 1, inLineC)

    outLineC := getColor(Colors["gridborder"], 50)
    for i in 1..<CELL_COLUMNS {
        posVec2 :rl.Vector2= {
            gridPos.x + f32(i) * cellSize.x,
            gridPos.y,
        }
        sizeVec2 :rl.Vector2= {
            gridPos.x + f32(i) * cellSize.x,
            gridPos.y + f32(gridSize.y),
        }
        rl.DrawLineV(posVec2, sizeVec2, outLineC) 
    }

    for i in 1..<CELL_ROWS {
        posVec2 :rl.Vector2= {
            gridPos.x,
            gridPos.y + f32(i) * cellSize.y,
        }
        sizeVec2 :rl.Vector2= {
            gridPos.x + f32(gridSize.x),
            gridPos.y + f32(i) * cellSize.y,
        }
       rl.DrawLineV(posVec2, sizeVec2, outLineC) 
    }

    drawSnake()
    c :rl.Color 
    /* Draw Fruit */
    for f in fruits {
        pos := posToPixel(f.pos)
        size: rl.Vector2
        if f.type == .Apple {
            c = getColor(Colors["white"], f.opacity)
            rl.DrawTexture(apple,
            i32(pos.x + cellSize.x/2 - f32(apple.width)/2),
            i32(pos.y + cellSize.y/2 - f32(apple.width)/2), c)
        } else if f.type == .Mango {
            c = getColor(Colors["white"], f.opacity)
            rl.DrawTexture(mango,
            i32(pos.x + cellSize.x/2 - f32(mango.width)/2),
            i32(pos.y + cellSize.y/2 - f32(mango.width)/2), c)
        } else if f.type == .Dragonfruit {
            c = getColor(Colors["white"], f.opacity)
            rl.DrawTexture(dragonfruit,
            i32(pos.x + cellSize.x/2 - f32(mango.width)/2),
            i32(pos.y + cellSize.y/2 - f32(mango.width)/2), c)
        } else if f.type == .Fossil {
            c = getColor(Colors["grey"], f.opacity)
            rl.DrawTexture(dragonfruit,
            i32(pos.x + cellSize.x/2 - f32(mango.width)/2),
            i32(pos.y + cellSize.y/2 - f32(mango.width)/2), c)
        } else if f.type == .Box {
            c = getColor(Colors["white"], f.opacity)
            rl.DrawTexture(box,
            i32(pos.x + cellSize.x/2 - f32(box.width)/2),
            i32(pos.y + cellSize.y/2 - f32(box.width)/2), c)
        }
    }

    /* Draw Title */
    c = getColor(Colors["text"])

    fSize :f32= 25

    text :cstring= "Snake!"
    fontSize := f32(fontBold.baseSize) * 1.7
    spacing :f32= 3
    textSizeVec2 := rl.MeasureTextEx(fontBold, text, fontSize, spacing)
    pos := rl.Vector2 {
        f32(W_WIDTH) / 2.0 - textSizeVec2.x / 2.0,
        gridPos.y/2 - textSizeVec2.y/2,
    }
    rl.DrawTextEx(fontBold, text, pos, fontSize, spacing ,c)

    /* Draw Score */
    buf :[256]byte={}
    str := strings.join({
        "Score", strconv.itoa(buf[:], score)},
        ": ",
    )
    defer delete(str)
    text = strings.clone_to_cstring(str)
    fontSize = f32(font.baseSize) * 1.2
    spacing = 0
    textSizeVec2 = rl.MeasureTextEx(font, text, fontSize, spacing)
    pos = rl.Vector2 {
        gridPos.x + f32(gridSize.x) - textSizeVec2.x,
        gridPos.y - textSizeVec2.y - 10,
    }
    rl.DrawTextEx(font, text, pos, fontSize, spacing ,c)
    if gameState == .Paused do drawInfoBox("Paused", "Press 'P' to continue")
    if gameState == .Death do drawInfoBox("GameOver!", "Press 'Enter' to play again or 'Q' to quit")
}

drawInfoBox :: proc(header: string, text: string) {

    h := strings.clone_to_cstring(header)
    hFontSize := f32(fontBold.baseSize) * 1.5
    headerSize:= rl.MeasureTextEx(fontBold, h, hFontSize, 0)

    t := strings.clone_to_cstring(text)
    tFontSize := f32(font.baseSize) * 0.8
    textSize := rl.MeasureTextEx(font, t, tFontSize, 0)
    textPadding :f32= 10

    headerPos := rl.Vector2 {
        W_WIDTH/2 - headerSize.x/2,
        W_HEIGHT/2 - (headerSize.y + textSize.y + textPadding)/2,
    }
    textPos := rl.Vector2 {
        W_WIDTH/2 - textSize.x/2,
        W_HEIGHT/2 - (headerSize.y + textSize.y + textPadding)/2 + headerSize.y + textPadding,
    }

    c := getColor(Colors["windowbg"], 190)
    textWidth: f32
    if headerSize.x > textSize.x do textWidth = headerSize.x
    else do textWidth = textSize.x
    ibPadding :i32= 20
    ibW: i32 = i32(textWidth) + ibPadding
    ibH: i32 = i32(textSize.y + headerSize.y + textPadding) + ibPadding
    ibX: i32 = W_WIDTH/2 - ibW/2
    ibY: i32 = W_HEIGHT/2 - ibH/2

    rl.DrawRectangle(ibX, ibY, ibW, ibH, c)

    c = getColor(Colors["text"])
    rl.DrawTextEx(fontBold, h, headerPos, hFontSize, 0, c)
    rl.DrawTextEx(font, t, textPos, tFontSize, 0, c)
}
