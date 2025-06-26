local socket = require("socket")
local json = require("dkjson")

local server  
local clientList = {} -- [ip:port] = {ip, port, playerId}
local debugText = {
    [1] = "",
    [2] = ""
}
local inputStates = {
    [1] = {left = false, right = false, w = false, s = false, r = false, h = false},
    [2] = {left = false, right = false, w = false, s = false, r = false, h = false}
}
local lastClientInputStates = {
    [1] = {left = false, right = false, w = false, s = false, r = false, h = false},
    [2] = {left = false, right = false, w = false, s = false, r = false, h = false}
}

local sendInterval = 1 / 60
local sendTimer = 0

local batMoveImpulse = 1000
local batDamping = 0.99

local player1Lives = 3
local player2Lives = 3
local maxLives = 3
local restartDelay = 3  -- seconds
local restartTimer = 0  -- counts after game over

local preStartDelay = 3  -- seconds
local preStartTimer = 0  -- counts time before first game starts
local waitingToStart = false  -- flag for the initial delay

local gameActive = false
local gameStarted = false
local winner = nil
local initialBallSpeed = 300
local ballNeedsReset = false

function love.load()
    love.window.setMode(900, 600)
    love.window.setTitle("Contest Engine - Server (Multi-Client)")

    server = socket.udp()
    server:setsockname("*", 12345)
    server:settimeout(0)

    WORLD_WIDTH = 900
    WORLD_HEIGHT = 600
    world = love.physics.newWorld(0, 0, true)
    world:setCallbacks(beginContact)

    local wallThickness = 10
    walls = {
        left = createWall(-wallThickness / 2, WORLD_HEIGHT / 2, wallThickness, WORLD_HEIGHT),
        right = createWall(WORLD_WIDTH + wallThickness / 2, WORLD_HEIGHT / 2, wallThickness, WORLD_HEIGHT),
        top = createWall(WORLD_WIDTH / 2, -wallThickness / 2, WORLD_WIDTH, wallThickness),
        bottom = createWall(WORLD_WIDTH / 2, WORLD_HEIGHT + wallThickness / 2, WORLD_WIDTH, wallThickness)
    }

    ball = {
        body = love.physics.newBody(world, WORLD_WIDTH / 2, WORLD_HEIGHT / 2, "dynamic"),
        shape = love.physics.newCircleShape(10)
    }
    ball.fixture = love.physics.newFixture(ball.body, ball.shape, 1)
    ball.fixture:setRestitution(0.8)
    ball.fixture:setUserData("ball")

    bat1 = {
        body = love.physics.newBody(world, 450, 50, "dynamic"),
        shape = love.physics.newRectangleShape(80, 12)
    }
    bat1.fixture = love.physics.newFixture(bat1.body, bat1.shape, 2)
    bat1.body:setFixedRotation(true)
    bat1.fixture:setUserData("bat1")

    bat2 = {
        body = love.physics.newBody(world, 450, 550, "dynamic"),
        shape = love.physics.newRectangleShape(80, 12)
    }
    bat2.fixture = love.physics.newFixture(bat2.body, bat2.shape, 2)
    bat2.body:setFixedRotation(true)
    bat2.fixture:setUserData("bat2")

    walls.top.fixture:setUserData("topWall")
    walls.bottom.fixture:setUserData("bottomWall")
    walls.left.fixture:setUserData("sideWall")
    walls.right.fixture:setUserData("sideWall")

    stars = {}
    for i = 1, 100 do
        table.insert(stars, {
            x = love.math.random(0, WORLD_WIDTH),
            y = love.math.random(0, WORLD_HEIGHT),
            size = love.math.random(1, 3),
            speed = love.math.random(5, 20)
        })
    end
end

function table.copy(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = type(v) == "table" and table.copy(v) or v
    end
    return t2
end

function resetBall()
    ball.body:setPosition(WORLD_WIDTH / 2, WORLD_HEIGHT / 2)
    ball.body:setLinearVelocity(0, 0)

    local speed = initialBallSpeed
    local direction = love.math.random(1, 2)
    local angle
    if direction == 1 then
        angle = love.math.random() * (math.pi * 0.5) + (math.pi * 1.25)
    else
        angle = love.math.random() * (math.pi * 0.5) + (math.pi * 0.25)
    end
    ball.body:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)
end

function beginContact(a, b, contact)
    local fixtureA, fixtureB = a:getUserData(), b:getUserData()
    local ballFixture, wallFixture

    if fixtureA == "ball" then
        ballFixture, wallFixture = a, fixtureB
    elseif fixtureB == "ball" then
        ballFixture, wallFixture = b, fixtureA
    end

    if ballFixture and (wallFixture == "topWall" or wallFixture == "bottomWall") then
        if gameActive then
            if wallFixture == "topWall" then
                player1Lives = player1Lives - 1
                print("Ball hit top wall! Player 1 lives: " .. player1Lives)
            elseif wallFixture == "bottomWall" then
                player2Lives = player2Lives - 1
                print("Ball hit bottom wall! Player 2 lives: " .. player2Lives)
            end

            if player1Lives <= 0 then
                winner = 2
                gameActive = false
                restartTimer = 0
                print("Game Over! Player 2 Wins!")
            elseif player2Lives <= 0 then
                winner = 1
                gameActive = false
                restartTimer = 0
                print("Game Over! Player 1 Wins!")
            end


            ballNeedsReset = true
        end
    end
end

function handleBatInput(bat, input, lastInput)
    local vx, vy = bat.body:getLinearVelocity()
    if input.left and not lastInput.left then
        print("Halo")
        bat.body:applyLinearImpulse(-batMoveImpulse, 0)
    elseif input.right and not lastInput.right then
         print("Hola")
        bat.body:applyLinearImpulse(batMoveImpulse, 0)
    end
    if input.w and not lastInput.w then
         print("Ohayo")
        bat.body:applyLinearImpulse(0, -batMoveImpulse)
    elseif input.s and not lastInput.s then
         print("Bonjour")
        bat.body:applyLinearImpulse(0, batMoveImpulse)
    end
    bat.body:setLinearDamping(2) -- Try values like 1 to 5
    -- bat.body:setLinearVelocity(vx * batDamping, vy * batDamping)
end

function enforceBounds(bat)
    local x, y = bat.body:getPosition()
    local vx, vy = bat.body:getLinearVelocity()
    local halfW, halfH = 40, 6

    if x < halfW then
        bat.body:setPosition(halfW, y)
        bat.body:setLinearVelocity(0, vy)
    elseif x > WORLD_WIDTH - halfW then
        bat.body:setPosition(WORLD_WIDTH - halfW, y)
        bat.body:setLinearVelocity(0, vy)
    end

    if y < halfH then
        bat.body:setPosition(x, halfH)
        bat.body:setLinearVelocity(vx, 0)
    elseif y > WORLD_HEIGHT - halfH then
        bat.body:setPosition(x, WORLD_HEIGHT - halfH)
        bat.body:setLinearVelocity(vx, 0)
    end
end

function love.update(dt)
    world:update(dt)
    -- Auto-restart game after delay
    if not gameActive and gameStarted and winner then
        restartTimer = restartTimer + dt
        if restartTimer >= restartDelay then
            player1Lives = maxLives
            player2Lives = maxLives
            winner = nil
            restartTimer = 0
            gameActive = true
            resetBall()
            print("Game restarted automatically.")
        end
    end

    local readyPlayers = 0
    for _, client in pairs(clientList) do
        if client.playerId == 1 or client.playerId == 2 then
            readyPlayers = readyPlayers + 1
        end
    end
    if readyPlayers == 2 and not gameStarted then
        restartTimer = restartTimer + dt 
        if restartTimer >= restartDelay then
            gameStarted = true
            gameActive = true
            restartTimer = 0
            resetBall()
        end
        print("Both clients connected. Game starting!")
    end

    if ballNeedsReset then
        ballNeedsReset = false
        if gameActive then
            resetBall()
        else
            ball.body:setLinearVelocity(0, 0)
        end
    end

    while true do
        local data, ip, port = server:receivefrom()
        if not data then break end
        local key = ip .. ":" .. port
        local decoded, _, err = json.decode(data)
        if decoded then
            if not clientList[key] then
                local currentCount = 0
                for _ in pairs(clientList) do currentCount = currentCount + 1 end
                if currentCount < 2 then
                    local playerId = currentCount + 1
                    clientList[key] = {ip = ip, port = port, playerId = playerId}
                    print("Registered Player " .. playerId .. " at " .. key)
                else
                    print("Extra client attempted to join:", key)
                end
            end
            local client = clientList[key]
            if client then
                inputStates[client.playerId] = decoded
                -- clientInputStates[client.playerId] = decoded
                debugText[client.playerId] = "Player " .. client.playerId .. ": " .. data
            end
        else
            print("Invalid JSON from", key, ":", err)
        end
    end

    if gameActive then
        handleBatInput(bat1, inputStates[1], lastClientInputStates[1])
        handleBatInput(bat2, inputStates[2], lastClientInputStates[2])
        enforceBounds(bat1)
        enforceBounds(bat2)

        if inputStates[1].r and not lastClientInputStates[1].r then
           bat1.body:applyTorque(10)
        elseif inputStates[1].h and not lastClientInputStates[1].h then
            bat1.body:setAngle(0)
        end

        if inputStates[2].r and not lastClientInputStates[2].r then
            bat2.body:applyTorque(10)
        elseif inputStates[2].h and not lastClientInputStates[2].h then
            bat2.body:setAngle(0)
        end
    end

    for _, star in ipairs(stars) do
        star.y = star.y + star.speed * dt
        if star.y > WORLD_HEIGHT then
            star.y = 0
            star.x = love.math.random(0, WORLD_WIDTH)
        end
    end

    sendTimer = sendTimer + dt
    if sendTimer >= sendInterval then
        sendTimer = sendTimer - sendInterval
        local ball_vx, ball_vy = ball.body:getLinearVelocity()
        local state = {
            ball = {x = ball.body:getX(), y = ball.body:getY(), vx = ball_vx, vy = ball_vy},
            bat1 = {x = bat1.body:getX(), y = bat1.body:getY(), angle = bat1.body:getAngle()},
            bat2 = {x = bat2.body:getX(), y = bat2.body:getY(), angle = bat2.body:getAngle()},
            player1Lives = player1Lives,
            player2Lives = player2Lives,
            gameActive = gameActive,
            gameStarted = gameStarted,
            winner = winner,
            maxLives = maxLives
        }
        local encoded = json.encode(state)
        for _, client in pairs(clientList) do
            server:sendto(encoded, client.ip, client.port)
        end
    end

    for i = 1, 2 do
        lastClientInputStates[i] = table.copy(inputStates[i])
    end
end

function love.draw()
    -- love.graphics.setBackgroundColor(0.1, 0.1, 0.1)
    -- love.graphics.setColor(1, 1, 1)
    -- love.graphics.setColor(0.4, 0.4, 0.5)

    -- love.graphics.polygon("fill", walls.left.body:getWorldPoints(walls.left.shape:getPoints()))

    -- love.graphics.polygon("fill", walls.right.body:getWorldPoints(walls.right.shape:getPoints()))

    -- love.graphics.polygon("fill", walls.top.body:getWorldPoints(walls.top.shape:getPoints()))

    -- love.graphics.polygon("fill", walls.bottom.body:getWorldPoints(walls.bottom.shape:getPoints()))

    -- love.graphics.setColor(1, 0.2, 0.2)

    -- love.graphics.circle("fill", ball.body:getX(), ball.body:getY(), ball.shape:getRadius())

    -- love.graphics.setColor(0.2, 0.5, 1)

    -- love.graphics.polygon("fill", bat1.body:getWorldPoints(bat1.shape:getPoints()))

    -- love.graphics.polygon("fill", bat2.body:getWorldPoints(bat2.shape:getPoints()))

    -- love.graphics.setColor(1, 1, 1)

    -- for _, star in ipairs(stars) do

    --     love.graphics.circle("fill", star.x, star.y, star.size)

    -- end

    love.graphics.setColor(1, 1, 1)

    love.graphics.print("Ball: "..math.floor(ball.body:getX())..", "..math.floor(ball.body:getY()), 10, 10)
    love.graphics.setFont(love.graphics.newFont(20))

    love.graphics.print("P1 Lives: " .. player1Lives .. "/" .. maxLives, WORLD_WIDTH - 150, 10)
    love.graphics.print("P2 Lives: " .. player2Lives .. "/" .. maxLives, WORLD_WIDTH - 150, 30)

    if not gameStarted then
        love.graphics.print("Waiting for 2 clients to join...", (WORLD_WIDTH - 280) / 2, WORLD_HEIGHT / 2 - 20)
    elseif not gameActive and winner then
        love.graphics.print("GAME OVER!", (WORLD_WIDTH - 120) / 2, WORLD_HEIGHT / 2 - 20)
        love.graphics.print("Player " .. winner .. " Wins!", (WORLD_WIDTH - 150) / 2, WORLD_HEIGHT / 2 + 10)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(debugText[1], 10, WORLD_HEIGHT - 40)
    love.graphics.print(debugText[2], 10, WORLD_HEIGHT - 20)



    love.graphics.setFont(love.graphics.newFont(12))
end

function love.keypressed(key)
    -- Reserved for debug/admin controls
    -- if key == "a" then
    --     bat1.body:applyLinearImpulse(-batMoveImpulse, 0)
    -- end
    -- local vx, vy = bat1.body:getLinearVelocity()
    -- if key == "d" then
    --     bat1.body:applyLinearImpulse(batMoveImpulse, 0)
    -- end
    -- if key == "w" then
    --     print("Ohayo")
    --     bat1.body:applyLinearImpulse(-batMoveImpulse, 0)
    -- end
    -- if key == "s" then
    --      print("Bonjour")
    --     bat1.body:applyLinearImpulse(0, batMoveImpulse)
    -- end
    -- bat1.body:setLinearVelocity(vx * batDamping, vy * batDamping)

end

function createWall(x, y, width, height)
    local wall = {
        body = love.physics.newBody(world, x, y, "static"),
        shape = love.physics.newRectangleShape(width, height)
    }
    wall.fixture = love.physics.newFixture(wall.body, wall.shape, 0)
    wall.fixture:setRestitution(0.5)
    return wall
end

