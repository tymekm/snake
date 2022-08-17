package main
import rand "core:math/rand"
import "core:time"
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
Foods :: enum {Small, Big, Super}

Snake :: struct {
    body: [dynamic][2]i32,
    nextPos: [2]i32,
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
cellSize: [2]i32
gridPos: [2]i32
gridSize: [2]i32
snake : Snake
food: [dynamic]Food
score: u16
frameTimeAcc : f32
consumedAcc: u16
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
    size := la.round(W_WIDTH * 0.8 / CELL_COLUMNS)
    cellSize.xy = i32(size)
    gridSize.x = cellSize.x * CELL_COLUMNS
    gridSize.y = cellSize.y * CELL_ROWS
    gridPos.x = (W_WIDTH  - gridSize.x) / 2
    gridPos.y = (W_HEIGHT  - gridSize.y) / 2
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
        return
    }
    if rl.IsKeyPressed(.P) do gameState = .Paused
    if rl.IsKeyDown(.ESCAPE) || rl.IsKeyDown(.Q) do gameState = .Quit

    if gameState != .Running {return}
    nextDir := snake.direction
    if rl.IsKeyDown(.UP) || rl.IsKeyDown(.E) do nextDir = .Up
    if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.D) do nextDir = .Down
    if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.F) do nextDir = .Right
    if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.S) do nextDir = .Left

    /* Move Snake */
    nPos :[2]i32
    #partial switch snake.direction {
        case .Up :
            if snake.body[0].y != 0 {
                nPos = {snake.body[0].x, snake.body[0].y - 1}
            } else {
                nPos = {snake.body[0].x, CELL_ROWS - 1}
            }
        case .Down :
            if snake.body[0].y != CELL_ROWS - 1 {
                nPos = {snake.body[0].x, snake.body[0].y + 1}
            } else {
                nPos = {snake.body[0].x, 0}
            }
        case .Left :
            if snake.body[0].x != 0 {
                nPos = {snake.body[0].x - 1, snake.body[0].y}
            }
            else {
                nPos = {CELL_COLUMNS - 1, snake.body[0].y}
            }
        case .Right :
            if snake.body[0].x != CELL_COLUMNS - 1{
                nPos = {snake.body[0].x + 1, snake.body[0].y}
            }
            else {
                nPos = {0, snake.body[0].y}
            }
    }

    if nPos == snake.body[1] do return

    if checkCollision(nPos) {
        gameState = .Death 
        return
    } 

    snake.nextPos =  nPos
    snake.direction = nextDir

    if frameTimeAcc >= GAME_SPEED {
        consumedAcc += 1
        lastI := len(snake.body) - 1
        if snake.eaten == true {
            append(&snake.body, snake.body[lastI])
            snake.eaten = false
        }
        for i := lastI; i > 0; i-=1 {
            snake.body[i] = snake.body[i-1]
        }
        snake.body[0] = nPos
        frameTimeAcc -= GAME_SPEED
    }

    /* Handle Fruit */
    for i := 0; i < len(food); i += 1 {
        if nPos == food[i].pos && food[i].type == .Small {
            unordered_remove(&food, i)
            append(&food, getFood(.Small))
            snake.eaten = true
            consumedAcc += 1
            fmt.println(consumedAcc)
        } 
    }
    if snake.eaten == true && consumedAcc % 5 == 0 {
        append(&food, getFood(.Big))
       snake.eaten = false
    }
    frameTimeAcc += rl.GetFrameTime()
}


checkCollision :: proc(nextPos: [2]i32) -> (collision: bool) {
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
    if checkCollision(pos) do getFood(type)
    return {pos, type}
}

getColor :: proc(color: u32, alpha:u8= 255) -> rl.Color {
    red := u8(color >> (2*8) & 0xFF)
    green := u8(color >> (1*8) & 0xFF)
    blue := u8(color >> (0*8) & 0xFF)
    return {red, green, blue, alpha}
}

posToPixel :: proc(vec: [2]i32) -> [2]i32 {
    x := gridPos.x + vec.x * cellSize.x
    y := gridPos.y + vec.y * cellSize.y
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

    /* Draw Snake */
    color := getColor(Colors["brightRed"], 150)
    if gameState == .Death {
        color = getColor(Colors["red"], 150)
    }
    for pos in snake.body {
        vec2 := posToPixel(pos) 
        rl.DrawRectangle(vec2.x, vec2.y, cellSize.x, cellSize.y, color,)
    }

    /* Draw Food */
    c := getColor(Colors["green"], 150)
    for f in food {
        if f.type == .Big do c = getColor(Colors["yellow"], 150)
        f := posToPixel(f.pos) 
        rl.DrawRectangle(f.x, f.y, cellSize.x, cellSize.y, c)
    }
}
