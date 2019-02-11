menu = {}
menu.__index = menu

--- Constructor
function menu.__make(params, parent, root)
	local m = {}           -- Our new object
	setmetatable(m,menu)   -- Make menu handle lookup
	m.type = "menu"
	m.subtype = params.subtype
	m.varname = params.varname
	m.default = params.default
	m.title = params.title or "New Menu"
	m.description = params.description
	m.items = {}
	m.selected = 1
	m.func = params.func

	if parent then         -- Only sub menus have a parent
		m.parent = parent
		m.root = root
	else                   -- Root menu
		m.config = params.config
		m.draw_funcs = {}
		m.current_submenu = m
		m.isroot = true
		m.parent = m       -- Root is its own parent
		m.root = m         -- Roots root is itself
		m.isvisible = false
		m.keyprompt = false
		-- Menu options
		m.opts = params.opts or {}
		if not params.opts then params.opts = {} end
		m.opts.help               = params.opts.help               or true
		m.opts.x                  = params.opts.x                  or 150
		m.opts.y                  = params.opts.y                  or 100
		m.opts.item_width         = params.opts.item_width         or 300
		m.opts.item_height        = params.opts.item_heigth        or 25
		m.opts.item_padding       = params.opts.item_padding       or 1
		m.opts.desc_x             = params.opts.desc_x             or 0
		m.opts.desc_y             = params.opts.desc_y             or 0
		m.opts.fg                 = params.opts.fg                 or rgba(255,255,255,200)
		m.opts.fg_var             = params.opts.fg_var             or rgba(255,200,0,255)
		m.opts.bg                 = params.opts.bg                 or rgba(0,0,0,120)
		m.opts.fg_sel             = params.opts.fg_sel             or rgb(0,0,0)
		m.opts.bg_sel             = params.opts.bg_sel             or rgba(255,225,130,255)
		m.opts.fg_header          = params.opts.fg_header          or rgba(255,255,255, 200)
		m.opts.bg_header          = params.opts.bg_header          or rgba(0,0,0,185)
		m.opts.fg_sep             = params.opts.fg_sep             or rgba(255,255,255,220)
		m.opts.key_menu_toggle    = params.opts.key_menu_toggle    or "F1"
		m.opts.key_menu_prev      = params.opts.key_menu_prev      or "Up"
		m.opts.key_menu_next      = params.opts.key_menu_next      or "Down"
		m.opts.key_menu_parent    = params.opts.key_menu_parent    or "Left"
		m.opts.key_menu_enter     = params.opts.key_menu_enter     or "Right"
		m.opts.key_menu_inc_var   = params.opts.key_menu_inc_var   or "MouseScrollUp"
		m.opts.key_menu_dec_var   = params.opts.key_menu_dec_var   or "MouseScrollDown"
		m.opts.key_menu_reset_var = params.opts.key_menu_reset_var or "MiddleMouseButton"
	end

	return m  -- Return this menu
end
function menu.create(params)
	-- Wrapper to create the root menu
	return menu.__make(params, nil, nil)
end

function menu:__recursive_write_vars(menu, tlookup)
	
	for k,v in pairs(menu.items) do

		if v.varname ~= nil then
			-- Lookup if 
			if v.varname:find("[.]") then
				if type(self:get_var("tlookup." .. v.varname)) ~= "table" then

					local str = ""
					local var = tlookup
					for w, d in v.varname:gmatch("([%w_]+)(.?)") do
						if d == "." then           -- Not last field?
							if tonumber(w) then
								str = str .. "[" .. w .. "]"
								w = tonumber(w)
							else
								str = #str > 0 and str .. "." .. w or w
							end
							if var[w] == nil then
								io.write(str .. " = {}\n")
							end
							var[w] = var[w] or {}  -- Create table if absent
							var = var[w]           -- Get the table
						end
					end
				end
			end

			local val = self:get_var(v.varname)
			local str

			if (v.subtype == nil or v.subtype == "keybind") then

				if type(val) == "string" then
					str = "\"" .. val .. "\""
				elseif type(val) == "boolean" then
					str = val and "true" or "false"
				else
					str = val
				end
				io.write(string.format("%-36s = %s\n", v.varname:gsub("[.]([%d]+)", "[%1]"), str))
			else
				if v.subtype == "color" then
					io.write(string.format("%-36s = rgba(%s,%s,%s,%s)\n", v.varname:gsub("[.]([%d]+)", "[%1]"), val.r, val.g, val.b, val.a))
				elseif v.subtype == "fvector" then
					io.write(string.format("%-36s = Vector(%s,%s,%s)\n", v.varname:gsub("[.]([%d]+)", "[%1]"), val.x, val.y, val.z))
				end
			end
		end

		if v.type == "menu" and v.subtype == nil then
			self:__recursive_write_vars(v, tlookup)
		end
	end
end

function menu:write_config()
	if self.config == nil then return end

	local title = self.root.title or "Menu"

	local path = config.getPath() .. self.root.config
	local cfg = io.open(path , "w")

	if not cfg then 
		consoleRGB(title .. " error: could not open " .. self.root.config .. " for writing", rgb(255,0,0))
		notify(title .. " error", "Could not open " .. self.root.config .. " for writing")
		return
	end

	io.output(cfg)  -- Set default output file

	io.write("-- Auto generated by " .. title .. "\n")

	local tlookup = {}
	self:__recursive_write_vars(self, tlookup)

	notify(title, "Settings saved")
	cfg:close()
end

--- Data retrieval
function menu:get_current_menu()
	if self.isroot then  -- Return sub menu when called from root
		return self.current_submenu
	else                 -- Otherwise return ourself
		return self
	end
end

function menu:get_items()
	return self.items
end

function menu:get_item(pos)
	return self.items[pos]
end

function menu:get_selected_item()
	return self.items[self.selected]
end

function menu:get_item_count()
	return #self.items
end

function menu:get_var(name)
	local var = _G                     -- Start with the table of globals
	for w in name:gmatch("[%w_]+") do  -- Split by periods to traverse down tables
		if tonumber(w) then
			w = tonumber(w)
		end
		if var[w] == nil then return nil end
		var = var[w]
	end
	return var
end

function menu:set_var(name, value)
	local var = _G                 -- Start with the table of globals
	for w, d in name:gmatch("([%w_]+)(.?)") do
		if tonumber(w) then
			w = tonumber(w)
		end
		if d == "." then           -- Not last field?
			var[w] = var[w] or {}  -- Create table if absent
			var = var[w]           -- Get the table
		else                       -- Last field
			var[w] = value         -- Do the assignment
		end
	end
end

--- Variable manipulation
function menu:increment_var()
	if self.root.isvisible then
		local m = self.root.current_submenu
		local item = m.items[m.selected]

		if item.type ~= "variable" then return end

		local val = self:get_var(item.varname)

		-- Booleans just need their value inverted
		if type(val) == "boolean" then
			self:set_var(item.varname, not val)
		elseif type(val) == "number" then
			-- Return if we don't know by how much to increment
			if item.inc == nil or item.inc == 0 then return end
			
			val = val + item.inc

			-- Is there a max and are we over it?
			if item.max ~= nil then
				if val > item.max then
					-- Roundabout if there is a min, otherwise lock to the max
					val = item.min ~= nil and item.min or item.max
				end
			end
			
			if m.subtype == "color" then
				local col = rgba(
					self:get_var(m.varname .. ".r"),
					self:get_var(m.varname .. ".g"),
					self:get_var(m.varname .. ".b"),
					self:get_var(m.varname .. ".a")
				)

				local member = item.varname:match("([%w])$")
				col[member] = val
				self:set_var(m.varname, col)
			elseif m.subtype == "fvector" then
				local vec = Vector(
					self:get_var(m.varname .. ".x"),
					self:get_var(m.varname .. ".y"),
					self:get_var(m.varname .. ".z")
				)

				local member = item.varname:match("([%w])$")
				vec[member] = val
				self:set_var(m.varname, vec)
			else
				-- Set the variable
				self:set_var(item.varname, val)	
			end
		end
	end
end

function menu:decrement_var()
	if self.root.isvisible then
		local m = self.root.current_submenu
		local item = m.items[m.selected]

		if item.type ~= "variable" then return end

		local val = self:get_var(item.varname)

		-- Booleans just need their value inverted
		if type(val) == "boolean" then
			self:set_var(item.varname, not val)
		elseif type(val) == "number" then
			-- Return if we don't know by how much to increment
			if item.inc == nil or item.inc == 0 then return end
			
			val = val - item.inc

			-- Is there a min and are we under it?
			if item.min ~= nil then
				if val < item.min then
					-- Roundabout if there is a max, otherwise lock to the min
					val = item.max or item.min
				end
			end
			
			if m.subtype == "color" then
				local col = rgba(
					self:get_var(m.varname .. ".r"),
					self:get_var(m.varname .. ".g"),
					self:get_var(m.varname .. ".b"),
					self:get_var(m.varname .. ".a")
				)

				local member = item.varname:match("([%w])$")
				col[member] = val
				self:set_var(m.varname, col)
			elseif m.subtype == "fvector" then
				local vec = Vector(
					self:get_var(m.varname .. ".x"),
					self:get_var(m.varname .. ".y"),
					self:get_var(m.varname .. ".z")
				)

				local member = item.varname:match("([%w])$")
				vec[member] = val
				self:set_var(m.varname, vec)
			else
				-- Set the variable
				self:set_var(item.varname, val)	
			end
		end
	end
end

function menu:reset_var()
	if self.root.isvisible then
		local m = self.root.current_submenu
		local item = m.items[m.selected]

		if item.varname ~= nil and item.default ~= nil then
			if item.type == "menu" then
				if item.subtype == "color" then
					self:set_var(item.varname, rgba(
						item.default.r,
						item.default.g,
						item.default.b,
						item.default.a
					))
				elseif item.subtype == "fvector" then
					self:set_var(item.varname, Vector(
						item.default.x,
						item.default.y,
						item.default.z
					))
				end
			elseif m.subtype == "color" then
				local col = rgba(
					self:get_var(m.varname .. ".r"),
					self:get_var(m.varname .. ".g"),
					self:get_var(m.varname .. ".b"),
					self:get_var(m.varname .. ".a")
				)

				local member = item.varname:match("([%w]+)$")
				col[member] = item.default
				self:set_var(m.varname, col)
			elseif m.subtype == "fvector" then
				local vec = Vector(
					self:get_var(m.varname .. ".x"),
					self:get_var(m.varname .. ".y"),
					self:get_var(m.varname .. ".z")
				)

				local member = item.varname:match("([%w]+)$")
				vec[member] = item.default
				self:set_var(m.varname, vec)
			else
				self:set_var(item.varname, item.default)
			end
		end
	end
end

--- Navigation
function menu:go_enter()
	-- TODO: find first non sep when entering. Only do that when there are
	-- items and more than 1 if the current is a separator, ezpz
	if self.root.isvisible then
		local title = self.root.title or "Menu"
		local m = self.root.current_submenu
		local selected = m:get_selected_item()

		-- Call attached function if there is one
		if type(selected.func) == "function" then
			selected.func(m, selected)
		end

		if selected.type == "menu" then
			-- Items of type menu just change the current sub menu
			m.root.current_submenu = selected
		elseif selected.type == "variable" then
			if m.subtype == "color" then
				local var = self:get_var(m.varname)
				local str = string.format("/lua %s = rgba(%s, %s, %s, %s)", m.varname:gsub("[.]([%d]+)", "[%1]"), var.r, var.g, var.b, var.a)
				openConsole(str)
			elseif m.subtype == "fvector" then
				local var = self:get_var(m.varname)
				local str = string.format("/lua %s = Vector(%s, %s, %s)", m.varname:gsub("[.]([%d]+)", "[%1]"), var.x, var.y, var.z)
				openConsole(str)
			elseif selected.subtype == "keybind" then
				notify(title, "Press any key")
				self.root.keyprompt = true
				return
			else
				local var = self:get_var(selected.varname)
				local vartype = type(var)
				-- Assemble a string which will be pre-entered into the console
				local str = "/lua " .. selected.varname:gsub("[.]([%d]+)", "[%1]") .. " = "

				-- Append the variable to the string and open the console
				if vartype == "boolean" then
					str = var and str .. "true" or str .. "false"
					openConsole(str)
				elseif vartype == "number" then
					openConsole(str .. var)
				elseif vartype == "string" then
					openConsole(str .. "\"" .. var .. "\"")
				end
			end
		end
	end
end

function menu:go_next()
	if self.root.isvisible then
		local m = self.root.current_submenu
		local selected = m.selected + 1

		-- Roundabout
		if selected > #m.items then selected = 1 end

		-- Find the next non-separator menu entry
		while m.items[selected].type == "separator" do
			selected = selected + 1
			if selected > #m.items then selected = 1 end
		end
		m.selected = selected
	end
end

function menu:go_prev()
	if self.root.isvisible then
		local m = self.root.current_submenu
		local selected = m.selected - 1

		-- Roundabout
		if selected < 1 then selected = #m.items end

		-- Find the next non-separator menu entry
		while m.items[selected].type == "separator" do
			selected = selected - 1
			if selected < 1 then selected = #m.items end
		end
		m.selected = selected
	end
end

function menu:go_parent()
	if self.root.isvisible then
		local m = self.root.current_submenu

		-- Root has no parent, so only go up a level if we are in a sub menu
		if not m.isroot then
			-- Call attached function if there is one
			if type(m.parent.func) == "function" then
				m.parent.func(m.parent.parent, m.parent)
			end

			m.root.current_submenu = m.parent
		end
	end
end

--- Adding/Removing items
function menu:clear()
	self.selected = 1
	self.items = {}
end

function menu:add_submenu(params)
	-- A sub menu which holds items

	m = menu.__make(params, self, self.root)

	if params.position == nil then
		-- Add to the end
		table.insert(self.items, m)
	else
		-- Add at position
		table.insert(self.items, params.position, m)
	end
	return m
end

function menu:add_separator(params)
	-- A separator which can also display text if it has a title

	local t = {}
	t.type = "separator"
	t.title = params.title
	t.description = params.description
	if params.position == nil then
		-- Add to the end
		table.insert(self.items, t)
	else
		-- Add at position
		table.insert(self.items, params.position, t)
	end
end

function menu:add_item(params)
	-- Generic menu item mainly for functions or placeholders

	local t = {}
	t.type = "item"
	t.title = params.title
	t.description = params.description
	t.func = params.func

	if params.position == nil then
		-- Add to the end
		table.insert(self.items, t)
	else
		-- Add at position
		table.insert(self.items, params.position, t)
	end
end

function menu:add_variable(params)
	-- A variable

	local t = {}
	t.type = "variable"
	t.subtype = params.subtype
	t.title = params.title
	t.description = params.description
	t.default = params.default  -- Default value
	t.min     = params.min      -- The minimum value
	t.max     = params.max      -- The maximum value
	t.inc     = params.inc      -- Incrementation steps
	t.varname = params.varname  -- Name of the attached variable
	t.func    = params.func     -- Function to run

	if (t.subtype == "keybind") then
		t.dorepeat = params.dorepeat
		t.call     = params.call
	end

	-- Set the attached variable if a value is provided
	if params.value ~= nil then
		self:set_var(params.varname, params.value)
	end

	-- Try to create the variable with its default value if it does not exist
	if self:get_var(params.varname) == nil then
		self:set_var(params.varname, params.default)
	end

	if params.position == nil then
		-- Add to the end
		table.insert(self.items, t)
	else
		-- Add at position
		table.insert(self.items, params.position, t)
	end
end

function menu:add_keybind(params)
	-- A keybind
	if (params.default ~= nil and params.default ~= "" and type(params.call) == "function") then
		bindKey(params.default, Input.PRESSED, params.call)
		if (params.dorepeat) then
			bindKey(params.default, Input.REPEAT, params.call)
		end
	end

	params.subtype = "keybind"
	self:add_variable(params)
end

function menu:add_color(params)
	-- Try to create the variable with its default value if it does not exist
	if self:get_var(params.varname) == nil then
		self:set_var(params.varname, params.default)
	end

	-- Copy table so the default value will never be a
	-- reference to the current value or vice versa
	local default = {}
	if params.default ~= nil then
		default.r = params.default.r
		default.g = params.default.g
		default.b = params.default.b
		default.a = params.default.a
		params.default = default
	end

	params.subtype = "color"
	local m = self:add_submenu(params)

	local value = params.value
	local varname = params.varname

	params.description = nil
	params.min = 0
	params.max = 255
	params.inc = 1

	local names = { "Red", "Green", "Blue", "Alpha" }
	local col   = { "r", "g", "b", "a" }

	for i, v in ipairs(col) do
		if default ~= nil then
			params.default = default[v]
		end
		if value ~= nil then
			params.value = value[v]
		end
		params.title = names[i]
		params.varname = varname .. "." .. v
		m:add_variable(params)
	end

	m:add_separator({})
	m:add_item({ title = "Reset", func = function()
		if m.default ~= nil then
			self:set_var(m.varname, rgba(
				m.default.r,
				m.default.g,
				m.default.b,
				m.default.a
			))
		end
	end })

	return m
end

function menu:add_fvector(params)
	-- Try to create the variable with its default value if it does not exist
	if self:get_var(params.varname) == nil then
		self:set_var(params.varname, params.default)
	end

	-- Copy table so the default value will never be a
	-- reference to the current value or vice versa
	local default = {}
	if params.default ~= nil then
		default.x = params.default.x
		default.y = params.default.y
		default.z = params.default.z
		params.default = default
	end

	params.subtype = "fvector"
	local m = self:add_submenu(params)

	local value = params.value
	local varname = params.varname

	params.description = nil

	local names = { "X Axis - Forward/Backward", "Y Axis - Left/Right", "Z Axis - Up/Down" }
	local axes  = { "x", "y", "z" }

	for i, v in ipairs(axes) do
		if default ~= nil then
			params.default = default[v]
		end
		if value ~= nil then
			params.value = value[v]
		end
		params.title = names[i]
		params.varname = varname .. "." .. v
		m:add_variable(params)
	end

	m:add_separator({})
	m:add_item({ title = "Reset", func = function()
		if m.default ~= nil then
			self:set_var(m.varname, Vector(
				m.default.x,
				m.default.y,
				m.default.z
			))
		end
	end })

	return m
end

function menu:add_back(params)
	-- Wrapper to easily add a back button
	params.func = function() self:go_parent() end
	self:add_item(params)
end

function menu:add_exit(params)
	-- Wrapper to easily add an exit button
	params.func = function() self:hide() end
	self:add_item(params)
end

--- Displaying
function menu:show()
	if not viewPort.isMainMenuOpen() then
		-- If we are in a sub menu with an attached function, also call that
		-- function when re-opening the menu
		local m = self.root.current_submenu
		if type(m.func) == "function" then
			m.func(m.parent, m)
		end
		self.root.isvisible = true
	end
end

function menu:hide()
	self.root.isvisible = false
end

function menu:toggle()
	if not viewPort.isMainMenuOpen() then
		if self.root.isvisible then
			self:hide()
		else
			self:show()
		end
	end
end

function menu:isvisible()
	return self.root.isvisible
end

function menu:add_draw_func(func)
	table.insert(self.root.draw_funcs, func)
end

function menu:draw()
	-- Automatically close the menu when the T:A main menu is open, which
	-- also happens on map end etc. This is necessary because otherwise it's
	-- possible to navigate the menu while it can't be seen
	if viewPort.isMainMenuOpen() then
		self:hide()
		return
	end

	local x_res = viewPort.size().x
	local y_res = viewPort.size().y

	local m = self.root.current_submenu
	local r = self.root
	local style = r.opts

	-- Run all attached draw functions
	if #r.draw_funcs > 0 then
		for i = 1,#m.root.draw_funcs do
			r.draw_funcs[i](x_res, y_res)
		end
	end

	-- Only draw the menu when it's "visible"
	if not r.isvisible then return false end

	local x_pos = style.x
	local y_pos = style.y

	-- Draw color for color submenus
	if m.type == "menu" and m.subtype == "color" then
		local x_pos = style.x + style.item_width + 5
		local y_pos = style.y
		drawBox(x_pos, y_pos, x_pos + 32, y_pos + 32, rgb(0,0,0))
		drawRect(x_pos + 3, y_pos + 3, x_pos + 29, y_pos + 29, self:get_var(m.varname))
	end

	-- Draw headers
	if m.title then
		drawRect(style.x, y_pos, style.x + style.item_width, y_pos + style.item_height, style.bg_header)
		drawUTText(m.title, style.fg_header, style.x + style.item_width / 2, y_pos + style.item_height / 2, 1, 0, 0)
		y_pos = y_pos + style.item_height + style.item_padding
	end

	-- Iterate over all items of the current menu
	local i = 1
	while i <= #m.items do
		local item = m.items[i]

		-- Menu wrapping to the right if the bottom edge of the screen is reached
		-- Don't move empty separators over as first element so we don't have
		-- weird empty space at the top
		if item.title ~= nil and y_pos + style.item_height > y_res then
			y_pos = style.y
			x_pos = x_pos + style.item_width + 4

			-- Move the menu left if there is not enough space on the right to
			-- display any more wrapped menu items
			if x_pos + style.item_width > x_res then
				style.x = math.max(0, style.x - (x_pos + style.item_width - x_res))
			end
		end

		if item.type == "separator" then
			if item.title then
				drawUTText(item.title, style.fg_sep, x_pos + 5, y_pos + style.item_height - 8, 0, 1, 0)
				y_pos = y_pos + style.item_height + style.item_padding
			else
				y_pos = y_pos + style.item_height / 2 + style.item_padding
			end
		else
			-- Is this a variable with a non-default value?
			local default = true
			if item.default ~= nil and item.varname ~= nil then
				if item.type == "variable" and self:get_var(item.varname) ~= item.default then
					default = false
				elseif item.type == "menu" then
					if item.subtype == "color" then
						if self:get_var(item.varname .. ".r") ~= item.default.r or
						   self:get_var(item.varname .. ".g") ~= item.default.g or
						   self:get_var(item.varname .. ".b") ~= item.default.b or
						   self:get_var(item.varname .. ".a") ~= item.default.a then
							default = false
						end
					elseif item.subtype == "fvector" then
						if self:get_var(item.varname .. ".x") ~= item.default.x or
						   self:get_var(item.varname .. ".y") ~= item.default.y or
						   self:get_var(item.varname .. ".z") ~= item.default.z then
							default = false
						end
					end
				end
			end

			-- Set colors depending on selection
			if i == m.selected then
				text_color = style.fg_sel
				bg_color = style.bg_sel
			else
				text_color = default and style.fg or style.fg_var
				bg_color = style.bg
			end

			-- Draw the background rectangle
			drawRect(x_pos, y_pos, x_pos + style.item_width, y_pos + style.item_height, bg_color)

			-- Draw description if this item is selected and has a description
			if i == m.selected and item.description ~= nil then
				local x = x_res / 2 + style.desc_x
				local y = y_res * 0.25 + style.desc_y
				drawRect(x - 150, y, x + 150, y + 10, style.bg_sel)

				-- Split on newlines
				local i = 0
				local y_pos = y + 10
				for line in item.description:gmatch("[^\n]+") do
					drawRect(x - 150, y_pos, x + 150, y_pos + 15, style.bg_sel)
					drawUTText(line, style.fg_sel, x - 145, y_pos + 5, 0, 0, 0)
					y_pos = y_pos + 15
				end
				drawRect(x - 150, y_pos, x + 150, y_pos + 5, style.bg_sel)
			end

			if item.type == "variable" then
				-- Also draw the current value of a variable
				local text
				local var = self:get_var(item.varname)
				local vartype = type(var)

				if vartype == "boolean" then
					text = var and "Yes" or "No"
				elseif vartype == "string" then
					text = string.len(var) > 0 and "\"" .. var .. "\"" or "Empty"
				else
					text = var
				end

				drawUTText(text, text_color, x_pos + style.item_width - 5, y_pos + style.item_height / 2, 2, 0, 0)
			elseif item.type == "menu" then
				if item.subtype == "color" then
					-- Draw a color preview
					drawRect(x_pos + style.item_width - style.item_height + 3, y_pos + 3, x_pos + style.item_width - 3, y_pos + style.item_height - 3, self:get_var(item.varname))
				else
					-- Draw an indicator so it's obvious this item is a sub menu
					drawUTText(">", text_color, x_pos + style.item_width - 5, y_pos + style.item_height / 2, 2, 0, 0)
				end
			end

			-- Finally draw the items title
			drawUTText(item.title, text_color, x_pos + 5, y_pos + style.item_height / 2, 0, 0, 0)
			y_pos = y_pos + style.item_height + style.item_padding
		end
		i = i + 1
	end

	return true
end
