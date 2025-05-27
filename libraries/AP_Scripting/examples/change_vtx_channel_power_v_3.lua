--
-- @component change_vtx_channel ver.2;
-- @description Change VTX channel for MILELRS with
-- auto detection of the number of channels;
-- @Author: @alex_jackson.01 (signal);
-- @For To use with MILELRS a couple of steps are required;
-- 				1) Enable option "VTX_CHANGE_EN" to 1;
-- 				2) Specify the Channel (aux) that will switch vtx,
-- 				in parameter "VTX_CHANNEL_RC" from 6 to 16;
--				3) Specify the Power (aux) that will switch vtx,
-- 				in parameter "VTX_POWER_RC" from 6 to 16;
-- 				3) Specify the frequencies of the desired vtx channels
-- 				in the same order as specified in the MILELRS settings,
-- 				in parameters "FREQ1" to "FREQ8";
--				4) Specify the values of the desired vtx power
-- 				in parameters "VTX_MIN_POWER" to "VTX_TRIM_POWER";
-- @end;
--

-- var START --
local TABLE_KEY = 51
local TABLE_PREFIX = "VTX_"
local LOOP_INTERVAL = 200
local VTX_FREQ = "VTX_FREQ"
local VTX_POWER = "VTX_POWER"
local RC_MIN = 990
local RC_RANGE = 1025
local CH_RC_channel = nil
local CH_RC_channel_value = 0
local prev_CH_RC_channel_value = 0
local PWR_RC_channel = nil
local PWR_RC_channel_value = 0
local prev_PWR_RC_channel_value = 0
local pwr_value = 25
local range_step = 0
local lower_bound = 0
local upper_bound = 0
local freq = 0
local BAND = 0
local CHANNEL = 0
local count = 0
local is_init_channels = false
local is_add_param_table = false
local is_enable = false
local is_init_CH_RC_channel = false
local is_init_PWR_RC_channel = false
local is_power_range = false
local is_init = false
local control_band = {}
local pwr_ranges = {}
local band_names = {"A","B","E","F","R","L","1G3_A","1G3_B","X","3G3_A","3G3_B"}
local PARAMS = {
	CHANGE_ENABLE = "CHANGE_EN",
	CHANNEL_RC = "CHANNEL_RC",
	POWER_RC = "POWER_RC",
	MIN_POWER = "MIN_POWER",
	TRIM_POWER = "TRIM_POWER",
	CONTROL1 = "CONTROL1",
}
local VIDEO_CHANNELS = {
    { 5865, 5845, 5825, 5805, 5785, 5765, 5745, 5725}, -- Band A
    { 5733, 5752, 5771, 5790, 5809, 5828, 5847, 5866}, -- Band B 
    { 5705, 5685, 5665, 5645, 5885, 5905, 5925, 5945}, -- Band E 
    { 5740, 5760, 5780, 5800, 5820, 5840, 5860, 5880}, -- Airwave 
    { 5658, 5695, 5732, 5769, 5806, 5843, 5880, 5917}, -- Race
    { 5621, 5584, 5547, 5510, 5473, 5436, 5399, 5362}, -- LO Race
    { 1080, 1120, 1160, 1200, 1240, 1280, 1320, 1360}, -- Band 1G3_A
    { 1080, 1120, 1160, 1200, 1258, 1280, 1320, 1360}, -- Band 1G3_B
    { 4990, 5020, 5050, 5080, 5110, 5140, 5170, 5200}, -- Band X
    { 3330, 3350, 3370, 3390, 3410, 3430, 3450, 3470}, -- Band 3G3_A
    { 3170, 3190, 3210, 3230, 3250, 3270, 3290, 3310}  -- Band 3G3_B
}
-- var END --

-- main START --
local function loop()
	CH_RC_channel_value = rc:get_pwm(CH_RC_channel)
	PWR_RC_channel_value = rc:get_pwm(PWR_RC_channel)

	if prev_CH_RC_channel_value ~= CH_RC_channel_value then
		prev_CH_RC_channel_value = CH_RC_channel_value
		for _, val in ipairs(control_band) do

			if CH_RC_channel_value > val.lower and CH_RC_channel_value <= val.upper then
				if val.band ~= BAND then
					BAND = val.band
				end
                
                if val.channel ~= CHANNEL then
					CHANNEL = val.channel
				end

                freq = VIDEO_CHANNELS[BAND][CHANNEL]
                local curr_freq = param:get(VTX_FREQ)
                if curr_freq ~= freq then
                    gcs:send_text(6, string.format("Current VTX CHANNEL: %s%d", band_names[BAND], CHANNEL))
                    param:set(VTX_FREQ, freq)
                    break
                end
			end
		end
	end

	if prev_PWR_RC_channel_value ~= PWR_RC_channel_value then
		prev_PWR_RC_channel_value = PWR_RC_channel_value
		for _, range in ipairs(pwr_ranges) do

			if PWR_RC_channel_value >= range.lower and PWR_RC_channel_value <= range.upper then
				if range.value ~= pwr_value then
					pwr_value = range.value
					gcs:send_text(6, string.format("Current VTX power: %d", pwr_value))
					param:set(VTX_POWER, pwr_value)
					break
				end
			end

		end
	end	

	return loop, LOOP_INTERVAL
end
-- main END --

-- init START --
local function init()
	-- add param table

	if not is_add_param_table then
		gcs:send_text(6, " - * - * - * - * - * - * - * - * - * - * - * - \n ")
		gcs:send_text(6, "0 : Initialize VTX control\n ")

		assert(param:add_table(TABLE_KEY, TABLE_PREFIX, 6), "The parameter table wasn`t created")
		param:add_param(TABLE_KEY, 1, PARAMS.CHANGE_ENABLE, 0)
		param:add_param(TABLE_KEY, 2, PARAMS.CHANNEL_RC, 0)
		param:add_param(TABLE_KEY, 3, PARAMS.POWER_RC, 0)
		param:add_param(TABLE_KEY, 4, PARAMS.MIN_POWER, 0)
		param:add_param(TABLE_KEY, 5, PARAMS.TRIM_POWER, 0)
		param:add_param(TABLE_KEY, 6, PARAMS.CONTROL1, 0)

		is_add_param_table = true

		return init, 1000
	end

	-- check enable vtx channel change mode
	if not is_enable then
		local enable = param:get(TABLE_PREFIX .. PARAMS.CHANGE_ENABLE) or 0
		if enable == 1 then
			gcs:send_text(6, "1 : VTX control enable!\n ")
			is_enable = true
			return init, 100
		end

		if enable == 0 and count < 5 then
			count = count + 1
			return init, 100
		elseif enable == 0 and count >= 5 then
			gcs:send_text(6, "1 : VTX control disabled!\n ")
			return
		end
		return init, 100
	end

	-- set CHANNEL RC channel
	if is_enable and not is_init_CH_RC_channel then
		CH_RC_channel = param:get(TABLE_PREFIX .. PARAMS.CHANNEL_RC) or nil
		if CH_RC_channel ~= nil or CH_RC_channel > 5 then
			gcs:send_text(6, string.format("2 : Set CHANNEL RC channel %d", CH_RC_channel))
			gcs:send_text(6, "2 : Done!\n ")
			is_init_CH_RC_channel = true
			return init, 100
		end
		gcs:send_text(6, "2 : VTX CHANNEL RC channel not found!\n ")
	end

	-- set POWER RC channel
	if is_enable and not is_init_PWR_RC_channel then
		PWR_RC_channel = param:get(TABLE_PREFIX .. PARAMS.POWER_RC) or nil
		if PW_RC_channel ~= nil or PWR_RC_channel > 5 then
			gcs:send_text(6, string.format("3 : Set POWER RC channel %d", PWR_RC_channel))
			gcs:send_text(6, "3 : Done!\n ")
			is_init_PWR_RC_channel = true
			return init, 100
		end
		gcs:send_text(6, "3 : VTX POWER RC channel not found! \n ")
	end

    -- set CHANNEL table
    if is_enable and not is_init_channels then
        gcs:send_text(6, "5 : Set CHANNEL table ... ")
        local control1 = param:get(TABLE_PREFIX .. PARAMS.CONTROL1) or 0
        local control1_string = tostring(control1)
        if #control1_string > 1 then
            local index = 0
            range_step = RC_RANGE / math.floor(#control1_string / 2)
            for i = 1, #control1_string, 2 do
                lower_bound = RC_MIN + (index) * math.floor(range_step)
                upper_bound = lower_bound + math.floor(range_step)
                local band = tonumber(control1_string:sub(i,i))
                local channel = tonumber(control1_string:sub(i+1,i+1))
                if channel then
                    table.insert(control_band, {lower = lower_bound, upper = upper_bound, band = band, channel = channel})
                    gcs:send_text(6, string.format("%d - %d, %d - CHANNEL: %s%d", index, lower_bound, upper_bound, band_names[band], channel))
                end
                index = index + 1
            end
        end
    
        if #control_band ~= 0 then
            gcs:send_text(6, " - - - - - - - - - - - - - - - - \n ")
            gcs:send_text(6, "5 : Done!\n ")
            is_init_channels = true
            return init, 100
        end
    
        gcs:send_text(6, "5 : VTX  CHANNELS not found! \n ")
    end

	-- set POWER RC range
	if is_init_PWR_RC_channel and not is_power_range then

		local lower = 0
		local upper = 0
		local min = param:get(TABLE_PREFIX .. PARAMS.MIN_POWER) or 25
		local av = param:get(TABLE_PREFIX .. PARAMS.TRIM_POWER) or 25
		local max = param:get(TABLE_PREFIX .. "MAX_POWER") or 25
		local pwr_values = {min, av, max}
		local step = RC_RANGE / 3
		gcs:send_text(6, "7: Set POWER RC range ...\n ")
		gcs:send_text(6, " - - - - - - - - - - - - - - - -")
		
		for i = 1, 3 do
			lower = RC_MIN + (i - 1) * math.floor(step)
			upper = lower + math.floor(step)
			table.insert(pwr_ranges, {lower = lower, upper = upper, value = pwr_values[i]})
			gcs:send_text(6,  string.format("%dmW - %d, %d;", pwr_values[i], lower, upper))
		end

		gcs:send_text(6, " - - - - - - - - - - - - - - - - \n ")
		gcs:send_text(6, "7 : Done!\n ")
		is_power_range = true
		return init, 100
	end

	-- init complete
	if (is_init_channels or is_power_range) and not is_init then
		is_init = true
		gcs:send_text(6, string.format("Initialize boundaries: %q;",is_init_channels))
		gcs:send_text(6, string.format("Initialize power ranges: %q;", is_power_range))
		gcs:send_text(6, "Initialize complete!!!")
		gcs:send_text(6, " - * - * - * - * - * - * - * - * - * - * - * -  \n ")
		return loop, LOOP_INTERVAL
	end

end
return init, 100
-- init END --
