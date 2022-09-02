package snake

import "core:fmt"
import "core:time"
import "core:strconv"
import "core:strings"
import "core:math"
import "core:os"
import rl "vendor:raylib"
import rand "core:math/rand"

FPS :: 60
GAME_SPEED :: 10
/* W_WIDTH, W_HEIGHT :: 800, 600 */
W_WIDTH, W_HEIGHT :: 1280, 1024
CELL_COLUMNS, CELL_ROWS :: 20, 15
CELLS :: CELL_COLUMNS * CELL_ROWS
FOOD_TIMER :: i32(CELLS * .2)
SCORE_FILE :: "highscore"

GameState :: enum {Running, Paused, Death, Highscore, Quit}
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
FruitsTypes :: enum {Apple, Mango, SteelBox, Box}


Colors := map[string]u32{
    "windowbg"   = 0x1F1F28,
    /* "windowbg"   = 0x2A2A37, */
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

cellSize: i32
gridPos:  [2]i32
gridSize: [2]i32
rng : rand.Rand
score:     int
highScore: int
snake:     Snake
fruits:    [dynamic]Fruit
timeAcc:   f32
gameState: GameState
moveSpeed: f32
scoreMultiplier: f32

Textures : map[string]rl.Texture 
font, fontBold : rl.Font

main :: proc() {
    rl.InitWindow(W_WIDTH, W_HEIGHT, "Snake!")
    defer rl.CloseWindow()
    rl.SetTargetFPS(FPS)

    initGame()
    loadAssets()
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
    size := math.round(f32(W_WIDTH) * 0.8 / f32(CELL_COLUMNS))
    cellSize = i32(size)
    gridSize.x  = cellSize * CELL_COLUMNS
    gridSize.y  = cellSize * CELL_ROWS
    gridPos.x   = (W_WIDTH  - gridSize.x) / 2
    gridPos.y   = (W_HEIGHT  - gridSize.y) / 2

    rng = rand.create(u64(time.to_unix_nanoseconds(time.now())))
    if score > highScore do scoreToFile()
    score = 0
    moveSpeed = 1 / f32(GAME_SPEED)
    scoreMultiplier = math.pow(f32(GAME_SPEED), 1.5)
    snake.body = {}
    snake.direction = Direction.Right
    startPos: [2]i32 = {CELL_COLUMNS / 2 , CELL_ROWS / 2}

    for i in 0..<8 {
        vec : [2]i32 = {startPos.x - i32(i), startPos.y}
        append(&snake.body, vec)
    }
    fruits = {}
    append(&fruits, getFruit(.Apple))

    scoreFile, errno := os.open(SCORE_FILE)
    defer os.close(scoreFile)
    data, ok := os.read_entire_file(scoreFile, context.allocator)

    if errno != 0 {
        data : [0]byte = {}
        created := os.write_entire_file(SCORE_FILE, data[:])
        if created do fmt.println("Created", SCORE_FILE, "file")
        else do fmt.println("Could not create", SCORE_FILE, "file")
    }
    else do highScore = strconv.atoi(string(data))
}

scoreToFile :: proc() {
    scoreFile, errno := os.open(SCORE_FILE, os.O_WRONLY)
    defer os.close(scoreFile)
    buf :[8]byte={}
    str := strconv.itoa(buf[:], score)
    /* str := transmute(string)highScore */
    if errno != 0 {
        fmt.println("Could not open file :", SCORE_FILE)
    } else {
        _, errno := os.write_string(scoreFile, str)
        if errno != 0 {
            fmt.println("Could not write to file:", SCORE_FILE, "\nErrno:", errno)
        } 
    }
}

loadAssets :: proc() {
    font = rl.LoadFont("./fonts/8bitOperatorPlus-Regular.ttf")
    fontBold = rl.LoadFont("./fonts/8bitOperatorPlus-Bold.ttf")
    appleImg := rl.LoadImage("./textures/apple.png")
    rl.ImageResize(&appleImg, i32(f32(cellSize) * 0.6), i32(f32(cellSize) * 0.6))
    Textures["apple"] = rl.LoadTextureFromImage(appleImg)
    mangoImg := rl.LoadImage("./textures/mango.png")
    rl.ImageResize(&mangoImg, i32(f32(cellSize) * 0.8), i32(f32(cellSize) * 0.8))
    Textures["mango"] = rl.LoadTextureFromImage(mangoImg)
    boxImg := rl.LoadImage("./textures/box.png")
    rl.ImageResize(&boxImg, i32(f32(cellSize) * 1.1), i32(f32(cellSize) * 1.1))
    Textures["box"] = rl.LoadTextureFromImage(boxImg)
    snakebodyImg := rl.LoadImage("./textures/snake-body.png")
    rl.ImageResize(&snakebodyImg, cellSize, cellSize)
    Textures["snakebody"] = rl.LoadTextureFromImage(snakebodyImg)
    snaketailImg := rl.LoadImage("./textures/snake-tail.png")
    rl.ImageResize(&snaketailImg, cellSize, cellSize)
    Textures["snaketail"] = rl.LoadTextureFromImage(snaketailImg)
    snakeheadImg := rl.LoadImage("./textures/snake-head.png")
    rl.ImageResize(&snakeheadImg, cellSize, cellSize)
    Textures["snakehead"] = rl.LoadTextureFromImage(snakeheadImg)
    snakebendImg := rl.LoadImage("./textures/snake-bend.png")
    rl.ImageResize(&snakebendImg, cellSize, cellSize)
    Textures["snakebend"] = rl.LoadTextureFromImage(snakebendImg)
    grassTileImg := rl.LoadImage("./textures/grass-tile.png")
    rl.ImageResize(&grassTileImg, cellSize*4, cellSize)
    Textures["grassTiles"] = rl.LoadTextureFromImage(grassTileImg)
}


updateGame :: proc() {
    /* Get Input */
    if gameState == .Death || gameState == .Highscore {
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
            if score > highScore && highScore != 0 do gameState = .Highscore 
            else do gameState = .Death 
            snake.body[0] = nextPos
            return
        } 
        snake.body[0] = nextPos
        timeAcc -= moveSpeed
        snake.moved = true
    }

    /* Handle Fruit */
    for fruit, it in &fruits {
        if fruit.type != .Apple && fruit.type != .SteelBox {
            if snake.moved do fruit.timer -= 1
            if fruit.timer == 0 { 
                if fruit.type == .Box {
                    fruit.type = .SteelBox
                    fruit.opacity = 255
                }
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
            } else if fruit.type == .Box do openBox()
            unordered_remove(&fruits, it)
        } 
    }
    eatable := 0
    for fruit in fruits {
        if fruit.type != .Box && fruit.type != .SteelBox do eatable += 1 
    }
    if eatable == 0 {
        randNum := getRandNum(1,10) 
        fruit : Fruit
        if randNum <= 6 do fruit = getFruit(.Apple)
        else if randNum <= 8  do fruit = getFruit(.Mango)
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
        if pos == fruit.pos && fruit.type == .SteelBox do return .Obstructed
        else if pos == fruit.pos do return .Fruit
    } 
    return .Empty
}

openBox :: proc () {
    foodSpawned:=false
    for i in 0..=5 {
        if getRandNum(0,3) == 0 {
            randNum := getRandNum(1,10)
            if randNum <= 4 do append(&fruits, getFruit(.Apple))
            else do append(&fruits, getFruit(.Mango))
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

posToPixel :: proc(vec: [2]i32) -> [2]i32 {
    x := i32(gridPos.x) + vec.x * cellSize
    y := i32(gridPos.y) + vec.y * cellSize
    return {x, y}
}

drawSnake :: proc() {
    using snake
    c :rl.Color 
    if gameState == .Death || gameState == .Highscore {
        c = getColor(Colors["snakedead"], 255)
    } else {
        c = getColor(Colors["white"], 255)
    }
    for pos, it in body {
        vec2 : rl.Vector2
        vec2.x = f32(posToPixel(pos).x)
        vec2.y = f32(posToPixel(pos).y)
        rotation : int
        if it == 0 {
            back := normaliseForWrap(body[it], body[it+1])
            diff := body[it] - back
            if diff == {1,0} do rotation = 0
            else if diff == {0,1} do rotation = 90
            else if diff == {-1,0} do rotation = 180
            else if diff == {0,-1} do rotation = 270
            adjustForRotation(&vec2, rotation)
            rl.DrawTextureEx(Textures["snakehead"], vec2, f32(rotation), 1, c)
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
            rl.DrawTextureEx(Textures["snaketail"], vec2, f32(rotation), 1, c)
            continue
        } 
        front := normaliseForWrap(body[it], body[it-1])
        back := normaliseForWrap(body[it], body[it+1])
        if (body[it] - front) + (body[it] - back) == 0 {
            diff := front - back
            if diff == {2,0} do rotation = 0
            else if diff == {0,2} do rotation = 90
            else if diff == {-2,0} do rotation = 180
            else if diff == {0,-2} do rotation = 270
            adjustForRotation(&vec2, rotation)
            rl.DrawTextureEx(Textures["snakebody"], vec2, f32(rotation), 1, c)
        } else {
            diff := (body[it] - front) + (body[it] - back)
            if diff == {1,1} do rotation = 0
            else if diff == {-1,1} do rotation = 90
            else if diff == {-1,-1} do rotation = 180
            else if diff == {1,-1} do rotation = 270
            adjustForRotation(&vec2, rotation)
            rl.DrawTextureEx(Textures["snakebend"], vec2, f32(rotation), 1, c)
        }
    }
    adjustForRotation :: proc(pos: ^rl.Vector2, rotation: int) {
        if rotation == 90 do pos.x += f32(cellSize)
        else if rotation == 180 { pos.x += f32(cellSize); pos.y += f32(cellSize)}
        else if rotation == 270 do pos.y += f32(cellSize)
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
    rl.ClearBackground(getColor(Colors["windowbg"]))
    grassRng := rand.create(0)
    for x in 0..<CELL_COLUMNS {
        for y in 0..<CELL_ROWS {
            rnum := getRandNum(1,5)
            rl.DrawTextureRec(
                Textures["grassTiles"],
                rl.Rectangle {
                   f32(int(cellSize) * int(rand.float32_range(1,5,&grassRng))),
                   0,
                   f32(cellSize),
                   f32(cellSize),
                },
                rl.Vector2{
                    f32(int(cellSize) * x + int(gridPos.x)),
                    f32(int(cellSize) * y + int(gridPos.y))
                },
                rl.WHITE,
            )
        }
    }

    /* Draw Play Field */
    /* outerRec := rl.Rectangle { */
    /*     f32(gridPos.x), f32(gridPos.y), */
    /*     f32(gridSize.x), f32(gridSize.y), */
    /* } */

    /* gridbg := getColor(Colors["gridbg"], 255) */
    /* /* rl.DrawRectangleRec( outerRec, gridbg) */ */
    /* inLineC := getColor(Colors["gridlines"], 255) */
    /* rl.DrawRectangleLinesEx(outerRec, 1, inLineC) */
    /* outLineC := getColor(Colors["gridborder"], 50) */
    /* outLineC := rl.BLACK */
    /* for i in 1..<CELL_COLUMNS { */
    /*     i := i32(i) */
    /*     rl.DrawLine( */
    /*         gridPos.x + i32(i) * cellSize, */
    /*         gridPos.y, */
    /*         gridPos.x + i32(i) * cellSize, */
    /*         gridPos.y + gridSize.y, */
    /*         outLineC, */
    /*     )  */
    /* } */
    /* for i in 1..<CELL_ROWS { */
    /*    rl.DrawLine( */
    /*         gridPos.x, */
    /*         gridPos.y + i32(i) * cellSize, */
    /*         gridPos.x + gridSize.x, */
    /*         gridPos.y + i32(i) * cellSize, */
    /*         outLineC */
    /*    )  */
    /* } */
    drawSnake()
    c :rl.Color 
    /* Draw Fruit */
    for f in fruits {
        vec2 := posToPixel(f.pos)
        size: rl.Vector2
        if f.type == .Apple {
            c = getColor(Colors["white"], f.opacity)
            rl.DrawTexture(
                Textures["apple"],
                vec2.x + cellSize/2 - Textures["apple"].width/2,
                vec2.y + cellSize/2 - Textures["apple"].width/2,
                c)
        } else if f.type == .Mango {
            c = getColor(Colors["white"], f.opacity)
            rl.DrawTexture(
                Textures["mango"],
                vec2.x + cellSize/2 - Textures["mango"].width/2,
                vec2.y + cellSize/2 - Textures["mango"].width/2,
                c)
        }  else if f.type == .SteelBox {
            c = getColor(Colors["grey"], f.opacity)
            rl.DrawTexture(
                Textures["box"],
                vec2.x + cellSize/2 - Textures["box"].width/2,
                vec2.y + cellSize/2 - Textures["box"].width/2,
                c)
        } else if f.type == .Box {
            c = getColor(Colors["white"], f.opacity)
            rl.DrawTexture(
                Textures["box"],
                vec2.x + cellSize/2 - Textures["box"].width/2,
                vec2.y + cellSize/2 - Textures["box"].width/2,
                c)
        }
    }

    /* Draw Title */
    c = getColor(Colors["text"])

    fSize :f32= 25

    text :cstring= "Snake!"
    fontSize := f32(fontBold.baseSize) * 1.7
    spacing :f32= 3
    textSizeVec2 := rl.MeasureTextEx(fontBold, text, fontSize, spacing)
    vec2 := rl.Vector2 {
        f32(W_WIDTH) / 2.0 - textSizeVec2.x / 2.0,
        f32(gridPos.y/2) - textSizeVec2.y/2,
    }
    rl.DrawTextEx(fontBold, text, vec2, fontSize, spacing ,c)

    /* Draw Score */
    buf :[8]byte={}
    scoreStr := strings.join({
        "Score", strconv.itoa(buf[:], score)},
        ": ",
    )
    defer delete(scoreStr)
    text = strings.clone_to_cstring(scoreStr)
    fontSize = f32(font.baseSize) * 1.2
    spacing = 0
    textSizeVec2 = rl.MeasureTextEx(font, text, fontSize, spacing)
    vec2 = rl.Vector2 {
        f32(gridPos.x + gridSize.x) - textSizeVec2.x,
        f32(gridPos.y) - textSizeVec2.y - 10,
    }
    rl.DrawTextEx(font, text, vec2, fontSize, spacing ,c)

    highScoreStr := strings.join({
        "HighScore", strconv.itoa(buf[:], highScore)},
        ": ",)
    defer delete(highScoreStr)
    text = strings.clone_to_cstring(highScoreStr)
    fontSize = f32(font.baseSize) * 1.2
    spacing = 0
    textSizeVec2 = rl.MeasureTextEx(font, text, fontSize, spacing)
    vec2 = rl.Vector2 {
        f32(gridPos.x),
        f32(gridPos.y) - textSizeVec2.y - 10,
    }
    rl.DrawTextEx(font, text, vec2, fontSize, spacing ,c)
    if gameState == .Paused do drawInfoBox("Paused", "Press 'P' to continue")
    if gameState == .Death do drawInfoBox("GameOver!", "Press 'Enter' to play again or 'Q' to quit")
    if gameState == .Highscore do drawInfoBox("New Highscore!", "Press 'Enter' to play again or 'Q' to quit")
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
