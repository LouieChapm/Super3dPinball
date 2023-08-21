pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- init

GRAVITY =  .1
DEBUG = ""
deltaTime = 1

LEFT_FLIPPER,RIGHT_FLIPPER = false, false
FLIPPER_SPEED = .2

PHYSICS_SPEED = 1
PHYSICS_STEPS = 16

STOP_SIM = false
BALL_RADIUS = 4.5

function _init()
	t=0

	palt(0,false)
	palt(15,true)


	BALLS={}
	new_ball(30,50)
	
	WALLS={}
	new_wall(10,70,40,80)
	new_wall(90,80,118,70)

	new_wall(0,0,10,70)
	new_wall(118,70,128,0)

	new_wall(64,-20,0,0)
	new_wall(128,0,64,-20)

	FLIPPERS = {}

	new_flipper(40, 80, 20, .8, -.1, false)
	new_flipper(90, 80, 20, .2, .1, true)

	POINTS = {}


	CAMERA_X, CAMERA_Y = 64,64
end

function new_flipper(_x, _y, _length, _dir, _extendAmount, _is_right)
	local flipper={
		x= _x,
		y= _y,

		is_right = _is_right,

		length = _length,				-- flipper length , what did you expect ?

		prev_dir = _dir,
		direction = _dir,				-- the actual direction the flipper is currently facing
		rest_direction = _dir,			-- the resting direction
		extend_amount = _extendAmount,	-- the amount the flipper rotates

		is_active = false,
		active_perc = 0,						-- number between 0-1 for how active the flipper is

		tip = {
			x = _x + sin(_dir) * _length,
			y = _y + cos(_dir) * _length,
		},
	}
	add(FLIPPERS, flipper)
end

-- function that returns a pinball at table x/y
function new_ball(_tx, _ty)
	local pinball = {
		x = _tx,
		y = _ty,

		dirX = 0,
		dirY = 0,
	}

	return add(BALLS, pinball)
end

function new_wall(x1,y1,x2,y2)
	local wall = {
		a = new_point(x1,y1), 
		b = new_point(x2,y2),
	}

	local dirX,dirY,length = get_direction_of_vector(convert_points_to_vector(wall.a,wall.b))
	wall.dirX,wall.dirY,wall.length= dirY , -dirX,length

	return add(WALLS,wall)
end

function new_point(_x, _y)
	return {x=_x, y=_y}
end

-->8
-- update
function _update60()
	t+=1

	LEFT_FLIPPER = btn"4"
	RIGHT_FLIPPER = btn"5"
	
	local speed = 1
	local BALL = BALLS[1]
	if(btn"0")BALL.x -= speed BALL.dirX = 0
	if(btn"1")BALL.x += speed BALL.dirX = 0

	if(btn"2")BALL.y -= speed BALL.dirY = 0
	if(btn"3")BALL.y += speed BALL.dirY = 0
	
	if(STOP_SIM)goto continue
	for i=PHYSICS_SPEED/PHYSICS_STEPS,PHYSICS_SPEED,PHYSICS_SPEED/PHYSICS_STEPS do 
		update_physics(PHYSICS_SPEED/PHYSICS_STEPS)
	end
	::continue::


	local cam_lerp_speed = .05
	local ox,oy = 64,80
	CAMERA_X,CAMERA_Y = lerp(CAMERA_X + ox, BALLS[1].x, cam_lerp_speed) - ox, lerp(CAMERA_Y + oy, BALLS[1].y, cam_lerp_speed) - oy
	camera(CAMERA_X, CAMERA_Y)
end


-->8
-- draw
function _draw()
	cls(15)

	local width = 32
	for x=-2,128/width,1 do
		for y=-2,128/width,1 do
			local _x,_y = CAMERA_X + x*width - CAMERA_X%width + (t*.2)%(2*width), CAMERA_Y + y*width - CAMERA_Y%width + (t*.15)%(2*width)
			if((x+CAMERA_X\width+y+CAMERA_Y\width)%2==0)rectfill(_x,_y,_x+width-1,_y+width-1,6)
		end
	end

	draw_walls()
	
	foreach(FLIPPERS, draw_flipper)
	foreach(BALLS, draw_ball)

	foreach(POINTS, draw_point)
	if (#POINTS>30) deli(POINTS,1)

	print(DEBUG, CAMERA_X + 1 , CAMERA_Y + 1,0)

	local debug2 = tostring(LEFT_FLIPPER) .. " " .. tonum(LEFT_FLIPPER) .. "\n" .. tostring(RIGHT_FLIPPER)
	print(debug2, 1, 100)


	print(PHYSICS_SPEED, 128 - #tostring(PHYSICS_SPEED)*4, 1)
end

function draw_point(_point)
	circfill(_point.x, _point.y, 1.5, 12)
end

function draw_ball(_ball)
	sspr(0,0,11,11,_ball.x-5,_ball.y-5)
	pset(_ball.x, _ball.y, 7)
	dirX,dirY=get_direction_of_vector(_ball.dirX, _ball.dirY)
	line(_ball.x, _ball.y, _ball.x + _ball.dirX *2, _ball.y + _ball.dirY *2, 7)
end

function draw_flipper(_flipper)
	local ox, oy = _flipper.x, _flipper.y

	circfill(ox, oy, 3, 3)

	line(ox, oy, _flipper.tip.x, _flipper.tip.y, 3)

	-- print(_flipper.active_perc, ox, oy, 1)
end

function draw_walls()
	for i=1,#WALLS do 
		local _wall=WALLS[i]
		
		local a,b = _wall.a, _wall.b
		local cx,cy = lerp(a.x,b.x,.5),lerp(a.y,b.y,.5)	-- get centre of line
		
		line(cx,cy,cx+_wall.dirX*5,cy+_wall.dirY*5,13)

		line(a.x,a.y,b.x,b.y, 5) -- the actual line segment
	end
end

-->8
-- physics

function dot_product(v1, v2)
	return ( v1.x * v2.x ) + ( v1.y * v2.y )
end

function convert_points_to_vector(a,b)
	return b.x-a.x, b.y-a.y
end

function get_direction_of_vector(_x, _y)
	local length = sqrt(_x*_x + _y*_y)
	return _x/length, _y/length, length
end


function update_physics(_timestep)
	deltaTime = _timestep

	foreach(BALLS, update_ball)

	foreach(FLIPPERS, update_flipper)
end

function update_flipper(_flipper)
	_flipper.prev_dir = _flipper.direction

	local is_active = false
	if _flipper.is_right then 
		is_active = RIGHT_FLIPPER
	else
		is_active = LEFT_FLIPPER
	end
	_flipper.is_active=is_active

	if tonum(is_active) != _flipper.active_perc then 	
		-- only update flipper location if it needs to move

		local movement = FLIPPER_SPEED * deltaTime * (is_active and 1 or -1)
		_flipper.active_perc = mid(0, _flipper.active_perc + movement, 1)

		-- update the fliper tip location
		local direction = _flipper.rest_direction + lerp(0, _flipper.extend_amount, easeInCubic(_flipper.active_perc))
		_flipper.direction = direction
		_flipper.tip.x = _flipper.x + sin(direction) * _flipper.length
		_flipper.tip.y = _flipper.y + cos(direction) * _flipper.length
	end
end

function update_ball(_ball)
	add_force(_ball, 0, GRAVITY * deltaTime, false)

	_ball.x += _ball.dirX * deltaTime
	_ball.y += _ball.dirY * deltaTime

	-- check collision with each line of edge
	-- foreach(LINES, line_col)
	for wall in all(WALLS) do 
		wall_col(wall, _ball)
	end

	for flipper in all(FLIPPERS) do 

		local col,point=edge_collision(flipper, flipper.tip, _ball)
		if col then 
			local dirX, dirY, length = get_direction_of_vector(convert_points_to_vector(new_point(point[1],point[2]),_ball))
			_ball.x, _ball.y = point[1] + dirX * BALL_RADIUS, point[2] + dirY * BALL_RADIUS

			local friction = .8
			if flipper.active_perc%1!=0 and flipper.is_active then 
					-- if flipper is moving forward

				local col_length = point[3]

					-- find x/y position for old
				local oldX = flipper.x + sin(flipper.prev_dir) * flipper.length * col_length
				local oldY = flipper.y + cos(flipper.prev_dir) * flipper.length * col_length

					-- new x/y is just collision location
				local newX = point[1]
				local newY = point[2]

				add(POINTS, new_point(newX, newY))

					-- change_in_position = x_final - x_initial.
				local deltaX = newX - oldX 
				local deltaY = newY - oldY 

					-- "velocity = change_in_position / dt."
				local velocityX, velocityY = deltaX / deltaTime, deltaY / deltaTime

				add_force(_ball, velocityX * friction, velocityY * friction, false)
			else
				local wall_direction=new_point(dirX, dirY)

				local dot = dot_product({x=_ball.dirX, y=_ball.dirY},wall_direction)

				local dx = -wall_direction.x * 2 * dot
				local dy = -wall_direction.y * 2 * dot

					-- normal flipper either stationary or heading down
				add_force(_ball, dx * friction, dy * friction, false)
			end
		end
	end
end

-- ran for each edge and applies physics stuff to it
function wall_col(_wall, _ball)
	local col,point = edge_collision(_wall.a, _wall.b, _ball)
	if col then
			-- old performant version , still might use  
			-- makes use of pre-calculated normals
		-- _ball.x, _ball.y = point[1]+point[4]*BALL_RADIUS,point[2]-point[3]*BALL_RADIUS
		-- local wall_direction=new_point(point[4],-point[3])

		
		local dirX, dirY, length = get_direction_of_vector(convert_points_to_vector(new_point(point[1],point[2]),_ball))
		_ball.x, _ball.y = point[1] + dirX * BALL_RADIUS, point[2] + dirY * BALL_RADIUS

		local wall_direction=new_point(dirX, dirY)

		local dot = dot_product({x=_ball.dirX, y=_ball.dirY},wall_direction)

		local dx = -wall_direction.x * 2 * dot
		local dy = -wall_direction.y * 2 * dot

		local friction = .8

		add_force(_ball, dx * friction, dy * friction, false)
	end
end

-- returns true if collision between ball and edge
function edge_collision(a, b, ball)

	local AC={}
	AC.x,AC.y=convert_points_to_vector(a,ball)

	-- direction of edge
	local dirX, dirY, length = get_direction_of_vector(convert_points_to_vector(a,b)) 		-- evnetually pre-calculate , direction and length of edge
	
	-- calculate if it's WAY out before even bothering with the rest
	local AC_dist_along_AB = dirX*AC.x + dirY * AC.y
	if(AC_dist_along_AB > length+BALL_RADIUS or AC_dist_along_AB<-BALL_RADIUS)return false

	local dist = mid(0,AC_dist_along_AB,length)					-- distance of AC along vector AB normalised to AB length

	local projX, projY = dirX * dist , dirY * dist				-- scaled direction vector to distance along AB length
	local closeX, closeY = a.x + projX , a.y + projY			-- x/y position of point closest to ball along AB

	local col_dist = calc_dist2(closeX, closeY, ball.x, ball.y)

	--[[
	local pointX, pointY = ball.x - closeX , ball.y - closeY
	local length2 = pointX*pointX + pointY*pointY				-- distance between closest point on AB and ball/circ
	]]--

	-- DEBUG = length2

	-- did_collide , { nearest point on lineX, Y, number show how far along the obj the collision was }
	return col_dist < BALL_RADIUS, {closeX, closeY, dist/length}
end


function calc_dist2(x1,y1,x2,y2)
	return abs(x1-x2)+abs(y1-y2)
end

-- add a force to target
-- is_inpulse overwrites velocity
function add_force(_target, _dx, _dy, is_inpulse)
	if(is_inpulse)_target.dirX, _target.dirY = 0,0

	_target.dirX += _dx
	_target.dirY += _dy
end

-->8
-- tools
function easeInCubic(_t)
	return _t * _t * _t
end

function lerp(a,b,t) 
	return a+(b-a)*t 
end
__gfx__
fff51115fff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ff1677761ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f166777661f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5dd66766dd5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1ddd666ddd1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
151ddddd151000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13511111531000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5d33bbb33d5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f13bbbbb31f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ff1dbbbd1ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
fff51115fff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
