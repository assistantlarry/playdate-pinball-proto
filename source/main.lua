import "CoreLibs/object"
import "CoreLibs/graphics"

local gfx = playdate.graphics

-- Playfield inside 400x240 screen, designed to feel tall/portrait
local PF_X, PF_Y = 120, 10
local PF_W, PF_H = 160, 220

local score = 0
local ball = {x = PF_X + PF_W/2, y = PF_Y + PF_H - 20, vx = 0, vy = 0, r = 4, active = false}

local bumper = {x = PF_X + PF_W/2, y = PF_Y + 70, r = 12}

local leftFlipper = {x = PF_X + 38, y = PF_Y + PF_H - 26, len = 28, up = false}
local rightFlipper = {x = PF_X + PF_W - 38, y = PF_Y + PF_H - 26, len = 28, up = false}

local GRAVITY = 0.18
local RESTITUTION = 0.82

local function resetBall()
  ball.x = PF_X + PF_W/2
  ball.y = PF_Y + PF_H - 20
  ball.vx = 0
  ball.vy = 0
  ball.active = false
end

local function launchBall()
  if not ball.active then
    ball.active = true
    ball.vx = math.random(-10, 10) / 20
    ball.vy = -4.2
  end
end

local function clamp(v,a,b)
  if v<a then return a end
  if v>b then return b end
  return v
end

local function collideCircle(cx, cy, cr)
  local dx = ball.x - cx
  local dy = ball.y - cy
  local d2 = dx*dx + dy*dy
  local rr = (ball.r + cr)
  if d2 <= rr*rr then
    local d = math.sqrt(d2)
    if d < 0.001 then d = 0.001 end
    local nx, ny = dx/d, dy/d
    ball.x = cx + nx * rr
    ball.y = cy + ny * rr
    local dot = ball.vx*nx + ball.vy*ny
    ball.vx = ball.vx - 2*dot*nx
    ball.vy = ball.vy - 2*dot*ny
    ball.vx *= RESTITUTION
    ball.vy *= RESTITUTION
    return true
  end
  return false
end

local function updateFlipperKick()
  -- simple flipper influence zones
  if leftFlipper.up then
    if collideCircle(leftFlipper.x + 14, leftFlipper.y - 2, 10) then
      ball.vx = ball.vx - 1.1
      ball.vy = ball.vy - 1.5
    end
  end
  if rightFlipper.up then
    if collideCircle(rightFlipper.x - 14, rightFlipper.y - 2, 10) then
      ball.vx = ball.vx + 1.1
      ball.vy = ball.vy - 1.5
    end
  end
end

local function updateBall()
  if not ball.active then return end

  ball.vy += GRAVITY
  ball.x += ball.vx
  ball.y += ball.vy

  -- walls/top
  if ball.x - ball.r < PF_X then
    ball.x = PF_X + ball.r
    ball.vx = -ball.vx * RESTITUTION
  elseif ball.x + ball.r > PF_X + PF_W then
    ball.x = PF_X + PF_W - ball.r
    ball.vx = -ball.vx * RESTITUTION
  end
  if ball.y - ball.r < PF_Y then
    ball.y = PF_Y + ball.r
    ball.vy = -ball.vy * RESTITUTION
  end

  -- bumper
  if collideCircle(bumper.x, bumper.y, bumper.r) then
    score += 100
    ball.vx += math.random(-20,20)/40
    ball.vy -= 0.8
  end

  updateFlipperKick()

  -- drain
  if ball.y - ball.r > PF_Y + PF_H then
    resetBall()
  end

  -- clamp speed a bit
  ball.vx = clamp(ball.vx, -5.2, 5.2)
  ball.vy = clamp(ball.vy, -8.0, 8.0)
end

local function drawFlipper(f, isLeft)
  local y = f.y
  if f.up then y = y - 6 end
  if isLeft then
    gfx.drawLine(f.x, y, f.x + f.len, y - (f.up and 4 or 0))
  else
    gfx.drawLine(f.x, y, f.x - f.len, y - (f.up and 4 or 0))
  end
end

local function draw()
  gfx.clear(gfx.kColorWhite)

  gfx.drawText("Pinball Proto", 10, 10)
  gfx.drawText("Score: " .. tostring(score), 10, 28)

  -- field
  gfx.drawRect(PF_X, PF_Y, PF_W, PF_H)
  gfx.drawLine(PF_X, PF_Y + PF_H - 14, PF_X + PF_W, PF_Y + PF_H - 14)

  -- bumper
  gfx.drawCircleAtPoint(bumper.x, bumper.y, bumper.r)

  -- flippers
  drawFlipper(leftFlipper, true)
  drawFlipper(rightFlipper, false)

  -- ball
  gfx.fillCircleAtPoint(ball.x, ball.y, ball.r)

  if not ball.active then
    gfx.drawText("A: Launch", PF_X + 42, PF_Y + PF_H - 12)
  end
end

function playdate.update()
  leftFlipper.up = playdate.buttonIsPressed(playdate.kButtonLeft)
  rightFlipper.up = playdate.buttonIsPressed(playdate.kButtonRight)

  if playdate.buttonJustPressed(playdate.kButtonA) then
    launchBall()
  end
  if playdate.buttonJustPressed(playdate.kButtonB) then
    resetBall()
  end

  updateBall()
  draw()
end

math.randomseed(playdate.getSecondsSinceEpoch())
resetBall()
