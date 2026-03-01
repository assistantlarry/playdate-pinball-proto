import "CoreLibs/object"
import "CoreLibs/graphics"

local gfx = playdate.graphics

-- Long-ways table: uses most of the 400px horizontal span.
local PF_X, PF_Y = 8, 20
local PF_W, PF_H = 384, 212

local score = 0
local balls = 3

local ball = {
  x = PF_X + PF_W - 12,
  y = PF_Y + PF_H - 16,
  vx = 0,
  vy = 0,
  r = 4,
  active = false
}

local shooter = {
  laneLeft = PF_X + PF_W - 24,
  x = PF_X + PF_W - 12,
  topGateY = PF_Y + 48
}

local bumpers = {
  {x = PF_X + 120, y = PF_Y + 70, r = 12, points = 100},
  {x = PF_X + 190, y = PF_Y + 108, r = 10, points = 150},
  {x = PF_X + 260, y = PF_Y + 72, r = 12, points = 100},
}

local leftFlipper = {
  bx = PF_X + 155, by = PF_Y + PF_H - 26,
  len = 38, aRest = -0.35, aUp = -0.95,
  up = false
}
local rightFlipper = {
  bx = PF_X + 235, by = PF_Y + PF_H - 26,
  len = 38, aRest = math.pi + 0.35, aUp = math.pi + 0.95,
  up = false
}

local GRAVITY = 0.22
local RESTITUTION = 0.84
local MAX_SPEED = 8.0

local function clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end

local function resetBall()
  ball.x = shooter.x
  ball.y = PF_Y + PF_H - 16
  ball.vx = 0
  ball.vy = 0
  ball.active = false
end

local function launchBall()
  if not ball.active then
    ball.active = true
    -- Launch up the right-side lane.
    ball.vx = 0
    ball.vy = -6.7
  end
end

local function segmentPoint(ax, ay, bx, by, t)
  return ax + (bx - ax) * t, ay + (by - ay) * t
end

local function collideSegment(ax, ay, bx, by, boostX, boostY)
  local px, py = ball.x, ball.y
  local abx, aby = (bx - ax), (by - ay)
  local ab2 = abx*abx + aby*aby
  if ab2 < 0.0001 then return false end

  local apx, apy = (px - ax), (py - ay)
  local t = (apx*abx + apy*aby) / ab2
  t = clamp(t, 0, 1)
  local qx, qy = segmentPoint(ax, ay, bx, by, t)

  local dx, dy = px - qx, py - qy
  local d2 = dx*dx + dy*dy
  local rr = ball.r + 1
  if d2 > rr*rr then return false end

  local d = math.sqrt(d2)
  if d < 0.001 then d = 0.001 end
  local nx, ny = dx / d, dy / d

  -- Push out of collision.
  ball.x = qx + nx * rr
  ball.y = qy + ny * rr

  -- Reflect velocity.
  local dot = ball.vx * nx + ball.vy * ny
  if dot < 0 then
    ball.vx = ball.vx - 2 * dot * nx
    ball.vy = ball.vy - 2 * dot * ny
    ball.vx = ball.vx * RESTITUTION + (boostX or 0)
    ball.vy = ball.vy * RESTITUTION + (boostY or 0)
  end
  return true
end

local function collideCircle(cx, cy, cr, points)
  local dx = ball.x - cx
  local dy = ball.y - cy
  local rr = ball.r + cr
  local d2 = dx*dx + dy*dy
  if d2 > rr*rr then return false end

  local d = math.sqrt(d2)
  if d < 0.001 then d = 0.001 end
  local nx, ny = dx/d, dy/d

  ball.x = cx + nx * rr
  ball.y = cy + ny * rr

  local dot = ball.vx * nx + ball.vy * ny
  ball.vx = (ball.vx - 2 * dot * nx) * RESTITUTION
  ball.vy = (ball.vy - 2 * dot * ny) * RESTITUTION

  -- Punchy bumper feel.
  ball.vx = ball.vx + nx * 0.7
  ball.vy = ball.vy + ny * 0.7
  if points then score += points end
  return true
end

local function flipperSegment(f)
  local a = f.up and f.aUp or f.aRest
  local ex = f.bx + math.cos(a) * f.len
  local ey = f.by + math.sin(a) * f.len
  return f.bx, f.by, ex, ey
end

local function updateFlippers()
  leftFlipper.up = playdate.buttonIsPressed(playdate.kButtonLeft)
  rightFlipper.up = playdate.buttonIsPressed(playdate.kButtonRight)
end

local function collideStaticWalls()
  -- outer boundaries
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

  -- right-side shooter lane divider: keeps launch in lane until top gate.
  if ball.y > shooter.topGateY and ball.x - ball.r < shooter.laneLeft and ball.x > shooter.laneLeft then
    ball.x = shooter.laneLeft + ball.r
    ball.vx = math.abs(ball.vx) * RESTITUTION
  end

  -- top gate kicker to throw ball into main playfield from shooter lane.
  collideCircle(shooter.laneLeft - 7, shooter.topGateY + 2, 8, 50)

  -- simple slingshot rails near lower half
  collideSegment(PF_X + 70, PF_Y + PF_H - 52, PF_X + 126, PF_Y + PF_H - 86)
  collideSegment(PF_X + PF_W - 70, PF_Y + PF_H - 52, PF_X + PF_W - 126, PF_Y + PF_H - 86)
end

local function collideFlippers()
  local lbx, lby, lex, ley = flipperSegment(leftFlipper)
  local rbx, rby, rex, rey = flipperSegment(rightFlipper)

  local lBoostX = leftFlipper.up and -0.65 or 0
  local lBoostY = leftFlipper.up and -1.25 or 0
  local rBoostX = rightFlipper.up and 0.65 or 0
  local rBoostY = rightFlipper.up and -1.25 or 0

  collideSegment(lbx, lby, lex, ley, lBoostX, lBoostY)
  collideSegment(rbx, rby, rex, rey, rBoostX, rBoostY)

  -- stronger tips help responsiveness
  collideCircle(lex, ley, 5, leftFlipper.up and 15 or nil)
  collideCircle(rex, rey, 5, rightFlipper.up and 15 or nil)
end

local function updateBall()
  if not ball.active then return end

  -- Substeps make collisions more reliable at higher speeds.
  local steps = 3
  for _=1,steps do
    ball.vy += GRAVITY / steps
    ball.x += ball.vx / steps
    ball.y += ball.vy / steps

    collideStaticWalls()

    for i=1,#bumpers do
      local b = bumpers[i]
      collideCircle(b.x, b.y, b.r, b.points)
    end

    collideFlippers()
  end

  -- Drain at bottom center area.
  if ball.y - ball.r > PF_Y + PF_H then
    balls -= 1
    if balls < 0 then balls = 3; score = 0 end
    resetBall()
  end

  ball.vx = clamp(ball.vx, -MAX_SPEED, MAX_SPEED)
  ball.vy = clamp(ball.vy, -MAX_SPEED, MAX_SPEED)
end

local function drawFlipper(f)
  local bx, by, ex, ey = flipperSegment(f)
  gfx.setLineWidth(4)
  gfx.drawLine(bx, by, ex, ey)
  gfx.setLineWidth(1)
end

local function draw()
  gfx.clear(gfx.kColorWhite)

  gfx.drawText("Pinball Proto (long-ways)", 10, 2)
  gfx.drawText("Score: " .. tostring(score), 10, 14)
  gfx.drawText("Balls: " .. tostring(math.max(balls,0)), 128, 14)

  gfx.drawRect(PF_X, PF_Y, PF_W, PF_H)

  -- shooter lane visual
  gfx.drawLine(shooter.laneLeft, PF_Y + 50, shooter.laneLeft, PF_Y + PF_H)
  gfx.drawText("lane", shooter.laneLeft + 2, PF_Y + PF_H - 14)

  -- bumpers
  for i=1,#bumpers do
    local b = bumpers[i]
    gfx.drawCircleAtPoint(b.x, b.y, b.r)
    gfx.drawCircleAtPoint(b.x, b.y, b.r + 2)
  end

  drawFlipper(leftFlipper)
  drawFlipper(rightFlipper)

  gfx.fillCircleAtPoint(ball.x, ball.y, ball.r)

  if not ball.active then
    gfx.drawText("A launch  B reset", PF_X + PF_W - 122, PF_Y + PF_H - 14)
  end
end

function playdate.update()
  updateFlippers()

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
