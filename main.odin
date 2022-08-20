package main

import "core:time"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:math"
import rl "vendor:raylib"
import la "core:math/linalg"
import rand "core:math/rand"

FPS :: 60
GAME_SPEED :u8: 10
W_WIDTH, W_HEIGHT :: 800, 600
CELL_COLUMNS, CELL_ROWS :: 15, 8
CELLS :: CELL_COLUMNS * CELL_ROWS

Direction :: enum{Up, Left, Down, Right}
State :: enum {Running, Paused, Death, Quit}
Foods :: enum {Small, Big, Super}
Entiti :: enum {Empty, Snake, Food}

Cells :: map [[2]i32] Entiti

Snake :: struct {
    body: [dynamic][2]i32,
    direction: Direction,
    eaten: bool,
}

Food :: struct {
    pos: [2]i32,
    type: Foods,
}


Colors := map[string]u32{
    "windowbg"   = 0x1F1F28,
    "gridbg"     = 0x2A2A37,
    "gridlines"  = 0xDCD7BA,
    "gridborder" = 0xC8C093,
    "infobg"     = 0xC8C093,
    "text"       = 0xDCD7BA,
    "snake"      = 0x7E9CD8,
    "snakedead"  = 0xE82424,
    "smallfood"  = 0xC34043,
    "bigfood"    = 0x98BB6C,
    "superfood"  = 0x957FB8,
}

Rgb :: struct {
    r : u8,
    g : u8,
    b : u8,
    a : u8,
}

cells: Cells
cellSize: rl.Vector2
gridPos:  rl.Vector2
gridSize: [2]i32
font, fontBold : rl.Font

score:     int
snake:     Snake
foods:      [dynamic]Food
timeAcc:   f32
eatenAcc:  u16
gameState: State
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
    gameState = State.Running
    /* Init Grid */
    size := f32(la.round(W_WIDTH * 0.8 / CELL_COLUMNS))
    cellSize.xy = size
    gridSize.x  = i32(cellSize.x) * CELL_COLUMNS
    gridSize.y  = i32(cellSize.y) * CELL_ROWS
    gridPos.x   = f32((W_WIDTH  - gridSize.x) / 2)
    gridPos.y   = f32((W_HEIGHT  - gridSize.y) / 2)

    score = 0
    moveSpeed = 1 / f32(GAME_SPEED)
    scoreMultiplier = math.sqrt(f32(GAME_SPEED))
    font = rl.LoadFont("./fonts/8bitOperatorPlus-Regular.ttf")
    fontBold = rl.LoadFont("./fonts/8bitOperatorPlus-Bold.ttf")

    snake.body = {}
    snake.direction = Direction.Right
    startPos: [2]i32 = {CELL_COLUMNS / 2 , CELL_ROWS / 2}
    for i in 0..<8 {
        vec : [2]i32 = {startPos.x - i32(i), startPos.y}
        append(&snake.body, vec)
    }

    for x:i32=0; x < CELL_COLUMNS; x+=1 {
        for y:i32=0; y < CELL_COLUMNS; y+=1 {
            cells[{x,y}]=.Empty
        }
    }
    for part in snake.body {
        cells[part]=.Snake 
    }

    foods = {}
    append(&foods, getFood(.Small))

    for food in foods {
        cells[food.pos]=.Food 
    }
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

    if collision(nextPos) {
        gameState = .Death 
        return
    } 

    if timeAcc >= moveSpeed {
        lastI := len(snake.body) - 1
        if snake.eaten == true {
            append(&snake.body, snake.body[lastI])
            cells[snake.body[lastI]]=.Snake
            snake.eaten = false
        }
        for i := lastI; i > 0; i-=1 {
            snake.body[i] = snake.body[i-1]
            cells[snake.body[lastI]]=.Empty
        }
        snake.body[0] = nextPos
        cells[snake.body[0]]=.Snake
        timeAcc -= moveSpeed
    }

    /* Handle Fruit */
    for i := 0; i < len(foods); i += 1 {
        if snake.body[0] == foods[i].pos {
            if foods[i].type == .Small {
                score += int(math.round(1.0 * scoreMultiplier))
                eatenAcc += 1
                append(&foods, getFood(.Small))
            } else if foods[i].type == .Big {
                score += int(math.round(3.0 * scoreMultiplier))
                eatenAcc += 1
            }
            unordered_remove(&foods, i)
            snake.eaten = true
        } 
    }
    if snake.eaten == true && eatenAcc % 5 == 0 {
        append(&foods, getFood(.Big))
        snake.eaten = false
    }
    timeAcc += rl.GetFrameTime()
}


collision :: proc(nextPos: [2]i32) -> (collision: bool) {
    for occupied in snake.body {
        if nextPos == occupied do return true 
    } 
    return false
}

getFood :: proc(type: Foods) -> Food {
    rng := rand.create(u64(time.to_unix_nanoseconds(time.now())))
    for {
        pos :[2]i32= {
            i32(rand.float32_range(0, CELL_COLUMNS - 1, &rng)),
            i32(rand.float32_range(0, CELL_ROWS - 1, &rng)),
        }
        if cells[pos] == .Empty do return {pos, type}
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

    /* Draw Snake */
    c :rl.Color 
    if gameState == .Death {
        c = getColor(Colors["snakedead"], 250)
    } else {
        c = getColor(Colors["snake"], 250)
    }
    for pos in snake.body {
        vec2 := posToPixel(pos) 
        rl.DrawRectangleV(vec2, cellSize, c)
    }

    /* Draw Food */
    for f in foods {
        pos := posToPixel(f.pos)
        size: rl.Vector2
        if f.type == .Small {
            c = getColor(Colors["smallfood"], 250)
            size.xy = cellSize.x * 0.5
        } else if f.type == .Big {
            c = getColor(Colors["bigfood"], 250)
            size.xy = cellSize.x * 0.7
        }
        pos.x += (cellSize.x - size.x) / 2
        pos.y += (cellSize.y - size.y) / 2 + 1
        rl.DrawRectangleV(pos, size, c)
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
        ": "
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
