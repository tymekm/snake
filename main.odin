package snake

import "core:fmt"
import "core:time"
import "core:strconv"
import "core:strings"
import "core:math"
import "core:os"
import rl "vendor:raylib"
import rand "core:math/rand"

FPS :: 120
GAME_SPEED :: 8
W_WIDTH, W_HEIGHT :: 1280, 1024
CELL_COLUMNS, CELL_ROWS :: 20, 15
CELLS :: CELL_COLUMNS * CELL_ROWS
FOOD_TIMER :: i32(CELLS * .2)
SCORE_FILE :: "highscore"

GameState    :: enum {Running, Paused, Death, Highscore, Quit}
CellState    :: enum {Empty, Fruit, Obstructed}
SnakeSegment :: enum {Tail, Body, Head, Bend}
Direction    :: enum {Right, Down, Left, Up}
FruitTypes   :: enum {Apple, Mango, SteelCrate, Crate}

Snake :: struct {
    body: [dynamic][2]i32,
    direction: Direction,
    ate: bool,
    moveSpeed: f32,
    velocity: f32,
}

Fruit :: struct {
    pos: [2]i32,
    type: FruitTypes,
    timer: i32,
    opacity: u8,
}

Colors := map[string]u32{
    "windowbg"   = 0x1F1F28,
    "text"       = 0xDCD7BA,
    "snakedead"  = 0xE82424,
    "white"      = 0xFFFFFF,
}

FireworksAnim :: struct {
    delay: f32,
    frames: i32,
    fireworks :[4] Firework,
}

Firework :: struct { 
    timeAcc: f32,
    currentFrame: i32,
    used: bool,
    texture: rl.Texture,
}

Music :: struct {
    maxVolume: f32,
    volume: f32,
    fadeTime: f32,
    track: rl.Music,
    fade : enum {In, Out},
}

cellSize: i32
gridPos:  [2]i32
gridSize: [2]i32
rng : rand.Rand
score:     int
highScore: int
snake:     Snake
fruits:    [dynamic]Fruit
fireworksAnim: FireworksAnim
timeAcc:   f32
gameState: GameState
scoreMultiplier: f32

Textures : map[string]rl.Texture 
font, fontBold : rl.Font
music : Music
Sounds : map[string] rl.Sound

main :: proc() {
    rl.InitWindow(W_WIDTH, W_HEIGHT, "Snake!")
    defer rl.CloseWindow()
    rl.InitAudioDevice()
    rl.SetMasterVolume(1) // 0 to 1
    defer rl.CloseAudioDevice()
    rl.SetTargetFPS(FPS)

    initGame()
    loadAssets()
    for gameState != .Quit {
        rl.BeginDrawing()
        defer rl.EndDrawing()
        updateGame()
        draw()
        rl.DrawFPS(0,0)
    }
}

initGame :: proc() {
    gameState = .Running
    music.maxVolume = 0.1
    music.volume = 0
    music.fadeTime = 2
    rl.SetMusicVolume(music.track, music.volume)
    rl.PlayMusicStream(music.track)

    size := math.round(f32(W_WIDTH) * 0.8 / f32(CELL_COLUMNS))
    cellSize = i32(size)
    gridSize.x  = cellSize * CELL_COLUMNS
    gridSize.y  = cellSize * CELL_ROWS
    gridPos.x   = (W_WIDTH  - gridSize.x) / 2
    gridPos.y   = (W_HEIGHT  - gridSize.y) / 2

    rng = rand.create(u64(time.to_unix_nanoseconds(time.now())))
    score = 0
    snake.moveSpeed = 1 / f32(GAME_SPEED)
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


    fireworksAnim.delay = 0.1
    fireworksAnim.frames = 8
    for firework, it in &fireworksAnim.fireworks {
        using firework
        used = false
        currentFrame = -5 - i32(it)
    }
}

loadAssets :: proc() {
    /* Fonts */
    font = rl.LoadFont("./fonts/8bitOperatorPlus-Regular.ttf")
    fontBold = rl.LoadFont("./fonts/8bitOperatorPlus-Bold.ttf")

    /* Textures */
    appleImg := rl.LoadImage("./textures/apple.png")
    defer rl.UnloadImage(appleImg)
    rl.ImageResize(&appleImg, i32(f32(cellSize) * 0.6), i32(f32(cellSize) * 0.6))
    Textures["apple"] = rl.LoadTextureFromImage(appleImg)

    mangoImg := rl.LoadImage("./textures/mango.png")
    defer rl.UnloadImage(mangoImg)
    rl.ImageResize(&mangoImg, i32(f32(cellSize) * 0.8), i32(f32(cellSize) * 0.8))
    Textures["mango"] = rl.LoadTextureFromImage(mangoImg)

    crateImg := rl.LoadImage("./textures/crate.png")
    defer rl.UnloadImage(crateImg)
    rl.ImageResize(&crateImg, cellSize, cellSize)
    Textures["crate"] = rl.LoadTextureFromImage(crateImg)

    steelCrateImg := rl.LoadImage("./textures/steel-crate.png")
    defer rl.UnloadImage(steelCrateImg)
    rl.ImageResize(&steelCrateImg, cellSize, cellSize)
    Textures["steelCrate"] = rl.LoadTextureFromImage(steelCrateImg)

    snakeImg := rl.LoadImage("./textures/snake.png")
    defer rl.UnloadImage(snakeImg)
    rl.ImageResize(&snakeImg, cellSize * 4, cellSize)
    Textures["snake"] = rl.LoadTextureFromImage(snakeImg)

    grassTileImg := rl.LoadImage("./textures/grass-tile.png")
    defer rl.UnloadImage(grassTileImg)
    rl.ImageResize(&grassTileImg, cellSize*(grassTileImg.width/grassTileImg.height), cellSize)
    Textures["grassTiles"] = rl.LoadTextureFromImage(grassTileImg)

    fireworkAnimImg := rl.LoadImage("./textures/firework.png")
    defer rl.UnloadImage(fireworkAnimImg)
    for firework, it in &fireworksAnim.fireworks {
        if it <= 1 {
            rl.ImageResize(&fireworkAnimImg, cellSize * 10 * fireworksAnim.frames, cellSize * 10)
        }
        else if it >= 2 {
            rl.ImageResize(&fireworkAnimImg, cellSize * 5 * fireworksAnim.frames, cellSize * 5)
        }
        firework.texture = rl.LoadTextureFromImage(fireworkAnimImg)
    }

    /* Music */
    music.track = rl.LoadMusicStream("./audio/Spooky-Island.mp3")
    music.track.looping = true
    rl.PlayMusicStream(music.track)

    /* Sounds */
    Sounds["eating"] = rl.LoadSound("./audio/eating.wav")
    Sounds["collision"] = rl.LoadSound("./audio/collision.wav")
    Sounds["breakcrate"] = rl.LoadSound("./audio/breakcrate.wav")
    Sounds["highscore"] = rl.LoadSound("./audio/highscore.wav")
}

scoreToFile :: proc() {
    scoreFile, errno := os.open(SCORE_FILE, os.O_WRONLY)
    defer os.close(scoreFile)
    buf :[8]byte={}
    str := strconv.itoa(buf[:], score)
    if errno != 0 {
        fmt.println("Could not open file :", SCORE_FILE)
    } else {
        _, errno := os.write_string(scoreFile, str)
        if errno != 0 {
            fmt.println("Could not write to file:", SCORE_FILE, "\nErrno:", errno)
        } 
    }
}

updateGame :: proc() {
    if gameState == .Running && music.volume <= music.maxVolume {
        music.volume += (rl.GetFrameTime() / music.fadeTime) * music.maxVolume
    } else if gameState == .Highscore {
        music.volume = 0
        rl.SeekMusicStream(music.track, 0)
    } else if gameState != .Running && music.volume >= 0 {
        music.volume -= (rl.GetFrameTime() / music.fadeTime) * music.maxVolume
    }
    rl.SetMusicVolume(music.track, music.volume)
    rl.UpdateMusicStream(music.track)

    /* Get Input */
    if gameState == .Death || gameState == .Highscore {
        if rl.IsKeyPressed(.ENTER)  do initGame()
        else if rl.IsKeyPressed(.Q) do gameState = .Quit
        return
    } else if gameState == .Paused {
        if rl.IsKeyPressed(.P) do gameState = .Running
        if rl.IsKeyPressed(.Q) do gameState = .Quit
        return
    }
    else if rl.IsKeyPressed(.P) do gameState = .Paused
    else if rl.IsKeyPressed(.ESCAPE)|| rl.IsKeyPressed(.Q) do gameState = .Quit
    else if gameState != .Running do return

    nextDir: Direction
    if rl.IsKeyPressed(.UP)        || rl.IsKeyPressed(.W) do nextDir = .Up  
    else if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) do nextDir = .Down 
    else if rl.IsKeyPressed(.RIGHT)|| rl.IsKeyPressed(.D) do nextDir = .Right 
    else if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.A) do nextDir = .Left 
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

    moved := false
    if timeAcc >= snake.moveSpeed {
        lastI := len(snake.body) - 1
        if snake.ate == true {
            append(&snake.body, snake.body[lastI])
            snake.ate = false
        }
        for i := lastI; i > 0; i-=1 {
            snake.body[i] = snake.body[i-1]
        }
        if isOccupied(nextPos) == .Obstructed {
            rl.PlaySound(Sounds["eating"])
            rl.PlaySound(Sounds["collision"])
            if score > highScore {
                if highScore == 0 {
                    gameState = .Death
                } else {
                    gameState = .Highscore
                    rl.PlaySound(Sounds["highscore"])
                }
                scoreToFile()
            } else {
                gameState = .Death
            } 
            snake.body[0] = nextPos
            return
        } 
        snake.body[0] = nextPos
        timeAcc -= snake.moveSpeed
        moved = true
    }

    /* Handle Fruit */
    for fruit, it in &fruits {
        if fruit.type != .Apple && fruit.type != .SteelCrate {
            if moved do fruit.timer -= 1
            if fruit.timer == 0 { 
                if fruit.type == .Crate {
                    fruit.type = .SteelCrate
                    fruit.opacity = 255
                }
                else do unordered_remove(&fruits, it)
                continue
            } else if fruit.timer <= i32(math.floor(f32(FOOD_TIMER) * .3)) {
                fruit.opacity += 15
            } 
        }
        if snake.body[0] == fruit.pos {
            if fruit.type != .Crate do snake.ate = true
            if fruit.type == .Apple {
                score += int(math.round(1.0 * scoreMultiplier))
                rl.PlaySound(Sounds["eating"])
            } else if fruit.type == .Mango {
                score += int(math.round(3.0 * scoreMultiplier))
                rl.PlaySound(Sounds["eating"])
            } else if fruit.type == .Crate {
                openCrate()
                rl.PlaySound(Sounds["breakcrate"])
            }
            unordered_remove(&fruits, it)
        } 
    }
    eatable := 0
    for fruit in fruits {
        if fruit.type != .SteelCrate do eatable += 1 
    }
    if eatable == 0 {
        randNum := getRandNum(1,10) 
        fruit : Fruit
        if randNum <= 6 do fruit = getFruit(.Apple)
        else if randNum <= 8  do fruit = getFruit(.Mango)
        else do fruit = getFruit(.Crate)
        append(&fruits, fruit)
    }
    timeAcc += rl.GetFrameTime()
}

isOccupied :: proc(pos: [2]i32) -> CellState {
    for part in snake.body {
        if pos == part do return .Obstructed
    }
    for fruit in fruits {
        if pos == fruit.pos && fruit.type == .SteelCrate do return .Obstructed
        else if pos == fruit.pos do return .Fruit
    } 
    return .Empty
}

openCrate :: proc () {
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

getFruit :: proc(type: FruitTypes) -> Fruit {
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

    drawSegment :: proc(seg: SnakeSegment, pos: ^rl.Vector2, rotation: int, color : rl.Color) {
        snakeTexture := Textures["snake"]
        origin : rl.Vector2
        if rotation == 90 do origin = {0, f32(cellSize)}
        else if rotation == 180 do origin = {f32(cellSize), f32(cellSize)}
        else if rotation == 270 do origin = {f32(cellSize), 0} 
        rl.DrawTexturePro(
            snakeTexture,
            rl.Rectangle {
                f32(snakeTexture.height * i32(seg)),
                0,
                f32(snakeTexture.height),
                f32(snakeTexture.height),
            },
            rl.Rectangle {
                pos.x,
                pos.y,
                f32(snakeTexture.height),
                f32(snakeTexture.height),
            },
            origin,
            f32(rotation),
            color,
        )

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
            drawSegment(.Head, &vec2, rotation, c)
            continue
        } 
        if it == len(body) - 1 {
            front := normaliseForWrap(body[it], body[it-1])
            diff := body[it] - front
            if diff == {-1,0} do rotation = 0
            else if diff == {0,-1} do rotation = 90
            else if diff == {1,0} do rotation = 180
            else if diff == {0,1} do rotation = 270
            drawSegment(.Tail, &vec2, rotation, c)
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
            drawSegment(.Body, &vec2, rotation, c)
        } else {
            diff := (body[it] - front) + (body[it] - back)
            if diff == {1,1} do rotation = 0
            else if diff == {-1,1} do rotation = 90
            else if diff == {-1,-1} do rotation = 180
            else if diff == {1,-1} do rotation = 270
            drawSegment(.Bend, &vec2, rotation, c)
        }
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
    grassTiles := Textures["grassTiles"]
    grassTilesNum := int(grassTiles.width / grassTiles.height)
    for x in 0..<CELL_COLUMNS {
        for y in 0..<CELL_ROWS {
            rnum := getRandNum(1, grassTilesNum)
            rl.DrawTextureRec(
                grassTiles,
                rl.Rectangle {
                   f32(int(cellSize) * int(rand.float32_range(1, f32(grassTilesNum), &grassRng))),
                   0,
                   f32(grassTiles.height),
                   f32(grassTiles.height),
                },
                rl.Vector2{
                    f32(cellSize * i32(x) + gridPos.x),
                    f32(cellSize * i32(y) + gridPos.y)
                },
                rl.WHITE,
            )
        }
    }
    drawSnake()
    c :rl.Color 
    /* Draw Fruit */
    for f in fruits {
        vec2 := posToPixel(f.pos)
        size: rl.Vector2
        if f.type == .Apple {
            c = getColor(Colors["white"], f.opacity)
            apple := Textures["apple"]
            rl.DrawTexture(
                apple,
                vec2.x + cellSize/2 - apple.width/2,
                vec2.y + cellSize/2 - apple.width/2,
                c)
        } else if f.type == .Mango {
            c = getColor(Colors["white"], f.opacity)
            mango := Textures["mango"]
            rl.DrawTexture(
                mango,
                vec2.x + cellSize/2 - mango.width/2,
                vec2.y + cellSize/2 - mango.width/2,
                c)
        }  else if f.type == .SteelCrate {
            c = getColor(Colors["white"], f.opacity)
            steelCrate := Textures["steelCrate"]
            rl.DrawTexture(
                steelCrate,
                vec2.x + cellSize/2 - steelCrate.width/2,
                vec2.y + cellSize/2 - steelCrate.width/2,
                c)
        } else if f.type == .Crate {
            c = getColor(Colors["white"], f.opacity)
            crate := Textures["crate"]
            rl.DrawTexture(
                crate,
                vec2.x + cellSize/2 - crate.width/2,
                vec2.y + cellSize/2 - crate.width/2,
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
    if gameState != .Running {
        rl.DrawRectangle(gridPos.x, gridPos.y, gridSize.x, gridSize.y, getColor(Colors["grey"], 200))
    }
    if gameState == .Paused do drawInfoBox("Paused", "Press 'P' to continue")

    else if gameState == .Death do drawInfoBox("GameOver!", "Press 'Enter' to play again or 'Q' to quit")
    else if gameState == .Highscore {
        drawInfoBox("New Highscore!", "Press 'Enter' to play again or 'Q' to quit")
        fireworkTexture := Textures["fireworkAnim"]
        using fireworksAnim
        for firework, it in &fireworks {
            using firework
            if !used {
                if timeAcc >= delay {
                    currentFrame += 1
                    timeAcc -= delay
                }
                if currentFrame >= 0 {
                    pos : rl.Vector2
                    if it == 0 {
                        pos = {
                           f32(gridPos.x),
                           f32(gridPos.y),
                        }
                    }
                    if it == 1 {
                        pos = {
                           f32(gridPos.x + gridSize.x - texture.width / frames),
                           f32(gridPos.y),
                        }
                    }
                    if it == 2 {
                        pos = {
                           f32(gridPos.x + cellSize * 5),
                           f32(gridPos.y),
                        }
                    }
                    if it == 3 {
                        pos = {
                           f32(gridPos.x + cellSize * 10),
                           f32(gridPos.y + cellSize * 3),
                        }
                    }
                    rl.DrawTextureRec(
                        texture,
                        rl.Rectangle {
                            f32(texture.width / frames * currentFrame), 
                            0, 
                            f32(texture.width / frames),
                            f32(texture.height),
                        },
                        pos,
                        rl.WHITE
                    )

                }
                timeAcc += rl.GetFrameTime()
                if currentFrame == frames - 1 do used = true
            }

        }
   }
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
    infoBoxWidth  := textWidth + 20
    infoBoxHeight := textSize.y + headerSize.y + textPadding + 20
    infoBoxVec2 : rl.Vector2 = {
        W_WIDTH/2 - infoBoxWidth/2,
        W_HEIGHT/2 - infoBoxHeight/2,
    }
    rl.DrawRectangleRec(
         rl.Rectangle {
             infoBoxVec2.x,
             infoBoxVec2.y,
             infoBoxWidth,
             infoBoxHeight,
        },
        c,
    )

    c = getColor(Colors["text"])
    rl.DrawTextEx(fontBold, h, headerPos, hFontSize, 0, c)
    rl.DrawTextEx(font, t, textPos, tFontSize, 0, c)

    if gameState == .Highscore {
        c = rl.GOLD
        buf := [8]byte {}
        s := strings.clone_to_cstring(strconv.itoa(buf[:], score))
        sFontSize := f32(fontBold.baseSize * 3)
        scoreSize := rl.MeasureTextEx(
            fontBold,
            s,
            sFontSize,
            0,
        )
        sPos: rl.Vector2 = {
            f32(gridPos.x + (gridSize.x/2)) - (scoreSize.x / 2),
            infoBoxVec2.y - (scoreSize.y * 2),
        }
        rl.DrawTextEx(fontBold, s, sPos, sFontSize, 0, c)
    }
}
