local socket = require("socket")
local json = require("dkjson")

local client
local buffer = ""
local gameState = nil
local inputSendInterval = 1 / 60
local inputSendTimer = 0
local currentInputState = {}

local player1Lives = 3
local player2Lives = 3
local maxLives = 3
local gameActive = false
local gameStarted = false
local winner = nil

local enteringIp = true
local userInputIp = ""
local connectionError = nil

function love.load()
    love.window.setMode(900, 600)
    love.window.setTitle("Contest Client")

    currentInputState = {left = false, right = false, w = false, s = false, r = false, h = false}

    stars = {}
    for i = 1, 100 do
        table.insert(stars, {x = love.math.random(0, 900), y = love.math.random(0, 600), size = love.math.random(1, 3), speed = love.math.random(5, 20)})
    end

    WORLD_WIDTH = 900
    WORLD_HEIGHT = 600
end

function connectToServer(ip)
    client = assert(socket.udp())
    client:settimeout(0)
    client:setpeername(ip, 12345)
    print("Attempting to connect to server at " .. ip)
end

function love.update(dt)
    if enteringIp then return end

    local line, msg = client:receive()
    if line and line ~= "" then
        buffer = line
        local decoded, _, decode_err = json.decode(buffer)
        if decoded then
            gameState = decoded
            player1Lives = gameState.player1Lives
            player2Lives = gameState.player2Lives
            gameActive = gameState.gameActive
            gameStarted = gameState.gameStarted
            winner = gameState.winner
            maxLives = gameState.maxLives
        else
            print("Client JSON error:", decode_err)
        end
    elseif msg == "timeout" then
        -- do nothing
    elseif msg then
        print("Receive error:", msg)
        connectionError = msg
        enteringIp = true
    end

    inputSendTimer = inputSendTimer + dt
    if inputSendTimer >= inputSendInterval and client then
        inputSendTimer = inputSendTimer - inputSendInterval
        currentInputState.left = love.keyboard.isDown("a") or love.keyboard.isDown("left")
        currentInputState.right = love.keyboard.isDown("d") or love.keyboard.isDown("right")
        currentInputState.w = love.keyboard.isDown("w")
        currentInputState.s = love.keyboard.isDown("s")
        currentInputState.r = love.keyboard.isDown("r")
        currentInputState.h = love.keyboard.isDown("h")

        local encodedInput = json.encode(currentInputState)
        local success, err = client:send(encodedInput .. "\n")
        if not success then
            print("Failed to send input:", err)
            client = nil
            enteringIp = true
            connectionError = err
        end
    end

    for _, star in ipairs(stars) do
        star.y = star.y + star.speed * dt
        if star.y > WORLD_HEIGHT then
            star.y = 0
            star.x = love.math.random(0, WORLD_WIDTH)
        end
    end
end

function love.textinput(t)
    if enteringIp then
        userInputIp = userInputIp .. t
    end
end

function love.keypressed(key)
    if enteringIp then
        if key == "backspace" then
            userInputIp = userInputIp:sub(1, -2)
        elseif key == "return" then
            if userInputIp ~= "" then
                connectToServer(userInputIp)
                enteringIp = false
                connectionError = nil
            end
        end
    end
end

function love.draw()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.1)
    love.graphics.setColor(1, 1, 1)
    for _, star in ipairs(stars) do
        love.graphics.circle("fill", star.x, star.y, star.size)
    end

    if enteringIp then
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.print("Enter Server IP: " .. userInputIp, 20, 20)
        if connectionError then
            love.graphics.setColor(1, 0.2, 0.2)
            love.graphics.print("Connection Error: " .. connectionError, 20, 60)
        end
        return
    end

    if not gameState then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Waiting for game state...", 20, 20)
        return
    end

    local ball = gameState.ball
    if ball and gameStarted then
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.circle("fill", ball.x, ball.y, 10)
    end

    local function drawBat(bat)
        if bat and gameStarted then
            love.graphics.push()
            love.graphics.translate(bat.x, bat.y)
            love.graphics.rotate(bat.angle)
            love.graphics.setColor(0.2, 0.5, 1)
            love.graphics.rectangle("fill", -40, -6, 80, 12)
            love.graphics.pop()
        end
    end

    drawBat(gameState.bat1)
    drawBat(gameState.bat2)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Ball Pos: " .. math.floor(ball.x) .. ", " .. math.floor(ball.y), 10, 10)
    love.graphics.print("Input Sent: " .. json.encode(currentInputState), 10, 30)

    love.graphics.print("P1 Lives: ", 10, WORLD_HEIGHT - 60)
    for i = 1, maxLives do
        if i <= player1Lives then
            love.graphics.setColor(1, 0.2, 0.2)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.circle("fill", 100 + (i * 20), WORLD_HEIGHT - 55, 8)
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("P2 Lives: ", 10, WORLD_HEIGHT - 30)
    for i = 1, maxLives do
        if i <= player2Lives then
            love.graphics.setColor(1, 0.2, 0.2)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.circle("fill", 100 + (i * 20), WORLD_HEIGHT - 25, 8)
    end

    love.graphics.setFont(love.graphics.newFont(30))
    if not gameStarted then
        local waitText = "Waiting for game to start..."
        local waitTextWidth = love.graphics.getFont():getWidth(waitText)
        love.graphics.print(waitText, (WORLD_WIDTH - waitTextWidth) / 2, WORLD_HEIGHT / 2 - 30)
    elseif not gameActive then
        local gameOverText = "GAME OVER!"
        local gameOverTextWidth = love.graphics.getFont():getWidth(gameOverText)
        love.graphics.print(gameOverText, (WORLD_WIDTH - gameOverTextWidth) / 2, WORLD_HEIGHT / 2 - 30)

        if winner then
            local winnerText = "Player " .. winner .. " Wins!"
            local winnerTextWidth = love.graphics.getFont():getWidth(winnerText)
            love.graphics.print(winnerText, (WORLD_WIDTH - winnerTextWidth) / 2, WORLD_HEIGHT / 2 + 10)
        end
    end

    love.graphics.setFont(love.graphics.newFont(12))
end
