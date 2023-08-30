pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- init

GRAVITY =  .06
DEBUG = ""
DEBUGTIME = 90

deltaTime = 1

LEFT_FLIPPER,RIGHT_FLIPPER = false, false
FLIPPER_SPEED = .4

PHYSICS_SPEED = 1
PHYSICS_STEPS = 8

STOP_SIM = false
BALL_RADIUS = 5

BALL_MAX_VELOCITY = 7

#include inf_mapdata.txt

function debug(_text, _time)
	DEBUG = tostr(_text)
	DEBUGTIME = _time or 90
end

function _init()
	t=0

	palt(0,false)
	palt(15,true)


	BALLS={}
	new_ball(40,50)
	
	WALLS={}
	foreach(split(poly_library,"\n"),init_walls)

	FLIPPERS = {}		-- todo remove evntually
	PARTS = {}
	foreach(split(part_library,"\n"),init_part)

	-- new_flipper(44, 116, 20, .82, -.12, false)
	-- new_flipper(94, 116, 20, .18, .12, true)

	-- new_flipper(137, 10, 20, .08, .1, true)

	POINTS = {}


	CAMERA_X, CAMERA_Y = 64,64
end

function init_part(_datastr)
	local data = split(_datastr)
	local part_type = deli(data,1)

	if part_type=="flipper" then 
		new_flipper(data)
	end
end

function init_walls(_data)
	local data = split(_data)
	for i=1,#data-2,2 do 
		new_wall(data[i],data[i+1],data[i+2],data[i+3])
	end
	new_wall(data[#data-1],data[#data],data[1],data[2])
end

function new_flipper(_data) -- _length, _dir, _extendAmount, _is_right)
	local name, _x, _y, is_left, _length, _rest, _extend = unpack(_data)

	debug(is_left)

	local flipper={
		x= _x,
		y= _y,

		is_left = is_left=="true",

		length = _length,				-- flipper length , what did you expect ?

		prev_dir = _rest,
		direction = _rest,				-- the actual direction the flipper is currently facing
		rest_direction = _rest,			-- the resting direction
		extend_amount = _extend,	-- the amount the flipper rotates

		is_active = false,
		active_perc = 0,						-- number between 0-1 for how active the flipper is

		tip = {
			x = _x + sin(_rest) * _length,
			y = _y + cos(_rest) * _length,
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

		-- normalised direction
		n_dirX = 0,
		n_dirY = 0,

		additive_velocity = 0,
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

	if(btnp"2")STOP_SIM=false

	if(DEBUGTIME>=0)DEBUGTIME-=1
	if(DEBUGTIME==0)DEBUG = ""

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


	cam_ox,cam_oy = -64,-64


	local ball = BALLS[1]

	local cam_lerp_speed = .05 + lerp(0,.1,min(abs(ball.dirX)+abs(ball.dirY),5)/5)
	local target_x, target_y = mid(62, ball.x + ball.dirX, 76) , min(ball.y + ball.dirY * 8, 90)

	CAMERA_X,CAMERA_Y = lerp(CAMERA_X, target_x, cam_lerp_speed), lerp(CAMERA_Y, target_y, cam_lerp_speed)	
	camera(flr(CAMERA_X + cam_ox), flr(CAMERA_Y + cam_oy))
end


-->8
-- draw
function _draw()
	cls(15)

	local width = 32
	for x=-2,128/width,1 do
		for y=-2,128/width,1 do
			local _x,_y = CAMERA_X + cam_ox + x*width - CAMERA_X%width + (t*.2)%(2*width), CAMERA_Y + cam_oy + y*width - CAMERA_Y%width + (t*.15)%(2*width)
			if((x+CAMERA_X\width+y+CAMERA_Y\width)%2==0)rectfill(_x,_y,_x+width-1,_y+width-1,6)
		end
	end

	draw_walls()
	
	foreach(FLIPPERS, draw_flipper)
	foreach(BALLS, draw_ball)

	foreach(POINTS, draw_point)
	if (#POINTS>30) deli(POINTS,1)

	print(DEBUG, CAMERA_X + cam_ox + 1, CAMERA_Y + cam_oy + 1,0)
end

function draw_point(_point)
	circfill(_point.x, _point.y, 1.5, 12)
end

function draw_ball(_ball)
	sspr(0,0,11,11,flr(_ball.x)-5,flr(_ball.y)-5)
	dirX,dirY=get_direction_of_vector(_ball.dirX, _ball.dirY)
	line(_ball.x, _ball.y, _ball.x + _ball.dirX *2, _ball.y + _ball.dirY *2, 7)
	pset(_ball.x, _ball.y, t)

end

function draw_flipper(_flipper)
	local ox, oy = _flipper.x, _flipper.y

	-- circfill(ox, oy, 3, 3)

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
	if _flipper.is_left then 
		is_active = LEFT_FLIPPER
	else
		is_active = RIGHT_FLIPPER
	end
	_flipper.is_active=is_active

	if tonum(is_active) != _flipper.active_perc then 	
		-- only update flipper location if it needs to move

		local movement = FLIPPER_SPEED * deltaTime * (is_active and 1 or -1)
		_flipper.active_perc = mid(0, _flipper.active_perc + movement, 1)

		-- update the fliper tip location
		local direction = _flipper.rest_direction + lerp(0, _flipper.extend_amount, easeOutCubic(_flipper.active_perc))
		_flipper.direction = direction
		_flipper.tip.x = _flipper.x + sin(direction) * _flipper.length
		_flipper.tip.y = _flipper.y + cos(direction) * _flipper.length
	end
end

function update_ball(_ball)
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

			local bounciness = .8
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

				-- debug(velocityX .. "," .. velocityY)


				bounciness = .9

				-- if it hits the edge of a flipper then send it on an angle
				if point[3]==1 or point[3]==0 then 
					debug("angled hit !")

					local wall_direction=new_point(dirX, dirY)

					-- set to abs as to not flip ball direction
					-- terrible work around , but it works so :/
					velocityX *= abs(wall_direction.x)
					velocityY *= abs(wall_direction.y)
				end

				-- horrible debug test physics stuff please remove
				-- makes vertical shots a bit easier from an idle ball
				--[[
				if(_ball.additive_velocity<1)velocityY+=5 * (1-_ball.additive_velocity)
				debug(5 * (1-_ball.additive_velocity))
				]]--

				add_force(_ball, velocityX * bounciness, velocityY * bounciness * 1.2, false)
			else
				local wall_direction=new_point(dirX, dirY)

				local dot = dot_product(new_point(_ball.dirX, _ball.dirY),wall_direction)

				local dx = -wall_direction.x * 2 * dot
				local dy = -wall_direction.y * 2 * dot

					-- normal flipper either stationary or heading down
				add_force(_ball, dx * bounciness, dy * bounciness, false)
			end
		end
	end

	add_force(_ball, 0, GRAVITY * deltaTime, false)

	_ball.dirX = mid(-BALL_MAX_VELOCITY, _ball.dirX, BALL_MAX_VELOCITY)
	_ball.dirY = mid(-BALL_MAX_VELOCITY, _ball.dirY, BALL_MAX_VELOCITY)

	local dist=calc_dist2(_ball.x, _ball.y, _ball.x + _ball.dirX, _ball.y + _ball.dirY)
	_ball.n_dirX, _ball.n_dirY = _ball.dirX / dist, _ball.dirY / dist -- normalised direction ?

	_ball.additive_velocity = abs(_ball.dirX) + abs(_ball.dirY)
	-- debug(_ball.additive_velocity)

	if(_ball.y>180)_ball.x, _ball.y, _ball.dirX, _ball.dirY = 92,112, 0, 0
end

-- TODO completely refactor this
-- ran for each edge and applies physics stuff to it
function wall_col(_wall, _ball)
	local col,point = edge_collision(_wall.a, _wall.b, _ball)
	if col then		
		local dirX, dirY, length = get_direction_of_vector(convert_points_to_vector(new_point(point[1],point[2]),_ball))
		_ball.x, _ball.y = point[1] + dirX * BALL_RADIUS, point[2] + dirY * BALL_RADIUS

		local wall_direction=new_point(dirX, dirY)

		local bounciness = .6

		local dot = dot_product({x=_ball.dirX, y=_ball.dirY},wall_direction) * (1+bounciness)

		local dx = -wall_direction.x * dot
		local dy = -wall_direction.y * dot

		--[[
		-- an extra check to see if the ball is "skimming" the wall , in which case don't bounce it too much- I guess
		local skim_check = dot_product({x=_ball.n_dirX, y=_ball.n_dirY},wall_direction)
		if abs(skim_check)<.3 then 
			debug(tostr(t) .. "\n" .. skim_check)
			dx = dirX
			dy = dirY

			bounciness = .3
		end
		]]--

		--[[
		local dx = dirX
		local dy = dirY
		]]--


		add_force(_ball, dx, dy, false)
	end
end

function normalise(_vx, _vy)

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

function easeOutCubic(t)
    t-=1
    return 1-t*t
end

function lerp(a,b,t) 
	return a+(b-a)*t 
end
__gfx__
fff51115fffffcccffffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ff1677761fffc777cfffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f166777661fc77777cffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5dd66766dd5c77777cffffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1ddd666ddd1c777777cfffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
151ddddd151c777777cfffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13511111531c7777777cffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5d33bbb33d5c7777777cffffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f13bbbbb31fc77777777cfffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ff1dbbbd1ffc77777777cfffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
fff51115fffc777777777cffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000c777777777cffffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000c7777777777cfffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000c7777777777cfffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000c77777777777cffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000c77777777777cffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000c777777777777cfff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000c777777777777cfff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000c7777777777777cff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000001c777777777777cff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000011cc77777777777cf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000f111cc777777777cf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000ff1111cc77777777c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000ffff1111cc777777c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000ffffff1111cc777c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000ffffffff1111ccc110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000ffffffffff111111f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000ffffffffffff111ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
