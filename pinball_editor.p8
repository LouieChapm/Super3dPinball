pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

DEBUG = ""
DEBUGTIME = 0

SELECTION_INFO = "none"
CURSORXYSTRING = ""

-- drag_next starts a drag on the next avaiable frame
can_drag, drag_next = true, -1
drag_update_x, drag_update_y=0,0

show_points = true

current_mode_index = 1
modes_names=split"polygon edit,place parts,spline edit,place sensors"
num_ui_modes = #modes_names
modes_ui_x = 126 - num_ui_modes*9 		-- horizontal place to start drawing modes ui buttons

-- camera zoom levels
ZOOM_SCALE, ZOOM_OX, ZOOM_OY = 1, 64, 64
ZOOM_CURRENT, ZOOM_T = false, 1


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

	-- goto_splines()
	-- debug(dget(2))
	
	local goto_target = dget(2)
	if(goto_target==0)goto_target = 1
	goto_goto(goto_target)
end

function init_part(_datastr)
	local data = split(_datastr)
	local part_type = deli(data,1)

	if part_type=="flipper" then 
		new_flipper(data) -- todo fix this
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

function easeinoutquad(t)
    if(t<.5) then
        return t*t*2
    else
        t-=1
        return 1-t*t*2
    end
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

function _update()
	mouseX_raw,mouseY_raw=stat(32),stat(33)

	current_mode = modes_names[current_mode_index]

	t+=1
	if(DEBUGTIME>0)DEBUGTIME-=1
	if(DEBUGTIME==0)DEBUG=""


	cursor_selection=nil
	SELECTION_INFO = ""

	local mx,my = world_to_screen(MOUSE_X, MOUSE_Y)
	CURSORXYSTRING = "x:" .. ((MOUSE_X - MOUSE_X%SNAP)) .. " y:" .. (MOUSE_Y - MOUSE_Y%SNAP)
	if(not ZOOM_INACTIVE)CURSORXYSTRING = "zoom active"		-- hide the cursor coordinates when zoomed out bc I can't figure it out todo ?

	
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

	keyboard_delete = false 
	if(p=="\b")keyboard_delete=true 


	
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

function gen_name(_num)
	part_num = _num or 0

	part_num+=1
	return "part" .. sub("0"..part_num, -2)
end

function update_camera()

	-- zoom
	MOUSE_WHEEL = stat(36)
	
	-- if do mouse wheel zoom thing
	if MOUSE_WHEEL!=0 and ZOOM_T%1==0 then
		deselect_everything()

		if MOUSE_WHEEL == -1 and ZOOM_T == 1 or  MOUSE_WHEEL== 1 and ZOOM_T == 0 then
			ZOOM_CURRENT = true
			ZOOM_RATE = zoom_speed * MOUSE_WHEEL
		end
	end

	if ZOOM_CURRENT then 
		ZOOM_T = mid(0, ZOOM_T + ZOOM_RATE, 1)

		-- lerp the camera based on zoom ? unsure ?
		-- CAMERA_X = lerp(-96, -64, easeinoutquad(ZOOM_T))
		-- CAMERA_Y = lerp(-96, -64, easeinoutquad(ZOOM_T))

		if ZOOM_T == 0 or ZOOM_T == 1 then 
			ZOOM_CURRENT = false
		end
	end

	ZOOM_INACTIVE = ZOOM_T >= 1
	ZOOM_SCALE = lerp(min_zoom, max_zoom, easeinoutquad(ZOOM_T))


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

	if ZOOM_T%1!=0 then 
		if(CAMERA_DRAGGING)end_drag()
	end

	if MOUSE_RIGHT_CLICK and can_drag or drag_next==t then 
		if(ZOOM_T%1==0)start_drag()
	end

	if CAMERA_DRAGGING and can_drag then 
		drag_update_x, drag_update_y = drag_origin_x - mouseX_raw, drag_origin_y - mouseY_raw


		if not mouse_has_dragged and abs(drag_update_x)>3 or abs(drag_update_y)>3 then 
			mouse_has_dragged = true
		end

	end

	if CAMERA_DRAGGING and not MOUSE_RIGHT then 
		end_drag()	
	end
end

function start_drag()
	CAMERA_DRAGGING = true 

	cam_origin_x, cam_origin_y = CAMERA_X, CAMERA_Y 
	drag_origin_x,drag_origin_y = mouseX_raw, mouseY_raw

	mouse_has_dragged = false		-- a little checker for RIGHT_UP checks to see whether a drag has occuered
end

function end_drag()
	CAMERA_DRAGGING = false
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

	placable, selected = nil, nil 			-- deselect current object
	cursor_selection = nil					-- for polygon editor
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

SNAP = 1
function update_point(_point)
	_point.hover = false
	_point.line_hover = false

	-- todo eventually calculate which circle is nearer !
	-- and only activate that one
	if cursor_selection==nil and not CURSOR_IN_UI and calc_dist2(_point.x, _point.y, MOUSE_X, MOUSE_Y)<8 then 
		_point.hover = true

		cursor_selection = _point
		SELECTION_INFO = "move point"

		cursor_mode = 2
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
	-- splines
	if(current_mode=="place sensors")draw_ui_sensors()

	do -- bottom ui
		rectfill(CAMERA_X, CAMERA_Y+121, CAMERA_X+128, CAMERA_Y+128, 8)

		local debug_text = DEBUGTIME>0 and DEBUG or SELECTION_INFO
		print(debug_text, CAMERA_X+1, CAMERA_Y+122, 2)

		-- dont draw cursor xy if the debugtext is too long
		if(#debug_text < 20)print(CURSORXYSTRING, CAMERA_X+128 - #CURSORXYSTRING*4, CAMERA_Y+122, 2)
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

function goto_polygon()
	cursor_selection = nil
end

function update_mode_polygon()

	debug(cursor_selection)

	-- if(keyboard_tab)show_points = not show_points
	if keyboard_tab then 
		ACTIVE_POLY_INDEX = (ACTIVE_POLY_INDEX%#POLYGONS)+1
		ACTIVE_POLY_OBJECT = POLYGONS[ACTIVE_POLY_INDEX]
	end

	if ZOOM_INACTIVE then 
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

					cursor_mode = 2
				end
			end
		end

		-- delete selection on right click
		if cursor_selection and MOUSE_RIGHT_RELEASE and not mouse_has_dragged then 
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
	else
		NEW_POINT_PREVIEW = nil
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
		local x,y = world_to_screen(NEW_POINT_PREVIEW.x, NEW_POINT_PREVIEW.y)
		circ(x, y, 2, 7)
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

	part_option_texts=split"flipper,pop bumper,ramp"

	placable,selected = nil,nil
end

part_x,part_y,part_w,part_h=80,30,32,60
function update_ui_parts()

	if(not ZOOM_INACTIVE) show_selector=false goto disable_button		-- don't let the user use the button if zoomed
	if mouseY_raw < 8 and mouseX_raw >= 1 and mouseX_raw < 28 then 		-- hovering over button

		-- kill placable
		placable = nil

		show_selector = true											-- show selection ui
	end
	::disable_button::

	local unselected_on_frame = nil
	if(not ZOOM_INACTIVE)return


	-- check to see if the cursor is in UI
	local hover = selected and mouse_hb(part_x, part_y, part_w + 2, part_h)

	-- select new part assuming that it's not covered by the UI
	if selected and not hover then 
		if MOUSE_CLICK or MOUSE_RIGHT_RELEASE and not mouse_has_dragged then 
			unselected_on_frame=selected
			new_selected()
		elseif MOUSE_RIGHT_CLICK then 
			start_drag()
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

		elseif MOUSE_RIGHT_RELEASE and not mouse_has_dragged then
			placable = nil
		end
	end

	-- click and pick up placed obbjects
	local mx,my = MOUSE_X, MOUSE_Y
	local hover_part = nil

	for part in all(PARTS) do 
		local dist = calc_dist2(part.x, part.y, MOUSE_X, MOUSE_Y)

		-- don't swap objects if you're hovering over the UI
		if not hover then 
			part.hover = dist<10

			if(part.hover)hover_part = part
		else
			part.hover = false
		end
	end
	

	if(hover_part)cursor_mode = 2

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
	
	
	if selected and keyboard_delete and not is_typing then 
		del(PARTS, selected)
		selected = nil

		can_drag = true
	end
end

function draw_mode_parts()
	for _poly in all(POLYGONS) do
		foreach(_poly,draw_iPointLine)
	end

	foreach(SPLINES,draw_spline)

	foreach(SENSORS, draw_sensor)
	foreach(PARTS, draw_part)

	-- draw current placing object thing
	if placable then 
		draw_part(placable)
	end
end

function draw_part(_p)
	local sel = _p == placable or _p == selected 
	
	local rad = 3
	local col = sel and 7 or ZOOM_INACTIVE and _p.hover and 6 or current_mode=="place parts" and 13 or 5

	circfill(_p.x, _p.y, rad, 0)
	circ(_p.x, _p.y, rad, col)

	if _p.type == "flipper" then 
		local is_left,length,rest_direction,active_angle=unpack(_p.data)
		
		local x2,y2 = world_to_screen(_x + sin(rest_direction + active_angle) * length, _y + cos(rest_direction + active_angle) * length)
		line(sx, sy, x2, y2, sel and 13 or 5)

		local x2,y2 = _p.x + sin(rest_direction) * length, _p.y + cos(rest_direction) * length
		line(_p.x, _p.y, x2, y2, col)
	end
end




function draw_ui_parts()
	spr(show_selector and 7 or 2, CAMERA_X + 3, CAMERA_Y)
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
					new_part(_text, true)
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
		-- can_drag = false
	else 
		can_drag = true
	end
end

function init_part(_datastr)
	local data = split(_datastr)

	if #data > 1 then	
		new_part(data, false)
	end
end



function new_part(_data, _placable)
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
		elseif _type == "pop bumper" then 
			part.index = 2
			part.data = {8}
		else 
			debug(_type)
		end

		placable = part
	else
		-- todo holy shit is so cringe
		local _type, _name, _x, _y, _info = deli(_data,1), deli(_data,1), deli(_data,1), deli(_data,1), _data
		
		part = {
			x = _x,
			y = _y,

			type = _type,
			name = _name,

			index = -1,
			data = _info,
		}

		if(_type == "flipper") part.index = 1
		if(_type == "pop bumper") part.index = 2

		-- todo bad solution no 
		for i=1, #part.data do 
			if(part.data[i]=="true" or part.data[i]=="false")part.data[i]= part.data[i]=="true"
		end

		add(PARTS, part)
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

-- secondary list to the above , used for iterators
setting_iterators = {
	split"????",
	split"bool,1,-.01,.02", 		-- flipper
	split"pwr", 						-- pop bumper
}

pedit_w,pedit_h = 32,60
function draw_part_editor(_part)
	local colours = split"0,1,7,0,0"
	local _x,_y = CAMERA_X + 80, CAMERA_Y + 30
	local _w,_h = pedit_w,pedit_h

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

---------------------------------------------------- SPLINES

function goto_splines()
	current_mode="spline edit"
	current_mode_index = 3

	show_handles = true

	--[[
	-- test ball on spline
	ball = {
		dist 	= 10, 			-- distance along spline
		vel 	= 2,			-- velocity
		segment	= SPLINES[2], 	-- current spline segment

		x = 0, 
		y = 0,

		prev_x = 0,
		prev_y = 0,
	}
	]]--
end


function update_ui_splines()
	if(keyboard_tab)show_handles = not show_handles

	foreach(SPLINES,update_spline)

	-- update_ball(ball)
	
end

function dot_product(x1, y1, x2, y2)
	return ( x1 * x2 ) + ( y1 * y2 )
end

--[[

	move ball along spline
	"pseudo-physics" , considering finding tangent to velocity vector 
	to calculate gravity to add :/

]]
GRAVITY = .06
function update_ball(_b)
	local segment = _b.segment

	if _b.prev_x + _b.prev_y != 0 then
		local dx, dy = _b.x - _b.prev_x, _b.y - _b.prev_y   		-- find delta direction and normalize
		local gravity_force = dot_product(dx, dy, 0, 1) / _b.vel 	-- get dot product to find direction relative to gravity

		-- apply damping to slow down the ball
		local damping = .97  		-- adjust this value as needed
		_b.vel += gravity_force		-- apply gravity force
		_b.vel *= damping			-- apply damping -- tokens
	end

	_b.dist += _b.vel  	-- add velocity to ball 
	if _b.dist > segment.lengths[#segment.lengths] then 
		_b.dist -= segment.lengths[#segment.lengths]		-- reset position along segment
		_b.segment = segment.next or SPLINES[1]				-- continue movement on next spline
	elseif _b.dist < 0 then 
		_b.segment = segment.prev or SPLINES[#SPLINES]		-- continue movement on previous spline
		_b.dist += _b.segment.lengths[#_b.segment.lengths]	-- reset position along segment
	end

	local s = _b.segment				-- current spline segment
	local t = dist_to_t(s, _b.dist)		-- convert distance to t value on spline

										-- init bezier spline data
	local x1, x2, x3, x4 = s.x1, s.x1 + s.ox1, s.x2 + s.ox2, s.x2
	local y1, y2, y3, y4 = s.y1, s.y1 + s.oy1, s.y2 + s.oy2, s.y2

										-- find world x/y coordinates
	local x,y = bezier(x1,x2,x3,x4, t), bezier(y1,y2,y3,y4, t)

	_b.x, _b.prev_x = x, _b.x			-- calculate ball position and save
	_b.y, _b.prev_y = y, _b.y			-- save previous data

							-- apply gravity force to ball ?
end

--[[

	draw ball o_O

]]
function draw_ball(_b)	
	local _x, _y = world_to_screen(_b.x, _b.y)
	circfill(_x, _y, 2, 7)				-- draw circle

										-- find delta position
	local dx,dy = _b.x - _b.prev_x, _b.y - _b.prev_y

										-- draw direction line
	local factor = 7
	if(ZOOM_INACTIVE)line(_b.x, _b.y, _b.x + dx * factor, _b.y + dy * factor, 6)
end


--[[

	creates new spline object
	-- x/y and ox/oy
	-- x/y and the point origins , and ox/oy are the handle offsets

]]
function new_spline(x1,y1,ox1,oy1,x2,y2,ox2,oy2,previous)
	local spline = {}
	
	spline.x1, spline.y1 = x1,y1
	spline.x2, spline.y2 = x2,y2

	spline.ox1, spline.oy1 = ox1,oy1
	spline.ox2, spline.oy2 = ox2,oy2

	spline.hover = -1					-- -1 for none , index for active
	spline.drag = -1

	spline_get_length(spline,8) -- maybe ? used for normalising speed along spline

	spline.dist_to_t = dist_to_t		-- distance to t value function

	if previous then 					-- 
		spline.prev = previous 
		spline.prev.next = spline
	end

	return spline
end

--[[

	converts a distance to a t value along the length of a spline
	fairly inperformant , but there's definitely optimisations to be made

]]
function dist_to_t(spline, dist)
    if(dist < 0) return 0 		-- negative distance just means 0

    local LUT = spline.lengths

    local n = #LUT 				-- segment count
    local arc_length = LUT[n] 	-- total arc length

	if(dist >= arc_length)return 1	-- distance is greater than or equal to the length of the arc

    for i = 1, n do -- iterate through the list to find which segment our distance lies between
        if dist >= LUT[i - 1] and dist < LUT[i] then
			-- linearly interpolate between i and i+1 by the ratio of the distance within the segment
            return (i - 1 + (dist - LUT[i - 1]) / (LUT[i] - LUT[i - 1])) / n
        end
    end

    return nil	-- shouldn't be possible
end


--[[

	WARNING : only approximate length

	split the spline into (steps) num of segments
	gives spline "s" a LUT of lengths

	lengths is a LUT of the cumulative length of each segment totaling to length

]]
function spline_get_length(s, steps)
	local length = 0
	s.lengths = {[0]=0}								-- init table variables

	local x1,x2,x3,x4 = s.x1, s.x1 + s.ox1, s.x2 + s.ox2, s.x2	-- there has to be a better way to do this ??
	local y1,y2,y3,y4 = s.y1, s.y1 + s.oy1, s.y2 + s.oy2, s.y2

	for i=0,steps do 												-- iterate through lerp
		local t = i / steps

		local x,y = bezier(x1,x2,x3,x4, t), bezier(y1,y2,y3,y4, t)
		
		-- ignore first point
		if i > 0 then 
			length += sqrt((x-old_x)^2+(y-old_y)^2)					-- calculate distance of segment
			add(s.lengths,length)									-- add current length to lengths LUT
		end

		old_x,old_y = x,y
	end
end

function draw_mode_spline()
	for _poly in all(POLYGONS) do
		foreach(_poly,draw_iPointLine)
	end

	foreach(SENSORS, draw_sensor)
	foreach(PARTS, draw_part)

	foreach(SPLINES,draw_spline)

	-- draw_ball(ball)
end

function update_spline(s)
	if(not ZOOM_INACTIVE)return

	local rad = 5

	s.hover = -1
	if(calc_dist2(s.x1, s.y1, MOUSE_X, MOUSE_Y)<rad)s.hover = 1 
	if(calc_dist2(s.x2, s.y2, MOUSE_X, MOUSE_Y)<rad)s.hover = 4

	if(calc_dist2(s.x1 + s.ox1, s.y1 + s.oy1, MOUSE_X, MOUSE_Y)<rad)s.hover = 2
	if(calc_dist2(s.x2 + s.ox2, s.y2 + s.oy2, MOUSE_X, MOUSE_Y)<rad)s.hover = 3 

	if(s.hover>0)cursor_mode = 2

	if MOUSE_CLICK and s.hover>0 and show_handles or s.drag>0 then 
		if(s.drag<0)s.drag = s.hover

		local newX, newY = flr(MOUSE_X), flr(MOUSE_Y)

		if(s.drag==1)s.x1,s.y1 = newX,newY
		if(s.drag==4)s.x2,s.y2 = newX,newY

		-- handles 1
		if s.drag==2 then
			s.ox1,s.oy1 = newX - s.x1,newY - s.y1

			-- if there is a previous attached spline then mirror the selected values to the other spline
			-- creates smooth curves
			if s.prev then 
				s.prev.ox2, s.prev.oy2 = -s.ox1, -s.oy1
			end
		end 

		-- mirror of s.drag==2
		if s.drag==3 then
			s.ox2,s.oy2 = newX - s.x2,newY - s.y2
			if s.next then 
				s.next.ox1, s.next.oy1 = -s.ox2, -s.oy2
			end
		end
	end

	-- release the drag when not holding mouse
	if not MOUSE_HOLD then 
		s.drag = -1
	end
end

function draw_spline(s)
	local cLine, cPoint, cHandle = 2, 13, 13
	local rad = 2

	local hover_col = MOUSE_HOLD and 7 or 6

	if(current_mode!="spline edit")cLine, cPoint, cHandle = 2, 2, 2

	


	local steps = 30
	
	local x1,y1 = world_to_screen(s.x1, s.y1)
	local x2,y2 = world_to_screen(s.x1 + s.ox1, s.y1 + s.oy1)
	local x3,y3 = world_to_screen(s.x2 + s.ox2, s.y2 + s.oy2)
	local x4,y4 = world_to_screen(s.x2, s.y2)

	-- handle lines
	if show_handles and current_mode=="spline edit" then 
		line(x1, y1, x2, y2, cHandle)
		line(x4, y4, x3, y3, cHandle)
	end

	--[[
	local x1,x2,x3,x4 = s.x1, s.x1 + s.ox1, s.x2 + s.ox2, s.x2
	local y1,y2,y3,y4 = s.y1, s.y1 + s.oy1, s.y2 + s.oy2, s.y2
	]]--

	for i = 0, steps do
		local t = i / steps
	
		local x = bezier(x1, x2, x3, x4, t)
		local y = bezier(y1, y2, y3, y4, t)
	

		if i > 0 then
			line(seg_x, seg_y, x,y, cLine)
		end
	
		seg_x, seg_y = x, y
	end

	-- draw line to connect the next spline
	if s.next then 
		local _x2, _y2 = world_to_screen(s.next.x1, s.next.y1)
		line(x4, y4, _x2, _y2, 1)
	end

	--[[
	for seg in all(s.lengths) do 
		local t = s:dist_to_t(seg)
		circ(bezier(x1,x2,x3,x4,t),bezier(y1,y2,y3,y4,t),1,14)
	end
	]]--

	--[[
	do 
		local factor = 10

		-- dist to t
		local t = s:dist_to_t((time() * factor)%s.lengths[#s.lengths])
		circ(bezier(x1,x2,x3,x4,t),bezier(y1,y2,y3,y4,t),2,7)
	end
	]]--

	if show_handles and current_mode=="spline edit"  then 
		-- tolbar circles
		circ(x2, y2, rad, s.hover==2 and hover_col or cPoint)
		circ(x3, y3, rad, s.hover==3 and hover_col or cPoint)

		-- origins
		circ(x1, y1, rad+1, s.hover==1 and hover_col or cPoint)
		circ(x4, y4, rad+1, s.hover==4 and hover_col or cPoint)
	end
end

function bezier(p0,p1,p2,p3, t)
	return (1-t)*((1-t)*((1-t)*p0+t*p1)+t*((1-t)*p1+t*p2)) + t*((1-t)*((1-t)*p1+t*p2)+t*((1-t)*p2+t*p3))
end

---------------------------------------------------- SENSORS

function goto_sensors()
	current_mode="place sensors"
	current_mode_index = 4

	-- display 
	show_selector = false

	sensor_ui_options=split"box sensor,impact switch,rollover switch"

	placable = nil
end


function update_ui_sensors()
	local hover_pedit = mouse_hb(80, 30, pedit_w, pedit_h)


	if(not ZOOM_INACTIVE) show_selector=false goto disable_button		-- don't let the user use the button if zoomed
	if mouseY_raw < 8 and mouseX_raw >= 1 and mouseX_raw < 28 then  	-- if cursor is hovering over the sensor button
			show_selector = true										-- highlight selector
	end
	::disable_button::

	local sensor_hover,hover_dist = nil,9999							-- init values bc you can only hover one item
	for sensor in all(SENSORS) do 
		sensor.hover = false											-- set hover to false on everything

		if(hover_pedit or placable)goto skip_hover
		local dist = calc_dist2(sensor.x, sensor.y, MOUSE_X, MOUSE_Y)	-- find distance between sensor and cursor
		if dist<10 and dist<hover_dist then 
			sensor_hover,hover_dist = sensor,dist						-- only update if it's closer than the current
		end
		::skip_hover::
	end

	if sensor_hover then 
		sensor_hover.hover = true

		if MOUSE_CLICK then 

			if sensor_hover==selected then		-- move part
				del(SENSORS,selected)
				selected, placable = nil, selected

			else 								-- set selected to current part
				selected = sensor_hover
			end

			MOUSE_CLICK = false						-- consume the click event
		end
	end

	if placable then 
		placable.x = MOUSE_X		-- get placable to follow cursor
		placable.y = MOUSE_Y

		if MOUSE_CLICK then 						-- place sensor on board
			add(SENSORS, placable)

			selected, placable = placable, nil

			MOUSE_CLICK = false						-- consume the mouse_click event
		end
	end

	if selected then 	
		local deselect = false
		
		if MOUSE_RIGHT_RELEASE and not mouse_has_dragged then 
			deselect = true
		end

		if not hover_pedit and MOUSE_CLICK then 
			deselect = true
		end

		if(deselect)selected = nil
	end
end

function draw_mode_sensors()
	for _poly in all(POLYGONS) do
		foreach(_poly,draw_iPointLine)
	end

	foreach(SPLINES,draw_spline)
	foreach(PARTS, draw_part)



	foreach(SENSORS, draw_sensor)

	-- draw currently placable sensor
	if(placable)draw_sensor(placable)
end

function draw_ui_sensors()
	do		-- draw folder ui
		spr(show_selector and 7 or 2, CAMERA_X + 3, CAMERA_Y)
		rectfill(CAMERA_X + 6, CAMERA_Y + 1, CAMERA_X + 34, CAMERA_Y + 7, show_selector and 2 or 14)
		print("sensors", CAMERA_X + 6, CAMERA_Y + 2, 8)
	end

	if show_selector then 					-- if UI element is visible
		local found = false					-- to check where cursor is hovering over ANY elements

		for i=1,#sensor_ui_options do 				-- for each text in table of UI text
			local _text = sensor_ui_options[i]		-- grab text

			local _x,_y,_w,_h = 3, 9 + (i-1)*7,#_text*4, 6

			-- the max line is some arbitrary minumum width to make it a bit nicer
			local hover = mouse_hb(3, 7 + (i-1)*7,max(60, #_text*4), 8)
			if hover then 
				found = true							-- indicate that we've found at least one element
				SELECTION_INFO = "create " .. _text		-- set UI text to indicate selected object
														-- we could probably stop looping here , but tokens > performance xD
						
				if MOUSE_CLICK then 		-- clicked on button to make new object
					new_sensor(_text)
				end
			end

											-- draw the text , and change the colours if it's highlighted
			local _x,_y,_w,_h = CAMERA_X + 3, CAMERA_Y + 8 + (i-1)*7,#_text*4, 6
			rectfill(_x,_y,_x+_w,_y+_h,hover and 7 or 14)
			print(_text, _x + 1, _y + 1, hover and 14 or 7)

		end

												-- hide UI if no object was found
		if not (CURSOR_IN_UI and MOUSE_X < 64) and not found then 
			show_selector = false				
		else
			if(mouseY_raw>8)cursor_mode=2		-- change cursor sprite
		end
	end

	if(selected)draw_part_editor(selected)		-- draw the object properties panel
end

function new_sensor(_data)

	if type(_data)=="string" then	
		-- creating a new blank object
		
		local sensor = {
			x = MOUSE_X,			-- x/y position
			y = MOUSE_Y,			

			type = _data,			-- object type ( e.g "box sensor" )
			name = gen_name(),		-- object name

			index = -1,				-- used for tooltips
			data = {},				-- object data ( what is editable with tooltips )
		}

		-- init object type data
		if(_data=="box sensor")sensor.data, sensor.index = {5, 5}, 3		-- { width , height }

		placable = sensor			-- set new table to current placable object
	else
		-- creating sensor with premade data

	end

end

function draw_sensor(_sensor)
	local sel, hover = _sensor == selected, _sensor.hover

	-- convert world to screen position
	local _x, _y = _sensor.x, _sensor.y
	if(_sensor == placable)_x, _y = mouseX_raw + CAMERA_X, mouseY_raw + CAMERA_Y
	local sx,sy = world_to_screen(_x, _y)

	local col = sel and 7 or hover and 6 or 13
	if(current_mode!="place sensors")col = 5

	if _sensor.type == "box sensor" then 
		local data = _sensor.data

		rect(sx - data[1]* ZOOM_SCALE, sy-data[2]* ZOOM_SCALE, sx + data[1] * ZOOM_SCALE, sy + data[2] * ZOOM_SCALE, col)
	else 
		circ(sx, sy, 6 * ZOOM_SCALE, col)
	end
end

---------------------------------------------------- LOOKUP TABLES

function new_LUT(_table)
	local LUT=_table

	return LUT
end

function LUT_get(_lut, _value)
	for value in all(_lut) do 
		
	end
end


---------------------------------------------------- CAMERA

function world_to_screen(wx, wy)
    local sx = (wx - 64) * ZOOM_SCALE + 64
	local sy = (wy - 64) * ZOOM_SCALE + 64

    return sx, sy
end



---------------------------------------------------- SPLINES

function goto_splines()
	SPLINES = {}
	add(SPLINES,new_spline(64,64,10,10,80,80,10,10))
end

function new_spline(x1,y1,ox1,oy1,x2,y2,ox2,oy2)
	local spline = {}
	
	spline.x1, spline.y1 = x1,y1
	spline.x2, spline.y2 = x2,y2

	spline.ox1, spline.oy1 = ox1,oy1
	spline.ox2, spline.oy2 = ox2,oy2

	spline.hover = -1		-- -1 for none , index for active
	spline.drag = -1

	return spline
end

function update_ui_splines()
	foreach(SPLINES,update_spline)
end

function draw_mode_spline()
	foreach(SPLINES,draw_spline)
end

function update_spline(s)
	local rad = 5

	s.hover = -1
	if(calc_dist2(s.x1, s.y1, MOUSE_X, MOUSE_Y)<rad)s.hover = 1 
	if(calc_dist2(s.x2, s.y2, MOUSE_X, MOUSE_Y)<rad)s.hover = 4

	if(calc_dist2(s.x1 + s.ox1, s.y1 + s.oy1, MOUSE_X, MOUSE_Y)<rad)s.hover = 2
	if(calc_dist2(s.x2 + s.ox2, s.y2 + s.oy2, MOUSE_X, MOUSE_Y)<rad)s.hover = 3 

	if MOUSE_CLICK and s.hover>0 or s.drag>0 then 
		if(s.drag<0)s.drag = s.hover

		local newX, newY = flr(MOUSE_X), flr(MOUSE_Y)

		if(s.drag==1)s.x1,s.y1 = newX,newY
		if(s.drag==4)s.x2,s.y2 = newX,newY

		if(s.drag==2)s.ox1,s.oy1 = newX - s.x1,newY - s.y1
		if(s.drag==3)s.ox2,s.oy2 = newX - s.x2,newY - s.y2
	end

	if not MOUSE_HOLD then 
		s.drag = -1
	end
end

function draw_spline(s)
	local c1,c2 = 13, 5
	local rad = 3

	local hover_col = MOUSE_HOLD and 7 or 6

	-- module things
	line(s.x1, s.y1, s.x1 + s.ox1, s.y1 + s.oy1, 5)
	line(s.x2, s.y2, s.x2 + s.ox2, s.y2 + s.oy2, 5)

	msg = ""

	local steps = 30
	
	local x1,x2,x3,x4 = s.x1, s.x1 + s.ox1, s.x2 + s.ox2, s.x2
	local y1,y2,y3,y4 = s.y1, s.y1 + s.oy1, s.y2 + s.oy2, s.y2

	local x1,y1=s.x1,s.y1
	for i=0, steps do 
		local t = i*(1/steps)

		local x2,y2 = bezier(x1,x2,x3,x4, t),bezier(y1,y2,y3,y4, t)
		line(x1,y1,x2,y2, 2)

		x1,y1 = x2,y2
	end
	--[[
	for i=0,1-(1/steps), 1/steps do	

		local t = i
		local x1 = bezier(x1,x2,x3,x4, t)
		local y1 = bezier(y1,y2,y3,y4, t)

		msg ..= x1 .."|"

		local t = i + 1/steps
		local x2 = bezier(x1,x2,x3,x4, t)
		local y2 = bezier(y1,y2,y3,y4, t)
		
		line(x1,y1, x2, y2, 2)

		msg ..= x2 .. " "
	end
	]]--

	debug(msg)

	local x1,x2,x3,x4 = s.x1, s.x1 + s.ox1, s.x2 + s.ox2, s.x2
	local y1,y2,y3,y4 = s.y1, s.y1 + s.oy1, s.y2 + s.oy2, s.y2

	local t = (time()*.25)%1
	circ(bezier(x1,x2,x3,x4,t),bezier(y1,y2,y3,y4,t),2,7)

	-- tolbar circles
	circ(s.x1 + s.ox1, s.y1 + s.oy1, rad, s.hover==2 and hover_col or c2)
	circ(s.x2 + s.ox2, s.y2 + s.oy2, rad, s.hover==3 and hover_col or c2)

	-- origins
	circ(s.x1,s.y1, rad+1, s.hover==1 and hover_col or c1)
	circ(s.x2,s.y2, rad+1, s.hover==4 and hover_col or c1)
end

function bezier(p0,p1,p2,p3, t)
	return (1-t)*((1-t)*((1-t)*p0+t*p1)+t*((1-t)*p1+t*p2)) + t*((1-t)*((1-t)*p1+t*p2)+t*((1-t)*p2+t*p3))
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
	local width = 16 * ZOOM_SCALE
	if ZOOM_T < .5 then 
		width *= 4
	end

	local origin_x, origin_y = CAMERA_X - CAMERA_X%width, CAMERA_Y - CAMERA_Y%width
	local start,fin = -2, 128/width

	if ZOOM_T < .5 then 
		local CX = CAMERA_X * 2
		local CY = CAMERA_Y * 2

		origin_x, origin_y = CX - CX%width, CY - CY%width

		start -=1 
		fin += 2
	end

	for x=start,fin,1 do
		for y=start,fin,1 do
			local _x,_y = origin_x + x*width,origin_y + y*width
			if (x+CAMERA_X\width+y+CAMERA_Y\width)%2==0 then 

				local sx,sy = world_to_screen(_x, _y)
				rect(sx, sy, sx+width, sy+width,_col)
			end
		end
	end
	fillp()

	local cx,cy = world_to_screen(0,0)
	circfill(cx,cy,2,0)
	circ(cx,cy,2,_col)
end

function draw_poly(_poly)
	foreach(_poly,draw_iPointLine)
	if(_poly==ACTIVE_POLY_OBJECT and show_points and ZOOM_INACTIVE)foreach(_poly,draw_iPoint)
end

function draw_iPoint(_point)
	local col=_point.hover and 7 or 13

	if(_point.line_hover or _point.prev.line_hover)col = 6

	local _x, _y = world_to_screen(_point.x, _point.y)

	circfill(_x, _y, 3,0)
	circ(_x, _y, 3, col)
	circfill(_x, _y, 1, col)
end

function draw_iPointLine(_point)
	local line_col = 5

	if current_mode == "polygon edit" then
		if(_point.parent==ACTIVE_POLY_OBJECT)line_col=13
		if(_point.hover or _point.next.hover) line_col = 6
	end

	if _point.next then 
		local x1, y1 = world_to_screen(_point.x, _point.y)
		local x2, y2 = world_to_screen(_point.next.x, _point.next.y)

		line(x1,y1, x2, y2, line_col)
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
	DEBUGTIME = _time or 90
	DEBUG = tostr(_msg)
end


-->8
-- data handing
function export_data()
	dset(0,CAMERA_X)
	dset(1,CAMERA_Y)

									-- polygon library
	local out = "poly_library=[["
	for _poly in all(POLYGONS) do
		out..=poly_to_string(_poly) .. "\n"
	end
	if(#POLYGONS>0)out = sub(out,1,-2)
	out..="]]"

									-- part library
	out..="\npart_library=[["
	for _part in all(PARTS) do 
		out..=part_to_string(_part) .. "\n"
	end
	if(#PARTS>0)out = sub(out,1,-2)
	out..="]]"

	out..="\nsensor_library=[["
	for _sensor in all(SENSORS) do 
		out..=sensor_to_string(_sensor) .. "\n"
	end
	if(#SENSORS>0)out = sub(out,1,-2)
	out..="]]"

									-- spline library
	out..="\nspline_library=[["
	for _spline in all(SPLINES) do 
		out..= spline_to_string(_spline) .. ":" .. table_to_string(_spline.lengths) .. "|"
	end
	if(#SPLINES>0)out = sub(out,1,-2)
	out..="]]"

	printh(out, "inf_mapdata.txt", true)
end

-- converts a spline into a string
function spline_to_string(s)
	local out = table_to_string({s.x1,s.y1,s.ox1,s.oy1,s.x2,s.y2,s.ox2,s.oy2})

	return out
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
