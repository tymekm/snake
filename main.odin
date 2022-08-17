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


Game :: struct {
    cells : [CELLS][2]i32,
    cellSize: [2]i32,
    gridPos: [2]i32,
    gridSize: [2]i32,
    snake : Snake,
    food: [dynamic]Food,
    score: u16,
    frameTimeAcc : f32,
    movesAcc: i32,
    state : State,
}

Snake :: struct {
    body : [dynamic][2]i32,
    nextPos : [2]i32,
    direction : Direction,
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

main :: proc() {
    rl.InitWindow(W_WIDTH, W_HEIGHT, "Snake!")
    defer rl.CloseWindow()

    rl.SetTargetFPS(FPS)

    game := initGame()

    for game.state != .Quit {
        rl.BeginDrawing()
        defer rl.EndDrawing()
        handleInput(&game)
        draw(&game)
        if game.state != .Running {continue}
        game.frameTimeAcc += rl.GetFrameTime()
    }
}

initGame :: proc() -> Game {
    game := Game{}
    using game
    state = State.Running

    /* Init Grid */
    size := la.round(W_WIDTH * 0.8 / CELL_COLUMNS)
    cellSize.xy = i32(size)
    gridSize.x = cellSize.x * CELL_COLUMNS
    gridSize.y = cellSize.y * CELL_ROWS
    gridPos.x = (W_WIDTH  - gridSize.x) / 2
    gridPos.y = (W_HEIGHT  - gridSize.y) / 2
    f :Food= {
        getFood(&game),
        Foods.Small,
    }; append(&food, f)
    
    /* Init Snake */
    startPos: [2]i32 = {CELL_COLUMNS / 2 , CELL_ROWS / 2}
    for i in 0..<8 {
        vec : [2]i32 = {startPos.x - i32(i), startPos.y}
        append(&snake.body, vec)
    }
    snake.direction = Direction.Right

    return game
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

    if nPos == body[1] do return

    if checkCollision(nPos, game) {
        game.state = .Death 
        return
    } 
    foodEaten := false

    nextPos =  nPos
    direction = dirct

    if game.frameTimeAcc >= GAME_SPEED {
        lastI := len(body) - 1
        if foodEaten == true {
            append(&body, body[lastI])

        }
        for i := lastI; i > 0; i-=1 {
            body[i] = body[i-1]
        }
        body[0] = nPos
        game.frameTimeAcc -= GAME_SPEED
        game.movesAcc += 1
    }
    for i := 0; i < len(game.food); i += 1 {
        if nPos == game.food[i].pos {
            foodEaten = true
            unordered_remove(&game.food, i)
        } 
    }
}

checkCollision :: proc(nextPos: [2]i32, using game: ^Game) -> (collision: bool) {
    for occupied in snake.body {
        if nextPos == occupied do return true 
    } 
    return false
}

handleInput :: proc(using game: ^Game) {
        if state == .Death {
            if rl.IsKeyPressed(.ENTER){
                game^ = initGame()
            }
            if rl.IsKeyPressed(.Q){
                state = .Quit
            } return
        }else if state == .Paused {
            if rl.IsKeyPressed(.P){
                state = .Running
            } return
        }
        if rl.IsKeyDown(.ESCAPE) || rl.IsKeyDown(.Q) {
            state = .Quit
        }
        if rl.IsKeyDown(.UP) || rl.IsKeyDown(.E) {
            moveSnake(game, .Up)
        }
        if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.D) {
            moveSnake(game, .Down)
        }
        if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.F) {
            moveSnake(game, .Right)
        }
        if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.S) {
            moveSnake(game, .Left)
        }
        if rl.IsKeyPressed(.P) {
            state = .Paused
        }
        else {
            moveSnake(game, snake.direction)
        }
}

getFood :: proc(using game: ^Game) -> [2]i32 {
    rng := rand.create(u64(time.to_unix_nanoseconds(time.now())))
    pos :[2]i32= {
        i32(rand.float32_range(0, CELL_COLUMNS - 1, &rng)),
        i32(rand.float32_range(0, CELL_ROWS - 1, &rng)),
    }
    if checkCollision(pos, game) do getFood(game)
    return pos
}

getColor :: proc(color: u32, alpha:u8= 255) -> rl.Color {
    rgb : rl.Color
    rgb.r = u8(color >> (2*8) & 0xFF)
    rgb.g = u8(color >> (1*8) & 0xFF)
    rgb.b = u8(color >> (0*8) & 0xFF)
    rgb.a = alpha
    return rgb
}

posToPixel :: proc(vec: [2]i32, using game: ^Game) -> [2]i32 {
    pos : [2]i32 
    pos.x = gridPos.x + vec.x * cellSize.x
    pos.y = gridPos.y + vec.y * cellSize.y
    return pos
}

draw :: proc(using game : ^Game) {
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
    if state == .Death {
        color = getColor(Colors["red"], 150)
    }
    for pos in snake.body {
        vec2 := posToPixel(pos, game) 
        rl.DrawRectangle(vec2.x, vec2.y, cellSize.x, cellSize.y, color,)
    }

    /* Draw Food */
    color = getColor(Colors["yellow"], 150)
    for f in food {
        f := posToPixel(f.pos, game) 
        rl.DrawRectangle(f.x, f.y, cellSize.x, cellSize.y, color,)
    }
}
