--
-- @component vtx_control;
-- @description Control vtx band, channel, power and pitmode;
-- @Author: @botsman.77 (signal);
-- @For To use with MILELRS a couple of steps are required;
-- 				1) Enable option "VTX_CHANGE_EN" to 1;
-- 				2) Specify the Channel (aux) that will switch vtx,
-- 				in parameters "VTX_CHANGE_RC","VTX_BAND_RC", "VTX_POWER_RC",
--              "VTX_PITMODE_RC" from 6 to 16;
-- 				3) Specify the desired vtx bands in parameter "VTX_BAND_CSTM"
-- 				without spaces like 457;
-- 				4) Specify min power value in parameter "VTX_MIN_POWER";
-- 				5) Specify power value of middle position of the switch
--              in parameter "VTX_TRIM_POWER";
--              6) Specify max power value in parameter "VTX_MAX_POWER";
-- @end;
--

-- var START --
local TABLE_KEY = 51
local TABLE_PREFIX = "VTX_"
local LOOP_INTERVAL = 200
local VTX_BAND = "VTX_BAND"
local VTX_FREQ = "VTX_FREQ"
local VTX_MAX_POWER = "VTX_MAX_POWER"
local VTX_POWER = "VTX_POWER"
local vtx_band = 0
local RC_RANGE = 1010
local range_step = math.floor(RC_RANGE / 3)
local lower_bound = 0
local upper_bound = 0
local is_add_param_table = false
local is_enable = false
local is_init_RC_channel = false
local is_init_BAND = false
local is_init_power = false
local is_init_pitmode = false
local is_init_channels_range = false
local count = 0
local message_index = 0
local channels = {0 , 1 , 2 , 3 , 4 , 5 , 6 , 7}
local band_names = {"A","B","E","F","R","L","1G3_A","1G3_B","X","3G3_A","3G3_B"}
local frequencies = {}
local PARAMS = {
	CHANGE_ENABLE = "CHANGE_EN",
    RCS= {
        {name = "BAND_RC", channel = nil, is_enable = false, boundaries = {}, curr = nil, curr_index = nil},
        {name = "CHANNEL_RC", channel = nil, is_enable = false, boundaries = {}, curr = nil, curr_index = nil},
        {name = "POWER_RC", channel = nil, is_enable = false,boundaries = {}, curr = nil, curr_index = nil},
        {name = "PITMODE_RC", channel = nil, is_enable = false, boundaries = {}, curr = nil, curr_index = nil}
    },
    BAND_CSTM = "BAND_CSTM",
    MIN_POWER = "MIN_POWER",
    TRIM_POWER = "TRIM_POWER"
}
local VIDEO_CHANNELS = {
    { 5865, 5845, 5825, 5805, 5785, 5765, 5745, 5725}, -- Band A  case 1
    { 5733, 5752, 5771, 5790, 5809, 5828, 5847, 5866}, -- Band B   case 2
    { 5705, 5685, 5665, 5645, 5885, 5905, 5925, 5945}, -- Band E   case 3
    { 5740, 5760, 5780, 5800, 5820, 5840, 5860, 5880}, -- Airwave   case 4
    { 5658, 5695, 5732, 5769, 5806, 5843, 5880, 5917}, -- Race  case 5
    { 5621, 5584, 5547, 5510, 5473, 5436, 5399, 5362}, -- LO Race  case 6
    { 1080, 1120, 1160, 1200, 1240, 1280, 1320, 1360}, -- Band 1G3_A  case 7
    { 1080, 1120, 1160, 1200, 1258, 1280, 1320, 1360}, -- Band 1G3_B  case 8
    { 4990, 5020, 5050, 5080, 5110, 5140, 5170, 5200}, -- Band X   case 9
    { 3330, 3350, 3370, 3390, 3410, 3430, 3450, 3470}, -- Band 3G3_A  case 10
    { 3170, 3190, 3210, 3230, 3250, 3270, 3290, 3310}  -- Band 3G3_B  case 11
}
-- var END --

-- get current
local function get_current(RC_index, curr_RC_channel_value)
    for i, item in ipairs(PARAMS.RCS[RC_index].boundaries) do
        if curr_RC_channel_value > item.lower and curr_RC_channel_value <= item.upper then
            PARAMS.RCS[RC_index].curr_index = i
            if item.value ~= PARAMS.RCS[RC_index].curr then
                PARAMS.RCS[RC_index].curr = item.value
                if RC_index == 1 then
                    gcs:send_text(6, "Current VTX BAND: " .. band_names[PARAMS.RCS[RC_index].curr])
                elseif RC_index == 2 then
                    if PARAMS.RCS[1].curr ~= vtx_band then
                        vtx_band = PARAMS.RCS[1].curr
                        frequencies = VIDEO_CHANNELS[vtx_band]
                    end
                    gcs:send_text(6, "Current VTX freq: " .. frequencies[PARAMS.RCS[RC_index].curr])
                    param:set(VTX_FREQ, frequencies[PARAMS.RCS[RC_index].curr])
                elseif RC_index == 3 then
                    gcs:send_text(6, string.format("Current VTX POWER: %dmW", PARAMS.RCS[RC_index].curr))
                    param:set(VTX_POWER, PARAMS.RCS[RC_index].curr)
                elseif RC_index == 4 then
                    gcs:send_text(6, "Current" .. PARAMS.RCS[RC_index].curr)
                    if i == 2 then
                        param:set(VTX_POWER, 0)
                    elseif i == 1 then
                        gcs:send_text(6, string.format("Current VTX POWER: %dmW", PARAMS.RCS[3].curr))
                        param:set(VTX_POWER, PARAMS.RCS[3].curr)
                    end    
                end
            end
            break
        end
    end
end

-- main START --
local function loop()
    
    -- get BAND, CHANNEL, POWER, PITMODE
    for i, rc in ipairs(PARAMS.RCS) do
        if rc.is_enable then
            local curr_RC_channel_value = rc:get_pwm(rc.channel)
            local curr_index = rc.curr_index
            if curr_RC_channel_value < rc.boundaries[curr_index].lower
                or curr_RC_channel_value > rc.boundaries[curr_index].upper then
                get_current(i, curr_RC_channel_value)
            end
        end
    end
    
	return loop, LOOP_INTERVAL
end
-- main END --

-- init Band function
local function init_band(band)
    if band == 0 or band > 11 then
        gcs:send_text(6, string.format("%d : Custom VTX BAND wasn`t defined!", message_index))
        band = param:get(VTX_BAND) or 0
        band = band + 1
    end
    local curr_band = band
    gcs:send_text(6, string.format("%d : Set VTX BAND: %s", message_index, band_names[curr_band]))
    gcs:send_text(6, string.format("%d : Done!\n ", message_index))
    is_init_BAND = true
    message_index = message_index + 1
    return curr_band
end
-- init BAND function end

-- init START --
local function init()
	
    -- add param table
	if not is_add_param_table then
		gcs:send_text(6, " - * - * - * - * - * - * - * - * - * - * - * - \n ")
		gcs:send_text(6, string.format("%d : Initialize VTX control\n ", message_index))
        
        local is_param_added = param:get(TABLE_PREFIX .. PARAMS.CHANGE_ENABLE)

        if is_param_added == nil then
            assert(param:add_table(TABLE_KEY, TABLE_PREFIX, 6), "The parameter table wasn`t created")
            param:add_param(TABLE_KEY, 1, PARAMS.CHANGE_ENABLE, 0)
            param:add_param(TABLE_KEY, 6, PARAMS.BAND_CSTM, 0)
            param:add_param(TABLE_KEY, 2, PARAMS.RCS[1].name, 0)
            param:add_param(TABLE_KEY, 2, PARAMS.RCS[2].name, 0)
            param:add_param(TABLE_KEY, 2, PARAMS.RCS[3].name, 0)
            param:add_param(TABLE_KEY, 2, PARAMS.RCS[4].name, 0)

            is_add_param_table = true
            message_index = message_index + 1
            return init, 1000
        end
		
		is_add_param_table = true
        message_index = message_index + 1
	end

	-- check enable vtx channel change mode
	if is_add_param_table and not is_enable then
		local enable = param:get(TABLE_PREFIX .. PARAMS.CHANGE_ENABLE) or 0
		if enable == 1 then
			gcs:send_text(6, string.format("%d : VTX control enable!\n ", message_index))
			is_enable = true
            message_index = message_index + 1
			return init, 100
		end

		if enable == 0 and count < 5 then
			count = count + 1
			return init, 100
		elseif enable == 0 and count >= 5 then
			gcs:send_text(6, string.format("%d : VTX control disabled!\n ", message_index))
			return
		end
        gcs:send_text(6, 
            string.format("%d : Unsupported value of %s%s : %d", message_index, TABLE_PREFIX, PARAMS.CHANGE_ENABLE, enable))
        gcs:send_text(6, string.format("%d : VTX control disabled!\n ", message_index))
		return
	end

    -- set RC channels
    if is_enable and not is_init_RC_channel then
        for _, rc in ipairs(PARAMS.RCS) do
            local RC_channel = param:get(TABLE_PREFIX .. rc.name) or 0
            if RC_channel > 5 and RC_channel <= 15 then
                gcs:send_text(6, string.format("%d : Set %s%s channel: %d", message_index, TABLE_PREFIX, rc.name, RC_channel))
                gcs:send_text(6, string.format("%d : Done!\n ", message_index))
                rc.channel = RC_channel
                rc.is_enable = true
            elseif RC_channel > 15 then
                gcs:send_text(6, string.format("%d : Unsupported value of %s%s : %d", message_index, TABLE_PREFIX, rc.name, RC_channel))
                gcs:send_text(6, string.format("%d : %s%s control disabled!\n ", message_index, TABLE_PREFIX, rc.name))
            else
                gcs:send_text(6, string.format("%d : %s%s channel wasn`t defined!\n ", message_index, TABLE_PREFIX, rc.name))
            end
            message_index = message_index + 1
        end
        is_init_RC_channel = true
        return init, 100
    end
    
    -- set BAND
    if PARAMS.RCS[1].is_enable and not is_init_BAND then
        local bands = param:get(TABLE_PREFIX .. PARAMS.BAND_CSTM) or 0
        
        if not PARAMS.RCS[1].is_enable then
            PARAMS.RCS[1].curr = init_band(bands)
            return init, 100
        end
        
        local bands_string = tostring(math.floor(bands))
        
        if #bands_string < 2 and #bands_string > 3 then
            PARAMS.RCS[1].curr =  init_band(bands)
            PARAMS.RCS[1].is_enable = false
            return init, 100
        end

        gcs:send_text(6, string.format("%d : Set VTX BANDS RC range\n ", message_index))
        gcs:send_text(6, " - - - - - - - - - - - - - - - -")
        for i = 1, 3 do
            local band = tonumber(bands_string:sub(i,i))
            lower_bound = 990 + (i - 1) * range_step
            upper_bound = lower_bound + range_step
            if not band then
                band = tonumber(bands_string:sub(i - 1,i - 1))
            end
            table.insert(PARAMS.RCS[1].boundaries, {lower = lower_bound, upper = upper_bound, value = band})
            gcs:send_text(6, string.format("%d - %d, %d - %s", i, lower_bound, upper_bound, band_names[band]))
        end
        gcs:send_text(6, " - - - - - - - - - - - - - - - - \n ")
        local curr_RC_channel_value = rc:get_pwm(PARAMS.RCS[1].channel)
        get_current(1, curr_RC_channel_value)
        gcs:send_text(6, string.format("%d : Done!\n ", message_index))
        is_init_BAND = true
        message_index = message_index + 1
        return init, 100
    end

    --set CHANNEL RC range
    if PARAMS.RCS[2].is_enable and not is_init_channels_range then
        gcs:send_text(6, string.format("%d: Set CHANNEL RC range ...\n ", message_index))
        gcs:send_text(6, " - - - - - - - - - - - - - - - -")
        local step = math.floor(RC_RANGE / #channels)
        for i = 1, #channels do
            lower_bound = 990 + (i - 1) * step
            upper_bound = lower_bound + step

            table.insert(PARAMS.RCS[2].boundaries, {lower = lower_bound, upper = upper_bound, value = i})
            gcs:send_text(6, string.format("%d - %d, %d;", i, lower_bound, upper_bound))
        end
        gcs:send_text(6, " - - - - - - - - - - - - - - - -\n ")
        local curr_RC_channel_value = rc:get_pwm(PARAMS.RCS[2].channel)
        get_current(2, curr_RC_channel_value)
        gcs:send_text(6, string.format("%d : Done!\n ", message_index))
        message_index = message_index + 1
        is_init_channels_range = true
        return init, 100
    end
    
    -- set POWER RC range
    if PARAMS.RCS[3].is_enable and not is_init_power then
        local min = param:get(TABLE_PREFIX .. PARAMS.MIN_POWER) or 25
        local av = param:get(TABLE_PREFIX .. PARAMS.TRIM_POWER) or 25
        local max = param:get(VTX_MAX_POWER) or 25
        local pwr_values = {min, av, max}
        gcs:send_text(6, string.format("%d: Set POWER RC range ...\n ", message_index))
        gcs:send_text(6, " - - - - - - - - - - - - - - - -")

        for i = 1, 3 do
            lower_bound = 990 + (i - 1) * range_step
            upper_bound = lower_bound + range_step
            table.insert(PARAMS.RCS[3].boundaries, {lower = lower_bound, upper = upper_bound, value = pwr_values[i]})
            gcs:send_text(6,  string.format("%dmW - %d, %d;", pwr_values[i], lower_bound, upper_bound))
        end

        gcs:send_text(6, " - - - - - - - - - - - - - - - - \n ")
        local curr_RC_channel_value = rc:get_pwm(PARAMS.RCS[3].channel)
        get_current(3, curr_RC_channel_value)
        gcs:send_text(6, string.format("%d : Done!\n ", message_index))
        message_index = message_index + 1
        is_init_power = true
        return init, 100
    end
    
    -- set PITMODE RC range
    if PARAMS.RCS[4].is_enable and not is_init_pitmode then
        gcs:send_text(6, string.format("%d: Set PITMODE RC range ...\n ", message_index))
        gcs:send_text(6, " - - - - - - - - - - - - - - - -")
        table.insert(PARAMS.RCS[4].boundaries, {lower = 990, upper = (990 + range_step), value = "PITMODE OFF"})
        gcs:send_text(6,  string.format("PITMODE OFF - %d, %d;", 990, (990 + range_step)))
        table.insert(PARAMS.RCS[4].boundaries, {lower = (990 + range_step), upper = (990 + RC_RANGE), value = "PITMODE ON"})
        gcs:send_text(6,  string.format("PITMODE ON - %d, %d;", (990 + range_step), (990 + RC_RANGE)))
        gcs:send_text(6, " - - - - - - - - - - - - - - - - \n ")
        local curr_RC_channel_value = rc:get_pwm(PARAMS.RCS[4].channel)
        get_current(4, curr_RC_channel_value)
        gcs:send_text(6, string.format("%d : Done!\n ", message_index))
        message_index = message_index + 1
        is_init_pitmode = true
        return init, 100
    end
    
	if is_init_RC_channel then
        for _, rc in ipairs(PARAMS.RCS) do
            if rc.is_enable then
                gcs:send_text(6, string.format("Initialize %s%s: %d", TABLE_PREFIX, rc.name, rc.channel))
            else
                gcs:send_text(6, string.format("Initialize %s%s: %q", TABLE_PREFIX, rc.name, rc.is_enable))
            end
        end
		gcs:send_text(6, "Initialize complete!!!")
		gcs:send_text(6, " - * - * - * - * - * - * - * - * - * - * - * - \n ")
		return loop, LOOP_INTERVAL
	end
end
return init, 100
-- init END --
