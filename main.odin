package main
import rand "core:math/rand"
import "core:fmt"
import rl "vendor:raylib"
import la "core:math/linalg"
import "core:math"

FPS :: 60
GAME_SPEED :: 0.1
W_WIDTH, W_HEIGHT :: 800, 600
CELL_COLUMNS, CELL_ROWS :: 30, 20
CELLS :: CELL_COLUMNS * CELL_ROWS

Direction :: enum{Up, Left, Down, Right}
State :: enum {Running, Paused, Death, Quit}
Fruit :: enum { Apple, Pear, Orange}


Game :: struct {
    cells : [CELLS][2]i32,
    cellSize: [2]i32,
    gridPos: [2]i32,
    gridSize: [2]i32,
    snake : Snake,
    frameTimeAcc : f32,
    state : State,
}

Snake :: struct {
    body : [dynamic][2]i32,
    nextPos : [2]i32,
    direction : Direction,
}

Food :: struct {
    pos: [2]i32,
    type: Fruit,
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

getColor :: proc(color: u32, alpha:u8= 255) -> rl.Color{
    rgb : rl.Color
    rgb.r = u8(color >> (2*8) & 0xFF)
    rgb.g = u8(color >> (1*8) & 0xFF)
    rgb.b = u8(color >> (0*8) & 0xFF)
    rgb.a = alpha
    return rgb
}

gameInit :: proc() -> Game {
    game := Game{}
    using game

    size := la.round(W_WIDTH * 0.8 / CELL_COLUMNS)
    cellSize.xy = i32(size)
    gridSize.x = cellSize.x * CELL_COLUMNS
    gridSize.y = cellSize.y * CELL_ROWS
    gridPos.x = (W_WIDTH  - gridSize.x) / 2
    gridPos.y = (W_HEIGHT  - gridSize.y) / 2
    drawField(&game)

    frameTimeAcc = 0
    state = State.Running

    startPos: [2]i32 = {CELL_COLUMNS / 2 , CELL_ROWS / 2}
    for i in 0..<8 {
        vec : [2]i32 = {startPos.x - i32(i), startPos.y}
        append(&snake.body, vec)
    }
    snake.direction = Direction.Right
    return game
}

getPixlPos :: proc(vec: [2]i32, game: ^Game) -> [2]i32 {
    using game
    pos : [2]i32 
    pos.x = gridPos.x + vec.x * cellSize.x
    pos.y = gridPos.y + vec.y * cellSize.y
    return pos
}

createGrid :: proc(game : ^Game){
    using game
    i := 0
    for x in 0..<CELL_COLUMNS{
        for y in 0..<CELL_ROWS{
            vec :[2]i32= {i32(x),i32(y)}
            cells[i] = getPixlPos(vec, game)
            i+=1
        }
    }
}

drawField :: proc(game : ^Game) {
    using game
    rl.ClearBackground(getColor(Colors["black"]))
    outLineC := getColor(Colors["brightBlack"], 50)
    inLineC := getColor(Colors["brightRed"], 255)
    outerRec := rl.Rectangle {
        f32(gridPos.x), f32(gridPos.y),
        f32(gridSize.x), f32(gridSize.y),
    }
    rl.DrawRectangleLinesEx( outerRec, 2, inLineC)

    for i in 1..<CELL_COLUMNS {
       rl.DrawLine(
           gridPos.x + i32(i) * cellSize.x, gridPos.y,
           gridPos.x + i32(i) * cellSize.x, gridPos.y + gridSize.y,
           outLineC,
       ) 
    }

    for i in 1..<CELL_ROWS {
       rl.DrawLine(
           gridPos.x, gridPos.y + i32(i) * cellSize.y,
           gridPos.x + gridSize.x, gridPos.y + i32(i) * cellSize.y,
           outLineC,
       ) 
    }
}

moveSnake :: proc(game : ^Game, dirct : Direction) {
    using game.snake
    nPos :[2]i32
    #partial switch dirct {
        case .Up :
            if body[0].y != 0 {
                nPos = {body[0].x, body[0].y - 1}
            } else {
                nPos = {body[0].x, CELL_ROWS - 1}
            }
        case .Down :
            if body[0].y != CELL_ROWS - 1 {
                nPos = {body[0].x, body[0].y + 1}
            } else {
                nPos = {body[0].x, 0}
            }
        case .Left :
            if body[0].x != 0 {
                nPos = {body[0].x - 1, body[0].y}
            }
            else {
                nPos = {CELL_COLUMNS - 1, body[0].y}
            }
        case .Right :
            if body[0].x != CELL_COLUMNS - 1{
                nPos = {body[0].x + 1, body[0].y}
            }
            else {
                nPos = {0, body[0].y}
            }
    }

    if nPos == body[1] {return}

    checkCollision(nPos, game)
    nextPos =  nPos
    direction = dirct

    if game.frameTimeAcc >= GAME_SPEED {
        it := len(body) - 1
        for i := it; i > 0; i-=1 {
            body[i] = body[i-1]
        }
        body[0] = nPos
        game.frameTimeAcc -= GAME_SPEED
    }
}

checkCollision :: proc(nextPos: [2]i32, game: ^Game) {
    using game
    for occupied in snake.body {
        if nextPos == occupied{
            state = .Death
        } 
    } 
}

drawSnake :: proc(game: ^Game) {
    using game
    color := getColor(Colors["brightRed"], 150)
    if state == .Death {
        color = getColor(Colors["red"], 150)
    }
    for xy in snake.body {
        pos := getPixlPos(xy, game) 
        rl.DrawRectangle(pos.x, pos.y, cellSize.x, cellSize.y, color,)
    }
}

handleInput :: proc(game: ^Game) {
        using game
        if state == .Death {
            if rl.IsKeyPressed(.ENTER){
                game^ = gameInit()
            }
            if rl.IsKeyPressed(.Q){
                state = .Quit
            } return
        }else if state == .Paused {
        }else if state == .Paused {
            if rl.IsKeyPressed(.P){
                state = .Running
            } return
        }
        if rl.IsKeyDown(.ESCAPE) || rl.IsKeyDown(.Q){
            state = .Quit
        }
        if rl.IsKeyDown(.UP) || rl.IsKeyDown(.E){
            moveSnake(game, .Up)
        }
        if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.D){
            moveSnake(game, .Down)
        }
        if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.F){
            moveSnake(game, .Right)
        }
        if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.S){
            moveSnake(game, .Left)
        }
        if rl.IsKeyPressed(.P){
            state = .Paused
        }
        else {
            moveSnake(game, snake.direction)
        }
}

main :: proc() {
    rl.InitWindow(W_WIDTH, W_HEIGHT, "Snake!")
    defer rl.CloseWindow()

    rl.SetTargetFPS(FPS)

    game := gameInit()

    for game.state != .Quit {
        rl.BeginDrawing()
        defer rl.EndDrawing()
        handleInput(&game)
        drawField(&game)
        drawSnake(&game)
        if game.state != .Running {continue}
        game.frameTimeAcc += rl.GetFrameTime()
    }
}
