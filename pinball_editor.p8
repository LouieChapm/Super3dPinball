pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

DEBUG = ""
DEBUGTIME = 0

SELECTION_INFO = "none"
CURSORXYSTRING = ""

cursor_selection = nil

-- drag_next starts a drag on the next avaiable frame
can_drag, drag_next = true, -1
drag_update_x, drag_update_y=0,0

show_points = true

current_mode_index = 1
modes_names=split"polygon edit,place parts"
num_ui_modes = #modes_names
modes_ui_x = 126 - num_ui_modes*9 		-- horizontal place to start drawing modes ui buttons



#include inf_mapdata.txt

function _init()
	t=0

	cartdata("super_pinball_editor_v1")

	menuitem(1, "export data", function() export_data() end)

	poke(0x5F2D, 1)
	MOUSE_X,MOUSE_Y,MOUSE_CLICK,MOUSE_HOLD,cursor_mode=64,64,false,false,1
	mouseX_raw, mouseY_raw = 0,0

	POLYGONS = {}
	foreach(split(poly_library,"\n"),init_polygon)
	ACTIVE_POLY_INDEX, ACTIVE_POLY_OBJECT = 1, POLYGONS[1]

	PARTS = {}
	

	CAMERA_X,CAMERA_Y=dget(0) or 0,dget(1) or 0
	CURSOR_IN_UI = false

	NEW_POINT_PREVIEW = {}
end

function init_part(_datastr)
	local data = split(_datastr)
	local part_type = deli(data,1)

	if part_type=="flipper" then 
		new_flipper(data)
	end
end


function init_polygon(poly_data)
	local points={}

	-- if its a string then split it , otherwise just use the table
	local data = type(poly_data)=="string" and split(poly_data) or poly_data
	for i=1,#data-1,2 do 
		local point = add(points,new_point(data[i],data[i+1], points))

		-- create a weird linked list
		point.prev = points[i\2] or nil
		if(point.prev)point.prev.next = point
	end

	points[#points].next = points[1]
	points[1].prev = points[#points]

	return add(POLYGONS, points)
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

function new_point(_x, _y, _parent)
	local point = {x=_x, y=_y}
	point.hover = false
	point.is_dragging = false
	point.line_hover = false

	-- create a weird linked list
	point.prev = nil
	point.next = nil

	point.parent = _parent or nil

	return point 
end



-->8
--update

function _update60()
	mouseX_raw,mouseY_raw=stat(32),stat(33)

	current_mode = modes_names[current_mode_index]

	t+=1
	if(DEBUGTIME>0)DEBUGTIME-=1
	if(DEBUGTIME==0)DEBUG=""


	cursor_selection=nil
	SELECTION_INFO = ""
	CURSORXYSTRING = "x:" .. (MOUSE_X - MOUSE_X%SNAP) .. " y:" .. (MOUSE_Y - MOUSE_Y%SNAP)

	
	update_cursor()
	update_keyboard()
	update_cursor_ui()

	update_camera()

	if(current_mode=="polygon edit")update_mode_polygon()
end

alphabet = split"a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,1,2,3,4,5,6,7,8,9,0,_"
function update_keyboard()
	local p = stat(30) and stat(31)

	keyboard_tab = false
	if(p=="\t")keyboard_tab=true

	keyboard_enter = false
	if(p=="\r")keyboard_enter=true

	
	if is_typing then 

		-- max length == 6 on part name things
		if(type_pass == "part_name" and #type_temp>=6)goto continue

		for letter in all(alphabet) do 
			if tostr(p)==tostr(letter) then 
				type_temp ..=letter
			end
		end

		::continue::

		if(p=="p")poke(0x5f30,1)

		if #type_temp>0 and p=="\b" then 
			type_temp = sub(type_temp,1,-2)

			
		end

		if MOUSE_CLICK or MOUSE_RIGHT_CLICK or keyboard_enter then 
			if(keyboard_enter)poke(0x5f30,1)
			end_typing()
		end
	end
end

function end_typing()
	is_typing = false

	if type_pass == "part_name" then 
		local name = type_temp
		if(#name<=0)name = gen_name()
		selected.name = sub(name,1,6)
	end
end	

part_num=0
function gen_name()
	part_num+=1
	return "part" .. sub("0"..part_num, -2)
end

function update_camera()
	local speed=3

	if can_drag then
		if(btn(⬅️))CAMERA_X-=speed
		if(btn(➡️))CAMERA_X+=speed
		if(btn(⬆️))CAMERA_Y-=speed
		if(btn(⬇️))CAMERA_Y+=speed
	end

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

	if MOUSE_RIGHT_CLICK and can_drag or drag_next==t then 
		start_drag()
	end

	if CAMERA_DRAGGING and can_drag then 
		drag_update_x, drag_update_y = drag_origin_x - mouseX_raw, drag_origin_y - mouseY_raw
	end

	if CAMERA_DRAGGING and not MOUSE_RIGHT then 
		CAMERA_DRAGGING = false
	end
end

function start_drag()
	CAMERA_DRAGGING = true 

	cam_origin_x, cam_origin_y = CAMERA_X, CAMERA_Y 
	drag_origin_x,drag_origin_y = mouseX_raw, mouseY_raw
end

function update_cursor_ui()
	CURSOR_IN_UI = mouseY_raw < 8 or mouseY_raw > 120
	cursor_mode = 1

	if(current_mode=="polygon edit")update_ui_polygon()
	if(current_mode=="place parts")update_ui_parts()

	if mouseY_raw < 8 then 
		if mouseX_raw > modes_ui_x-2 then 
			for i=0,num_ui_modes-1 do
				local _x = modes_ui_x-1 + i*9

				if mouseX_raw>_x and mouseX_raw<_x+8 then
					cursor_mode = 2
					SELECTION_INFO = modes_names[i+1]

					-- change mode
					if MOUSE_CLICK then 
						local mode_index = i+1
						current_mode_index = mode_index
						current_mode = modes_names[current_mode_index]

						if mode_index==2 then 
							goto_parts()
						end
					end
				end
			end
		end
	end
end

function delete_polygon(_index)
	deli(POLYGONS,_index)

	ACTIVE_POLY_INDEX = max(1,ACTIVE_POLY_INDEX-1)
	ACTIVE_POLY_OBJECT = POLYGONS[ACTIVE_POLY_INDEX]

	debug("polygon deleted")
end	

function create_polygon(_x, _y, _shape)
	debug("polygon inserted !")

	local shape = _shape
	for i=1,#shape,2 do 
		_shape[i]+=_x 
		_shape[i+1]+=_y
	end

	init_polygon(_shape)
end

SNAP = 4
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

	if(current_mode=="polygon edit")draw_mode_polygon()
	if(current_mode=="place parts")draw_mode_parts()

	do	-- top ui
		rectfill(CAMERA_X, CAMERA_Y, CAMERA_X+128, CAMERA_Y+7, 8)
		

		for i=0,num_ui_modes-1 do
			if(i+1==current_mode_index)pal(2,15)
			spr(9+i, CAMERA_X + modes_ui_x + i*9, CAMERA_Y)
			if(i+1==current_mode_index)pal(2,2)
		end
	end

	if(current_mode=="polygon edit")draw_ui_polygon()
	if(current_mode=="place parts")draw_ui_parts()

	do -- bottom ui
		rectfill(CAMERA_X, CAMERA_Y+121, CAMERA_X+128, CAMERA_Y+128, 8)
		print(DEBUGTIME>0 and DEBUG or SELECTION_INFO, CAMERA_X+1, CAMERA_Y+122, 2)
		print(CURSORXYSTRING, CAMERA_X+128 - #CURSORXYSTRING*4, CAMERA_Y+122, 2)
	end

	do -- cursor
		local _x,_y = mouseX_raw + CAMERA_X, mouseY_raw + CAMERA_Y
		if cursor_mode==1 then
			spr(1,_x,_y)
		elseif cursor_mode==2 then 
			if MOUSE_HOLD or MOUSE_RIGHT then 
				sspr(10,8,10,10,_x - 2,_y)
			else
				sspr(0,8,10,10,_x - 2,_y)
			end
		elseif cursor_mode==3 then 
			spr(6,_x-2,_y - 4)
		end
	end
end


---------------------------------------------------- POLYGON EDIT
function update_mode_polygon()
	-- if(keyboard_tab)show_points = not show_points
	if keyboard_tab then 
		ACTIVE_POLY_INDEX = (ACTIVE_POLY_INDEX%#POLYGONS)+1
		ACTIVE_POLY_OBJECT = POLYGONS[ACTIVE_POLY_INDEX]
	end

	foreach(ACTIVE_POLY_OBJECT, update_point)

	-- check to see if the cursor is hovering over an edge
	NEW_POINT_PREVIEW = nil
	if not cursor_selection then
		local curs = new_point(MOUSE_X, MOUSE_Y)
		local closest_collision,collided_obj,collision_info = 999,nil,{}
		for i=1,#ACTIVE_POLY_OBJECT do 
			local p1,p2 = ACTIVE_POLY_OBJECT[i],ACTIVE_POLY_OBJECT[i].next
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
	if cursor_selection and MOUSE_RIGHT_RELEASE and abs(drag_update_x)<=2 and abs(drag_update_y)<=2 then 
		cursor_selection.prev.next = cursor_selection.next 
		cursor_selection.next.prev = cursor_selection.prev
		
		del(ACTIVE_POLY_OBJECT,cursor_selection)

		-- shape has no objects left
		if #POLYGONS[ACTIVE_POLY_INDEX] < 3 then 
			delete_polygon(ACTIVE_POLY_INDEX)
		end
	end

	-- add new point on left click
	if NEW_POINT_PREVIEW and MOUSE_CLICK then 
		local new_point = add(ACTIVE_POLY_OBJECT,new_point(NEW_POINT_PREVIEW.x, NEW_POINT_PREVIEW.y, ACTIVE_POLY_OBJECT))

		NEW_POINT_PREVIEW.prev.next = new_point
		NEW_POINT_PREVIEW.next.prev = new_point

		new_point.prev = NEW_POINT_PREVIEW.prev
		new_point.next = NEW_POINT_PREVIEW.next

		new_point.is_dragging = true
	end
end

function update_ui_polygon()
	if mouseY_raw < 8 then
		for i=1,#POLYGONS do
			local _x = (i*9)-8
			if mouseX_raw > _x and mouseX_raw < _x+9 then 
				cursor_mode = 2

				if MOUSE_CLICK then 
					ACTIVE_POLY_INDEX = i 
					ACTIVE_POLY_OBJECT = POLYGONS[i]
				end
			end
		end

		local _x = (#POLYGONS*9)+3
		if mouseX_raw > _x and mouseX_raw < _x + 9 then 
			cursor_mode = 2

			if MOUSE_CLICK then 
				create_polygon(CAMERA_X + 64,CAMERA_Y + 64,split"-10,-10,10,-10,10,10,-10,10")
				ACTIVE_POLY_INDEX = #POLYGONS
				ACTIVE_POLY_OBJECT = POLYGONS[#POLYGONS]
			end
		end
	end
end

function draw_mode_polygon()
	for _poly in all(POLYGONS) do
		if(_poly!=ACTIVE_POLY_OBJECT)draw_poly(_poly)
	end
	draw_poly(ACTIVE_POLY_OBJECT)

	if NEW_POINT_PREVIEW!=nil then 
		circ(NEW_POINT_PREVIEW.x, NEW_POINT_PREVIEW.y, 2, 7)
	end
end

function draw_ui_polygon()
	for i=1, #POLYGONS do
		local _x,_y=CAMERA_X+3 + (i-1)*9, CAMERA_Y
		if(ACTIVE_POLY_INDEX == i)pal(14,7)
		spr(2, _x, _y)
		if(ACTIVE_POLY_INDEX == i)pal(14,14)
		print(i-1, _x+3, _y+2, 8)
	end
	spr(3,CAMERA_X+3 + (#POLYGONS)*9, CAMERA_Y)
end


---------------------------------------------------- PLACE PARTS

function goto_parts()
	show_selector = false

	part_option_texts=split"flipper,bumper,pop bumper,ramp"

	placable,selected = nil,nil
end

part_x,part_y,part_w,part_h=80,30,32,60
function update_ui_parts()
	if mouseY_raw < 8 then 
		if mouseX_raw >= 1 and mouseX_raw < 28 then 

			-- kill placable
			placable = nil

			show_selector = true
		end
	end

	local unselected_on_frame = nil
	local hover = mouse_hb(part_x, part_y, part_w + 2, part_h)
	if selected and not hover then 
		if MOUSE_CLICK or MOUSE_RIGHT_CLICK then 
			unselected_on_frame=selected
			new_selected()

			-- allow you to drag straight away
			if MOUSE_RIGHT_CLICK then 
				drag_next = t+1
			end
		end
	end

	local placed_on_frame = false
	-- place one down
	if placable then
		placable.x = mouseX_raw + CAMERA_X
		placable.y = mouseY_raw + CAMERA_Y

		if MOUSE_CLICK then 
			add(PARTS,placable)

			new_selected(placable)

			placable = nil
			placed_on_frame=true

		elseif MOUSE_RIGHT_RELEASE and drag_update_x <1 and drag_update_y <1 then
			placable = nil
		end
	end

	-- click and pick up placed obbjects
	local mx,my = MOUSE_X, MOUSE_Y
	local hover_part = nil
	for part in all(PARTS) do 
		local dist = calc_dist2(part.x, part.y, MOUSE_X, MOUSE_Y)

		part.hover = dist<10

		if(part.hover)hover_part = part
	end

	-- debug(#PARTS)

	-- click on object on map
	if hover_part and not placable and MOUSE_CLICK and not placed_on_frame then 
		if unselected_on_frame and hover_part==unselected_on_frame then 
			placable, selected = unselected_on_frame, placable
			del(PARTS,placable)
		else
			new_selected(hover_part)
		end	
		-- del(PARTS, hover_part)
	end
	
end

function draw_mode_parts()
	for _poly in all(POLYGONS) do
		foreach(_poly,draw_iPointLine)
	end

	foreach(PARTS, draw_part)

	-- draw current placing object thing
	if placable then 
		draw_part(placable)
	end
end

function draw_part(_p)
	local sel = _p == placable or _p == selected 
	
	local rad = 3
	local col = sel and 7 or _p.hover and 6 or 13

	circfill(_p.x, _p.y, rad, 0)
	circ(_p.x, _p.y, rad, col)

	if _p.type == "flipper" then 
		local is_left,length,rest_direction,active_angle=unpack(_p.data)
		
		local x2,y2 = _p.x + sin(rest_direction + active_angle) * length, _p.y + cos(rest_direction + active_angle) * length
		line(_p.x, _p.y, x2, y2, sel and 13 or 5)

		local x2,y2 = _p.x + sin(rest_direction) * length, _p.y + cos(rest_direction) * length
		line(_p.x, _p.y, x2, y2, col)
	end
end




function draw_ui_parts()
	if(show_selector)pal(14,2)
	spr(2, CAMERA_X + 3, CAMERA_Y)
	if(show_selector)pal(14,14)
	rectfill(CAMERA_X + 6, CAMERA_Y + 1, CAMERA_X + 26, CAMERA_Y + 7, show_selector and 2 or 14)
	print("parts", CAMERA_X + 6, CAMERA_Y + 2, 8)


	if show_selector then 
		local found = false
		for i=1,#part_option_texts do 
			local _text = part_option_texts[i]

			local _x,_y,_w,_h = 3, 9 + (i-1)*7,#_text*4, 6

			-- the max line is some arbitrary minumum width to make it a bit nicer
			local hover = mouse_hb(3, 7 + (i-1)*7,max(40, #_text*4), 8)
			if hover then 
				found = true
				SELECTION_INFO = "create " .. _text
				
				-- clicked on button to make new object
				if MOUSE_CLICK then 
					new_part_placable(_text)
				end
			end

			local _x,_y,_w,_h = CAMERA_X + 3, CAMERA_Y + 8 + (i-1)*7,#_text*4, 6
			rectfill(_x,_y,_x+_w,_y+_h,hover and 7 or 14)

			print(_text, _x + 1, _y + 1, hover and 14 or 7)
		end
		if not (CURSOR_IN_UI and MOUSE_X < 64) and not found then 
			show_selector = false
		else
			if(mouseY_raw>8)cursor_mode=2
		end
	end

	if(selected)draw_part_editor(selected,30,30)
end

function mouse_hb(_x, _y, _w, _h)
	if(is_typing)return false

	return mouseX_raw > _x and mouseX_raw < _x + _w and mouseY_raw > _y and mouseY_raw < _y + _h
end

function new_typing(_pass)
	is_typing = true
	type_pass = _pass 
	type_temp = ""
end


function new_selected(_part)
	selected = _part or nil

	selinfo_index = 1
	if _part then 
		can_drag = false
	else 
		can_drag = true
	end
end

function new_part(_type)
	show_selector = false
	place_object = true

	part = {
		x = MOUSE_X,
		y = MOUSE_Y,

		type = _type,
		name = gen_name(),

		index = -1,
		data = {},
	}

	if _type == "flipper" then 
		part.index = 1
		part.data = {true, 20, .8, -.12}
	end
end


part_settings = {
	split"????",
	split"side,lgth,rest,actv", 		-- flipper
	split"pwr",
}

-- secondary list to the above , used for tooltips
setting_descriptors = {
	split"????",
	split"left side flipper?,flipper length,resting angle,active angle change", 		-- flipper
	split"pwr", 						-- pop bumper
}

-- secondary list to the above , used for tooltips
setting_iterators = {
	split"????",
	split"bool,1,-.01,.02", 		-- flipper
	split"pwr", 						-- pop bumper
}
function draw_part_editor(_part)
	local colours = split"0,1,7,0,0"
	local _x,_y = CAMERA_X + 80, CAMERA_Y + 30
	local _w,_h = 32, 60

	for i=4,0,-1 do 
		rectfill(_x-i,_y-i,_x+_w+i,_y+_h+i,colours[i+1])
	end

	print("edit", _x + _w*.5 + tcentre("edit"), _y + 1, 6)

	local type_hover = mouse_hb(_x - CAMERA_X, _y+6 - CAMERA_Y, _w, 6)
	if type_hover then 
		cursor_mode = 3

		if MOUSE_CLICK then
			new_typing("part_name")
		end
	end
	local name = is_typing and type_pass=="part_name" and type_temp or _part.name
	local _text = '"' .. name .. '"'
	print(_text, _x + _w*.5 + tcentre(_text), _y+7, 7)
	

	local part_index = _part.index==-1 and 1 or _part.index+1
	local _test = part_settings[part_index]
	for i=1,#_part.data do 
		local _text, y = _test[i], _y+11+i*6
		local data=_part.data[i]

		if type(data)=="boolean" then 
			local x = _x + 27
			rect(x, y, x + 4, y+4, 7)

			if(data)spr(5, x, y)
		else
			local str = sub(data,-4)
			print(str, _x+_w+tright(tostr(str))-1, y ,6)
		end

		local hover = mouse_hb(_x - CAMERA_X, y - CAMERA_Y - 1, _w, 6)
		if hover then 
			cursor_mode = 2

			SELECTION_INFO = setting_descriptors[part_index][i]

			-- clicking on the UI
			if MOUSE_CLICK or MOUSE_RIGHT_CLICK then 
				if type(data)=="boolean" then 
					_part.data[i] = not data

					if(_part.type=="flipper")_part.data[3] = (_part.data[3]+.5)%1
				else
					local change = setting_iterators[part_index][i] * (MOUSE_CLICK and 1 or -1)
					_part.data[i] = round(_part.data[i] + change,2)
				end
			end
		end

		print(_text, _x+1, y ,hover and 6 or 13)
		
	end
end

function round(num, numDecimalPlaces)
    numDecimalPlaces = min(numDecimalPlaces or 0, 2)
    local mult = 10^(numDecimalPlaces or 0)
    return flr(num * mult + 0.5) / mult
end

function tcentre(_text)
	return #_text*-2+1
end

function tright(_text)
	return #_text*-4+2
end


---------------------------------------------------- ELSE
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
	local width = 16
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

function draw_poly(_poly)
	foreach(_poly,draw_iPointLine)
	if(_poly==ACTIVE_POLY_OBJECT and show_points)foreach(_poly,draw_iPoint)
end

function draw_iPoint(_point)
	local col=_point.hover and 7 or 13

	if(_point.line_hover or _point.prev.line_hover)col = 6

	circfill(_point.x,_point.y, 3,0)
	circ(_point.x, _point.y, 3, col)
	circfill(_point.x, _point.y, 1, col)
end

function draw_iPointLine(_point)
	local line_col = 5

	if current_mode == "polygon edit" then
		if(_point.parent==ACTIVE_POLY_OBJECT)line_col=13
		if(_point.hover or _point.next.hover) line_col = 6
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
	for _poly in all(POLYGONS) do
		out..=poly_to_string(_poly) .. "\n"
	end
	out = sub(out,1,-2).."]]"

	out..="\npart_library=[["
	for _part in all(PARTS) do 
		out..=part_to_string(_part) .. "\n"
	end
	if(#PARTS>0)out = sub(out,1,-2)
	out..="]]"

	printh(out, "inf_mapdata.txt", true)
end

-- contains all the little info to convert a part into a string
function part_to_string(_part)
	local out = table_to_string({_part.type, _part.name, _part.x, _part.y})

	if _part.type == "flipper" then 
		out..=","..table_to_string(_part.data)
	end

	return out
end

-- converts a polygon into a big string of variables
function poly_to_string(_polygon)
	local out = ""

	local steps = 0
	local point = _polygon[1]
	while steps < #_polygon do 
		out..= point.x .. "," .. point.y ..","
		
		steps += 1
		point = point.next
	end

	return sub(out,1,-2)
end

-- converts a table into a string , yay
function table_to_string(_table)
	local out = ""
	for item in all(_table) do 
		out..=tostr(item) ..","
	end
	return sub(out,1,-2)
end




__gfx__
00000000010000000000000000000000000000000000000011111000000000000000000088888888888888888888888800000000000000000000000000000000
000000001710000000eeeeee00000000000070000777000017771000000000000000000088228888822222288888822800000000000000000000000000000000
00700700177100000eeeeeee00000000000077000777000011711000000000000000000082822888828888288882282800000000000000000000000000000000
0007700017771000eeeeeeee0000e000000077700777000001710000000000000000000082222828828888288228882800000000000000000000000000000000
0007700017777100eeeeeeee000eee00000077000000000001710000000000000000000088228228822222288228882800000000000000000000000000000000
0070070017711000eeeeeeee0000e000000070000000000011711000000000000000000088882288822882288882282800000000000000000000000000000000
0000000001101000eeeeeeee00000000000000000000000017771000000000000000000088822888822882288888822800000000000000000000000000000000
0000000000000000eeeeeeee00000000000000000000000011111000000000000000000088888888888888888888888800000000000000000000000000000000
00010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00171000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00171101000001010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00171717100017171710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01177777100117777710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
17177777101717777710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01777777100177777710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00117771000011777100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00017771000001777100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00001110000000111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
