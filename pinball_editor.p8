pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

DEBUG = "text message"

#include inf_walls.txt

function _init()
	t=0

	poke(0x5F2D, 1)
	MOUSE_X,MOUSE_Y,MOUSE_CLICK,MOUSE_HOLD=64,64,false,false

	init_polygon(DATA_walls)

	CAMERA_X,CAMERA_Y=0,0
end

function init_polygon(poly_data)
	WALLS={}
	POINTS={}

	local data = split(poly_data)
	for i=1,#data-1,2 do 

		local point = add(POINTS,new_point(data[i],data[i+1]))
		point.hover = false
		point.is_dragging = false

		-- create a weird linked list
		point.prev = POINTS[i\2] or nil
		if(point.prev)point.prev.next = point
	end

	POINTS[#POINTS].next = POINTS[1]
	POINTS[1].prev = POINTS[#POINTS]
end

function lerp(a,b,t) 
	return a+(b-a)*t 
end

function convert_points_to_vector(a,b)
	return b.x-a.x, b.y-a.y
end

function get_direction_of_vector(_x, _y)
	local length = sqrt(_x*_x + _y*_y)
	return _x/length, _y/length, length
end

function new_point(_x, _y)
	return {x=_x, y=_y}
end



-->8
--update

function _update60()
	t+=1

	update_camera()
	update_cursor()

	foreach(POINTS, update_point)

end

function update_camera()
	local speed=3

	if(btn(⬅️))CAMERA_X-=speed
	if(btn(➡️))CAMERA_X+=speed
	if(btn(⬆️))CAMERA_Y-=speed
	if(btn(⬇️))CAMERA_Y+=speed

	if CAMERA_DRAGGING then 
		CAMERA_X = cam_origin_x + drag_update_x
		CAMERA_Y = cam_origin_y + drag_update_y
	end

	camera(CAMERA_X, CAMERA_Y)
end

function update_cursor()
	local old_x, old_y = MOUSE_X, MOUSE_Y

	MOUSE_X,MOUSE_Y=stat(32)+CAMERA_X,stat(33)+CAMERA_Y
	
	local stat34 = stat(34)

	MOUSE_CLICK=MOUSE_HOLD==false and stat34%2==1
	MOUSE_HOLD=stat34%2==1

	MOUSE_RIGHT_CLICK = MOUSE_RIGHT==false and stat34&2==2
	MOUSE_RIGHT=stat34&2==2

	if MOUSE_RIGHT_CLICK then 
		CAMERA_DRAGGING = true 

		cam_origin_x, cam_origin_y = CAMERA_X, CAMERA_Y 
		drag_origin_x,drag_origin_y = stat(32), stat(33)
	end

	if CAMERA_DRAGGING then 
		drag_update_x, drag_update_y = drag_origin_x - stat(32), drag_origin_y - stat(33)
	end

	if CAMERA_DRAGGING and not MOUSE_RIGHT then 
		CAMERA_DRAGGING = false
	end
end

SNAP = 8
function update_point(_point)
	_point.hover = false

	if calc_dist2(_point.x, _point.y, MOUSE_X, MOUSE_Y)<10 then 
		_point.hover = true
	end

	if _point.hover and MOUSE_CLICK then 
		_point.is_dragging = true
	end

	if _point.is_dragging then 
		_point.x = ((MOUSE_X + SNAP*.5)\SNAP)*SNAP
		_point.y = ((MOUSE_Y + SNAP*.5)\SNAP)*SNAP

		if not MOUSE_HOLD then 
			_point.is_dragging = false
		end
	end
end

function calc_dist2(x1,y1,x2,y2)
	return abs(x1-x2)+abs(y1-y2)
end

-->8
-- draw
function _draw()
	cls(0)
	-- draw_checkerboard()

	draw_walls()
	foreach(POINTS,draw_iPoint)

	spr(1,MOUSE_X,MOUSE_Y)


	rectfill(CAMERA_X, CAMERA_Y, CAMERA_X+128, CAMERA_Y+6, 8)

	rectfill(CAMERA_X, CAMERA_Y+121, CAMERA_X+128, CAMERA_Y+128, 8)
	print(DEBUG, CAMERA_X + 1, CAMERA_Y + 122, 2)
end

function draw_checkerboard()
	local width = 32
	for x=-2,128/width,1 do
		for y=-2,128/width,1 do
			local _x,_y = CAMERA_X + x*width - CAMERA_X%width + (t*.2)%(2*width), CAMERA_Y + y*width - CAMERA_Y%width + (t*.15)%(2*width)
			if((x+CAMERA_X\width+y+CAMERA_Y\width)%2==0)rectfill(_x,_y,_x+width-1,_y+width-1,6)
		end
	end
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

function draw_iPoint(_point)
	local col=_point.hover and 13 or 5

	circ(_point.x, _point.y, 3, col)
	circfill(_point.x, _point.y, 1, col)

	if _point.next then 
		if t\15%2==0 then 
			fillp(▥)
		else
			fillp(▤)
		end
		line(_point.x, _point.y, _point.next.x, _point.next.y, 5)
		fillp()
	end
end


-->8
-- data handing
function export_data()
	
end

__gfx__
00000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000171000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700177100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000177710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000177771000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700177110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000011010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
