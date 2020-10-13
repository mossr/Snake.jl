"""
## Gameplay
```julia
using Snake
```
The game will start automatically.
- Hit `esc` to pause the game.
- Resume with `play()` or restart the game with `restart()`

## Controls (wasd)
* `a` and `d` to apply left and right velocity
* `s` to apply down velocity
* `w` to apply up velocity
* `esc` to pause, then `play()` to resume

## Emoji support

To play using emojis, run:

```julia
play(emoji=true)
```

## Other options
- `play(walls=true)`: Restart the game when hitting walls (default `true`)
- `play(size=(20,20))`: Change game field dimensions (default `(20,20)`)
"""
module Snake

# Modified from Chris DeLeon's 4:30 minute Javascript version
# https://youtu.be/xGmXxpIj6vs

export play, restart

# play when running `using Snake`
__init__() = restart()

global const ██ = "██" # Block character
global const KEY_UP = 'w'
global const KEY_LEFT = 'a'
global const KEY_DOWN = 's'
global const KEY_RIGHT = 'd'
global const KEY_ESC = '\e'
global const ─  = "  " # Space character (variable is a box drawing character ASCII 196 ─)

hide_cursor() = print("\e[?25l")
show_cursor() = println("\e[?25h")

const Field = Array{String}

global DEFAULTS = (emoji=false, walls=true, size=(20,20))


function resetstate(; emoji=DEFAULTS.emoji, walls=DEFAULTS.walls, size=DEFAULTS.size, playing=false)
    global gridx, gridy, px, py, ax, ay, xv, yv, trail, tail, PAUSED
    global gridx = size[1] # grid y-size
    global gridy = size[2] # grid x-size
    global px = rand(3:gridx-3) # initial player x-position (with some border-buffer)
    global py = rand(3:gridy-3) # initial player y-position (with some border-buffer)
    global ax = rand(2:gridx-1) # initial apple x-position
    global ay = rand(2:gridy-1) # initial apple y-position
    global xv = yv = 0 # player velocity
    global trail = []
    global starttail = 5
    global tail = starttail
    global PLAYING = playing
    global PAUSED = false
    global EMOJI = emoji
    global DELAY = 0.1
    global MAXTIMEOUT = 30/DELAY
    global TIMEOUT = 0
    global WALLS = walls

    clearscreen()
end


function restart(; kwargs...)
    resetstate(; kwargs...)
    play(; kwargs...)
end


"""
Snake options:
- `emoji = false`: If `true`, play using emojis (requires terminal support)
- `walls = true`: If `true`, restart the game when hitting walls
- `size = (20,20)`: Game field dimensions
"""
function play(; emoji=DEFAULTS.emoji, walls=DEFAULTS.walls, size=DEFAULTS.size)
    global PAUSED, PLAYING, EMOJI, DELAY, TIMEOUT, MAXTIMEOUT, WALLS, gridx, gridy
    EMOJI = emoji
    PAUSED = false
    TIMEOUT = 0
    WALLS = walls
    clearscreen()
    field = resetfield(gridx, gridy, tail-starttail)
    initialize_keyboard_input()
    while !PAUSED && TIMEOUT <= MAXTIMEOUT
        PLAYING = true
        game!(field; emoji=emoji, walls=walls, size=size)
        sleep(DELAY)
    end
    PLAYING = false
    close_keyboard_buffer()
    show_cursor()
    pausegame()
end


function game!(field; walls, kwargs...)
    global gridx, gridy, px, py, ax, ay, xv, yv, trail, tail, PAUSED, DELAY

    PAUSED = keypress()

    hit_wall = false

    # apply velocity
    px += xv
    py += yv

    if px ≤ 1
        hit_wall = true
        px = gridx-1
    end

    if px ≥ gridx
        hit_wall = true
        px = 2
    end

    if py ≤ 1
        hit_wall = true
        py = gridy
    end

    if py > gridy
        hit_wall = true
        py = 2
    end

    for i in 1:length(trail)
        if trail[i].x == px && trail[i].y == py
            tail = starttail # ate tail, restart game
        end
    end
    field = resetfield(gridx, gridy, tail-starttail)

    drawsnake!(field)
    push!(trail, (x=px, y=py))

    while length(trail) > tail
        popfirst!(trail)
    end

    if ax == px && ay == py
        tail += 1
        # random point not on trail
        randapple() = (rand(2:gridx-1), rand(2:gridy-1))
        ax, ay = randapple()
        while in((x=ax, y=ay), trail)
            ax, ay = randapple()
        end
    end

    drawapple!(field)
    drawfield(field, gridx, gridy)

    if walls && hit_wall
        sleep(DELAY)
        resetstate(; playing=true, kwargs...)
    end

    return PAUSED
end


function pausegame()
    global gridx
    pause_msg = "PAUSED: play() to resume"
    w = 2*(gridx-2)
    w = max(length(pause_msg)+2, w)
    println("╔", "─"^w, "╗")
    buff = Int((w-length(pause_msg))/2)
    println("║", " "^buff, pause_msg, " "^buff, "║")
    println("╚", "─"^w, "╝")
end


function resetfield(fw::Int, fh::Int, score) # score::Int
    field = Field(fill(─,fh,fw))
    field[:,1] .= "│"
    field[:,end] .= "│"
    field[end,1]  = "└"
    field[end,2:end-1] .= "──"
    field[end,end] = "┘"
    even = iseven(fw)
    field = vcat(["┌" fill("──", Int(floor((fw-2-3)/2)))... repeat("─", even ? 1 : 2) "SN" "AK" "E!" repeat("─", even ? 3 : 2) fill("──", Int(floor((fw-2-3)/2))-1)... "┐"], field)
    field[2,end] *= "  Score: $score     "
    field
end


function clearscreen()
    println("\33[2J")
    hide_cursor()
    # Move cursor to (1,1), then print a bunch of whitespace, then move cursor to (1,1)
    println("\033[1;1H$(join(fill(repeat(" ", 100),100), "\n"))\033[1;1H")
end


# Move cursor to 1,1, print field, move cursor to end
function drawfield(field, fh, fw)
    # Draw entire field
    print("\033[1;1H$(join(join.([field[i,:] for i in 1:size(field,1)]),"\n"))\033[$(fw+1);$(fh+1)H")
end


# Key input handling
global BUFFER
function initialize_keyboard_input()
    global BUFFER, PLAYING
    ccall(:jl_tty_set_mode, Int32, (Ptr{Cvoid}, Int32), stdin.handle, true)
    BUFFER = Channel{Char}(100)

    @async while PLAYING
        put!(BUFFER, read(stdin, Char))
    end
end


function close_keyboard_buffer()
    ccall(:jl_tty_set_mode, Int32, (Ptr{Cvoid}, Int32), stdin.handle, false)
end


function readinput()
    if isready(BUFFER)
        take!(BUFFER)
    end
end


function keypress()
    global xv, yv, TIMEOUT
    key = readinput()
    if key == KEY_LEFT
        xv, yv = -1, 0
    elseif key == KEY_RIGHT
        xv, yv = 1, 0
    elseif key == KEY_DOWN
        xv, yv = 0, 1
    elseif key == KEY_UP
        xv, yv = 0, -1
    elseif key == KEY_ESC
        return true # game over
    else
        TIMEOUT += 1
        return false
    end
    TIMEOUT = 0
    return false
end


function drawapple!(field)
    global EMOJI, ax, ay
    apple = EMOJI ? "🍎" : "\e[31;1m$██\e[0m"
    field[ay,ax] = apple
end


function drawsnake!(field)
    global EMOJI
    snake = EMOJI ? "🟩" : "\e[32m$██\e[0m"
    for pos in trail
        field[pos.y, pos.x] = snake
    end
end

end # module

