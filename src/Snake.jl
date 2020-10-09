"""
TODO!


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


function restart(; emoji=false)
    global gs, px, py, tc, ax, ay, xv, yv, trail, tail, PAUSED
    global px = py = 10 # player position
    global gs = tc = 20 # grid size, tile count
    global ax = ay = 15 # apple position
    global xv = yv = 0 # player velocity
    global trail = []
    global starttail = 5
    global tail = starttail
    global PLAYING = false
    global PAUSED = false
    global EMOJI = emoji

    play(emoji=emoji)
end


function play(; emoji=false)
    global PAUSED, PLAYING, EMOJI
    EMOJI = emoji
    PAUSED = false
    clearscreen()
    field = resetfield(gs, gs, tail-starttail)
    initialize_keyboard_input()
    while !PAUSED
        PLAYING = true
        game!(field)
        sleep(0.1)
    end
    PLAYING = false
    close_keyboard_buffer()
    show_cursor()
    pausegame()
end


function game!(field)
    global gs, px, py, tc, ax, ay, xv, yv, trail, tail, PAUSED

    PAUSED = keypress()

    # apply velocity
    px += xv
    py += yv

    if px ≤ 1
        px = tc-1
    end

    if px ≥ tc
        px = 2
    end

    if py ≤ 1
        py = tc
    end

    if py > tc
        py = 2
    end

    for i in 1:length(trail)
        if trail[i].x == px && trail[i].y == py
            tail = starttail # ate tail, restart game
        end
    end
    field = resetfield(gs, gs, tail-starttail)

    drawsnake!(field)
    push!(trail, (x=px, y=py))

    while length(trail) > tail
        popfirst!(trail)
    end

    if ax == px && ay == py
        tail += 1
        # random point not on trail
        ax = rand(setdiff(2:tc-1, map(t->t.x, trail)))
        ay = rand(setdiff(2:tc-1, map(t->t.y, trail)))
    end

    drawapple!(field)
    drawfield(field, gs, gs)

    return PAUSED
end


function pausegame()
    w = 2*(gs-2)
    println("╔", "─"^w, "╗")
    pause_msg = "PAUSED: play() to resume"
    println("║", " "^Int((w-length(pause_msg))/2), pause_msg, " "^Int((w-length(pause_msg))/2), "║")
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
    print("\033[1;1H$(join(join.([field[i,:] for i in 1:size(field,1)]),"\n"))\033[$(fh+1);$(fw+1)H")
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
    global xv, yv
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
    end
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