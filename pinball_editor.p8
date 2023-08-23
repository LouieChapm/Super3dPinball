pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

DEBUG = ""
DEBUGTIME = 90

SELECTION_INFO = "none"
CURSORXYSTRING = ""

cursor_selection = nil

drag_update_x, drag_update_y=0,0

show_points = true

#include inf_polygons.txt

function _init()
	t=0

	cartdata("super_pinball_editor_v1")

	menuitem(1, "export data", function() export_data() end)

	poke(0x5F2D, 1)
	MOUSE_X,MOUSE_Y,MOUSE_CLICK,MOUSE_HOLD=64,64,false,false
	mouseX_raw, mouseY_raw = 0,0

	init_polygon(poly_library)

	CAMERA_X,CAMERA_Y=dget(0) or 0,dget(1) or 0
	CURSOR_IN_UI = false

	NEW_POINT_PREVIEW = {}
end

function init_polygon(poly_data)
	POLYGONS ={{}}

	POINTS={}

	local data = split(poly_data)
	for i=1,#data-1,2 do 

		local point = add(POINTS,new_point(data[i],data[i+1]))

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
	local point = {x=_x, y=_y}
	point.hover = false
	point.is_dragging = false
	point.line_hover = false

	-- create a weird linked list
	point.prev = nil
	point.next = nil

	return point 
end



-->8
--update

function _update60()
	mouseX_raw,mouseY_raw=stat(32),stat(33)

	CURSOR_IN_UI = mouseY_raw < 8 or mouseY_raw > 120

	t+=1
	if(DEBUGTIME>0)DEBUGTIME-=1
	if(DEBUGTIME==0)DEBUG=""

	cursor_selection=nil
	SELECTION_INFO = ""
	CURSORXYSTRING = "x:" .. (MOUSE_X - MOUSE_X%SNAP) .. " y:" .. (MOUSE_Y - MOUSE_Y%SNAP)

	update_keyboard()
	if(keyboard_tab)show_points = not show_points
	update_camera()
	update_cursor()

	foreach(POINTS, update_point)
	
	-- check to see if the cursor is hovering over an edge
	NEW_POINT_PREVIEW = nil
	if not cursor_selection then
		local curs = new_point(MOUSE_X, MOUSE_Y)
		local closest_collision,collided_obj,collision_info = 999,nil,{}
		for i=1,#POINTS do 
			local p1,p2 = POINTS[i],POINTS[i].next
			local col,info=edge_collision(p1,p2,curs)
			if col and info[4]<closest_collision then 
				closest_collision = info[4]
				collided_obj = p1
				collision_info = info
			end
		end	

		if collided_obj then 
			collided_obj.line_hover = true

			local dist_on_line = collision_info[3]
			if dist_on_line>.15 and dist_on_line<.85 then
				NEW_POINT_PREVIEW = new_point(collision_info[1], collision_info[2])
				NEW_POINT_PREVIEW.data = collision_info

				NEW_POINT_PREVIEW.prev = collided_obj
				NEW_POINT_PREVIEW.next = collided_obj.next

				SELECTION_INFO = "split line"
			end
		end
	end

	-- delete selection on right click
	if cursor_selection and MOUSE_RIGHT_RELEASE and drag_update_x==0 and drag_update_y==0 then 
		cursor_selection.prev.next = cursor_selection.next 
		cursor_selection.next.prev = cursor_selection.prev
		
		del(POINTS,cursor_selection)
	end

	-- add new point on left click
	if NEW_POINT_PREVIEW and MOUSE_CLICK then 
		local new_point = add(POINTS,new_point(NEW_POINT_PREVIEW.x, NEW_POINT_PREVIEW.y))

		NEW_POINT_PREVIEW.prev.next = new_point
		NEW_POINT_PREVIEW.next.prev = new_point

		new_point.prev = NEW_POINT_PREVIEW.prev
		new_point.next = NEW_POINT_PREVIEW.next

		new_point.is_dragging = true
	end
end

function update_keyboard()
	debug(stat(31))

	local p = stat(30) and stat(31)

	keyboard_tab = false


	if(p=="\t")keyboard_tab=true
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

	MOUSE_X,MOUSE_Y=mouseX_raw+CAMERA_X,mouseY_raw+CAMERA_Y
	
	local stat34 = stat(34)

	MOUSE_CLICK=MOUSE_HOLD==false and stat34%2==1
	MOUSE_HOLD=stat34%2==1

	MOUSE_RIGHT_CLICK = MOUSE_RIGHT==false and stat34&2==2
	MOUSE_RIGHT_RELEASE = MOUSE_RIGHT and stat34&2!=2
	MOUSE_RIGHT=stat34&2==2

	if MOUSE_RIGHT_CLICK then 
		CAMERA_DRAGGING = true 

		cam_origin_x, cam_origin_y = CAMERA_X, CAMERA_Y 
		drag_origin_x,drag_origin_y = mouseX_raw, mouseY_raw
	end

	if CAMERA_DRAGGING then 
		drag_update_x, drag_update_y = drag_origin_x - mouseX_raw, drag_origin_y - mouseY_raw
	end

	if CAMERA_DRAGGING and not MOUSE_RIGHT then 
		CAMERA_DRAGGING = false
	end
end

SNAP = 8
function update_point(_point)
	_point.hover = false
	_point.line_hover = false

	-- todo eventually calculate which circle is nearer !
	-- and only activate that one
	if cursor_selection==nil and not CURSOR_IN_UI and calc_dist2(_point.x, _point.y, MOUSE_X, MOUSE_Y)<8 then 
		_point.hover = true

		cursor_selection = _point
		SELECTION_INFO = "move point"
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
	draw_checkerboard(1)

	foreach(POINTS,draw_iPointLine)
	if(show_points)foreach(POINTS,draw_iPoint)

	if NEW_POINT_PREVIEW!=nil then 
		circ(NEW_POINT_PREVIEW.x, NEW_POINT_PREVIEW.y, 2, 7)
	end


	-- top ui
	rectfill(CAMERA_X, CAMERA_Y, CAMERA_X+128, CAMERA_Y+7, 8)
	local selected = 1
	for i=1, #POLYGONS do
		local _x,_y=CAMERA_X+3 + (i-1)*9, CAMERA_Y
		if(selected == i)pal(14,7)
		spr(2, _x, _y)
		if(selected == i)pal(14,14)
		print(i, _x+3, _y+2, 8)
	end
	spr(3,CAMERA_X+3 + (#POLYGONS)*9, CAMERA_Y)

	-- bottom ui
	rectfill(CAMERA_X, CAMERA_Y+121, CAMERA_X+128, CAMERA_Y+128, 8)
	print(DEBUGTIME>0 and DEBUG or SELECTION_INFO, CAMERA_X+1, CAMERA_Y+122, 2)
	print(CURSORXYSTRING, CAMERA_X+128 - #CURSORXYSTRING*4, CAMERA_Y+122, 2)


	spr(1,MOUSE_X,MOUSE_Y)
end

function draw_checkerboard(_col)
	--[[
	local width = 32
	for x=-2,128/width,1 do
		for y=-2,128/width,1 do
			local _x,_y = CAMERA_X + x*width - CAMERA_X%width + (t*.2)%(2*width), CAMERA_Y + y*width - CAMERA_Y%width + (t*.15)%(2*width)
			if((x+CAMERA_X\width+y+CAMERA_Y\width)%2==0)rectfill(_x,_y,_x+width-1,_y+width-1,6)
		end
	end
	]]--

	fillp(▒)
	local width = 32
	for x=-2,128/width,1 do
		for y=-2,128/width,1 do
			local _x,_y = CAMERA_X + x*width - CAMERA_X%width, CAMERA_Y + y*width - CAMERA_Y%width
			if (x+CAMERA_X\width+y+CAMERA_Y\width)%2==0 then 
				rect(_x,_y,_x+width,_y+width,_col)
			end
		end
	end
	fillp()

	circfill(0,0,2,0)
	circ(0,0,2,_col)
end

function draw_iPoint(_point)
	local col=_point.hover and 7 or 5

	if(_point.line_hover or _point.prev.line_hover)col = 13

	circfill(_point.x,_point.y, 3,0)
	circ(_point.x, _point.y, 3, col)
	circfill(_point.x, _point.y, 1, col)
end

function draw_iPointLine(_point)
	local line_col = _point.line_hover and 13 or 5

	if _point.hover or _point.next.hover then 
		line_col = 13
	end

	if _point.next then 
		line(_point.x, _point.y, _point.next.x, _point.next.y, line_col)
	end
end

-->8
-- physics

-- returns true if collision between ball and edge
CURSOR_RADIUS = 5
function edge_collision(a, b, ball)

	if(CURSOR_IN_UI)return false

	local AC={}
	AC.x,AC.y=convert_points_to_vector(a,ball)

	-- direction of edge
	local dirX, dirY, length = get_direction_of_vector(convert_points_to_vector(a,b)) 		-- evnetually pre-calculate , direction and length of edge
	
	-- calculate if it's WAY out before even bothering with the rest
	local AC_dist_along_AB = dirX*AC.x + dirY * AC.y
	if(AC_dist_along_AB > length+CURSOR_RADIUS or AC_dist_along_AB<-CURSOR_RADIUS)return false

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
	return col_dist < CURSOR_RADIUS, {closeX, closeY, dist/length, col_dist}
end

-->8
-- debug

function debug(_msg, _time)
	DEBUG = tostr(_msg)
	DEBUGTIME = _time or 90
end


-->8
-- data handing
function export_data()

	dset(0,CAMERA_X)
	dset(1,CAMERA_Y)

	
	local out = "poly_library=[["

	local steps = 0
	local point = POINTS[1]
	while steps < #POINTS do 
		out..= point.x .. "," .. point.y ..","
		
		steps += 1
		point = point.next
	end

	out = sub(out,1,-2) .. "]]"

	printh(out, "inf_polygons.txt", true)
end



__gfx__
00000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000001710000000eeeeee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700177100000eeeeeee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007700017771000eeeeeeee0000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007700017777100eeeeeeee000eee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070017711000eeeeeeee0000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000001101000eeeeeeee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000eeeeeeee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
