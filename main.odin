package main

import "core:mem"
import "core:time"
import "core:fmt"
import s "core:strconv"
import "core:strings"
import rl "vendor:raylib"
import la "core:math/linalg"
import rand "core:math/rand"

FPS :: 20
MOVE_SPEED :: 0.1
W_WIDTH, W_HEIGHT :: 800, 600
CELL_COLUMNS, CELL_ROWS :: 30, 20
CELLS :: CELL_COLUMNS * CELL_ROWS

Direction :: enum{Up, Left, Down, Right}
State :: enum {Running, Paused, Death, Quit}
Foods :: enum {Small, Big, Super}

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
    "black" =         0x282828,
    "red" =           0xcc241d,
    "green" =         0x98971a,
    "yellow" =        0xd79921,
    "blue" =          0x458588,
    "magenta" =       0xb16286,
    "cyan" =          0x689d6a,
    "white" =         0xa89984,
    "brightBlack" =   0x928374,
    "brightRed" =     0xfb4934,
    "brightGreen" =   0xb8bb26,
    "brightYellow" =  0xfabd2f,
    "brightBlue" =    0x83a598,
    "brightMagenta" = 0xd3869b,
    "brightCyan" =    0x8ec07c,
    "brightWhite" =   0xebdbb2,
}

Rgb :: struct {
    r : u8,
    g : u8,
    b : u8,
    a : u8,
}

cells : [CELLS][2]i32
cellSize: rl.Vector2
/* cellSize: [2]i32 */
gridPos: rl.Vector2
gridSize: [2]i32

score: int
snake : Snake
food: [dynamic]Food
timeAcc : f32
eatenAcc: u16
gameState : State

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
    gridSize.x = i32(cellSize.x) * CELL_COLUMNS
    gridSize.y = i32(cellSize.y) * CELL_ROWS
    gridPos.x = f32((W_WIDTH  - gridSize.x) / 2)
    gridPos.y = f32((W_HEIGHT  - gridSize.y) / 2)
    /* Init Snake */
    snake.body = {}
    snake.direction = Direction.Right
    startPos: [2]i32 = {CELL_COLUMNS / 2 , CELL_ROWS / 2}
    for i in 0..<8 {
        vec : [2]i32 = {startPos.x - i32(i), startPos.y}
        append(&snake.body, vec)
    }
    /* Init Food */
    food = {}
    append(&food, getFood(.Small))
}

updateGame :: proc() {
    /* Get Input */
    if gameState == .Death {
        if rl.IsKeyPressed(.ENTER) do initGame()
        if rl.IsKeyPressed(.Q) do gameState = .Quit
        return
    }else if gameState == .Paused {
        if rl.IsKeyPressed(.P) do gameState = .Running
        if rl.IsKeyPressed(.Q) do gameState = .Quit
        return
    }
    if rl.IsKeyPressed(.P) do gameState = .Paused
    if rl.IsKeyPressed(.ESCAPE)|| rl.IsKeyPressed(.Q) do gameState = .Quit

    if gameState != .Running {return}

    if rl.IsKeyPressed(.UP)    || rl.IsKeyPressed(.E) && snake.direction != .Down {
        snake.direction = .Up
    } 
    if rl.IsKeyPressed(.DOWN)  || rl.IsKeyPressed(.D) && snake.direction != .Up  {
        snake.direction = .Down
    }
    if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.F) && snake.direction != .Left {
        snake.direction = .Right
    }
    if rl.IsKeyPressed(.LEFT)  || rl.IsKeyPressed(.S) && snake.direction != .Right {
        snake.direction = .Left
    }

    nPos :[2]i32 = {0,0}
    #partial switch snake.direction {
        case .Up:
            if snake.body[0].y != 0 {
                nPos = {snake.body[0].x, snake.body[0].y - 1}
            } else {
                nPos = {snake.body[0].x, CELL_ROWS - 1}
            }
        case .Down:
            if snake.body[0].y != CELL_ROWS - 1 {
                nPos = {snake.body[0].x, snake.body[0].y + 1}
            } else {
                nPos = {snake.body[0].x, 0}
            }
        case .Left:
            if snake.body[0].x != 0 {
                nPos = {snake.body[0].x - 1, snake.body[0].y}
            }
            else {
                nPos = {CELL_COLUMNS - 1, snake.body[0].y}
            }
        case .Right:
            if snake.body[0].x != CELL_COLUMNS - 1{
                nPos = {snake.body[0].x + 1, snake.body[0].y}
            }
            else {
                nPos = {0, snake.body[0].y}
            }
    }

    if collision(nPos) {
        gameState = .Death 
        return
    } 

    if timeAcc >= MOVE_SPEED {
        lastI := len(snake.body) - 1
        /* if snake.eaten == true { */
        /*     append(&snake.body, snake.body[lastI]) */
        /*     snake.eaten = false */
        /* } */
        for i := lastI; i > 0; i-=1 {
            snake.body[i] = snake.body[i-1]
        }
        snake.body[0] = nPos
        timeAcc -= MOVE_SPEED
    }

    /* Handle Fruit */
    for i := 0; i < len(food); i += 1 {
        if snake.body[0] == food[i].pos {
            if food[i].type == .Small {
                score += 1 
                eatenAcc += 1
                append(&food, getFood(.Small))
            }
            else if food[i].type == .Big {
                score += 5 
                eatenAcc += 1
            }
            unordered_remove(&food, i)
            snake.eaten = true
        } 
    }
    if snake.eaten == true && eatenAcc % 5 == 0 {
        append(&food, getFood(.Big))
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
    pos :[2]i32= {
        i32(rand.float32_range(0, CELL_COLUMNS - 1, &rng)),
        i32(rand.float32_range(0, CELL_ROWS - 1, &rng)),
    }
    if collision(pos) do getFood(type)
    return {pos, type}
}

getColor :: proc(color: u32, alpha:u8= 255) -> rl.Color {
    red := u8(color >> (2*8) & 0xFF)
    green := u8(color >> (1*8) & 0xFF)
    blue := u8(color >> (0*8) & 0xFF)
    return {red, green, blue, alpha}
}

posToPixel :: proc(vec: [2]i32) -> rl.Vector2 {
    x := gridPos.x + f32(vec.x) * cellSize.x
    y := gridPos.y + f32(vec.y) * cellSize.y
    return {x, y}
}

draw :: proc() {
    /* Draw Play Field */
    rl.ClearBackground(getColor(Colors["black"]))
    outLineC := getColor(Colors["brightBlack"], 50)
    inLineC := getColor(Colors["brightRed"], 255)
    outerRec := rl.Rectangle {
        f32(gridPos.x), f32(gridPos.y),
        f32(gridSize.x), f32(gridSize.y),
    }
    rl.DrawRectangleLinesEx( outerRec, 2, inLineC)

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
        c = getColor(Colors["red"], 250)
    }
    else {
        c = getColor(Colors["brightRed"], 250)
    }
    for pos in snake.body {
        vec2 := posToPixel(pos) 
        rl.DrawRectangleV(vec2, cellSize, c)
    }

    /* Draw Food */
    for f in food {
        pos := posToPixel(f.pos)
        size: rl.Vector2
        if f.type == .Small {
            c = getColor(Colors["brightGreen"], 250)
            size.xy = cellSize.x * 0.5
        }
        else if f.type == .Big {
            c = getColor(Colors["brightBlue"], 250)
            size.xy = cellSize.x * 0.7
        }
        pos.x += (cellSize.x - size.x) / 2
        pos.y += (cellSize.y - size.y) / 2 + 1
        rl.DrawRectangleV(pos, size, c)
    }

    /* Draw Score */
    c = getColor(Colors["blue"])

    
    buf :[8]byte={}
    fSize :f32= 25
    text := strings.clone_to_cstring(s.itoa(buf[:], score))

    font := rl.LoadFont("./fonts/8bitOperatorPlus8-Regular.ttf")
    /* font := rl.GetFontDefault() */
    test :cstring= "Snake!"
    len := len(test)
    fontSize := f32(font.baseSize) * 1.2
    spacing :f32= 3
    textVec2 := rl.MeasureTextEx(font, test, fontSize, spacing)
    pos := rl.Vector2 {
        f32(W_WIDTH) / 2.0 - textVec2.x / 2.0,
        10,
    }
    rl.DrawTextEx(font, test, pos, fontSize, spacing ,c)
    /* rl.DrawText(cstring(text), 0,0,fz ,c) */
}
