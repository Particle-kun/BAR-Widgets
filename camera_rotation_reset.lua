function widget:GetInfo()
    return {
        name      = "Camera Rotation Reset",
        desc      = "Sets spring camera orientation by chat command or keybind",
        author    = "Particle_kun",
        date      = "August 23, 2025",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

-- Usage: 

-- 		 Chat: /camset X Y  (replace XY with the desired values, in degrees)
-- 		       You can also choose to use only 1 value to ONLY update a particular axis like this: /camset 90. <-- that will change your pitch (X) while keeping your yaw (Y) the same.
-- 		       Alternatively, you can set your Yaw and leave pitch unchanged by adding a Y after your singular number like this: /camset 90Y  or  /camset 90y

--       List of commands: /camset X Y     /setcam X Y
--                         /camerareset    /resetcamera  
    
--       For engine default values, use /camerareset or /resetcamera or alternatively /camset or /setcam without any numbers.

-- Example keybinds:     bind [key] camset 90 0       You can have as many as you like!
--                       bind [key] camerareset

-- A value of 0 pitch (X) rotates the camera to be paralell with the ground. A value of 90 will make you look straight down. Default pitch is 63.381* degrees. *see below for technicalities
-- A value of 0 yaw (Y) results in the camera looking "north" / towards the top of the minimap. A value of 180 or -180 will result in looking south.



local rotX = math.rad(63.381)
local rotY = 0
local camState = {}
local HALFPI = math.pi / 2
local rotY_isCommanded = false


function widget:Initialize()
    widgetHandler:AddAction("camset", function(_, _, params) self:HandleCamset(_, _, params) end)
    widgetHandler:AddAction("setcam", function(_, _, params) self:HandleCamset(_, _, params) end)
    widgetHandler:AddAction("camerareset", function() self:HandleCameraReset() end)
    widgetHandler:AddAction("resetcamera", function() self:HandleCameraReset() end)
end


function widget:HandleCamset(_, _, params)
    if params and #params >= 1 then
        local command = "camset"         -- Takes the params from either camset or setcam and puts them in front of a newly created "camset", dont need unique handling for each action.
        for i = 1, #params do            -- loop through and build command string from keybind-passed parameters
            command = command .. " " .. tostring(params[i])
        end
        self:TextCommand(command)
    end
end


function widget:HandleCameraReset()
	rotX = 2.677   -- this is the default value for X, in radians. Basically equal to math.rad(63.381) + math.rad(90)
	rotY = 0       
    self:ResetTheCamera()
end


function widget:TextCommand(command)                  -- passes values in radians to function widget:ResetTheCamera(). Values accepted in degrees need to be converted to radians.          
	local current = Spring.GetCameraState()           -- 90 degrees is added to pitch here to account for the engine considering 90 paralell to the ground and 180 looking straight down.        
    local words = {}                                  -- Because I think most people would try to use values 0-90 when setting their pitch.
    for word in command:gmatch("%S+") do              -- For reference, engine default pitch in degrees is ~153.381. Default pitch in radians is exactly 2.677.
        table.insert(words, word)
    end
                                                            
    if words[1] == "camset" or words[1] == "setcam" then    
		if #words == 1 then
			rotX = 2.677
			rotY = 0 
			
		elseif #words == 2 then
			local input = words[2]
			if input:match("[Yy]$") then           -- if someone puts a y or Y after the first term, it means only change yaw
				local numStr = input:match("(.+)[Yy]$")
				local angle = tonumber(numStr)
				if angle then
					rotY = math.rad(angle)
					rotX = current.rx    -- keep current pitch
					rotY_isCommanded = true
				else
					Spring.Echo("Error: Invalid Y angle value '" .. numStr .. "'.")
				end
			else
				--default case for 1 number
				local angle = tonumber(input)
				if angle then
					rotX = math.rad(angle) + math.rad(90)
					rotY = current.ry      -- keep current yaw
					rotY_isCommanded = false
				else
					Spring.Echo("Error: Invalid X angle value '" .. input .. "'.")
				end
			end
			
        elseif #words >= 3 then
            local angleX = tonumber(words[2])    -- theres probably a better way to handle input sanitizing but oh well
            if angleX then
                rotX = math.rad(angleX) + math.rad(90)
            else
                Spring.Echo("Error: Invalid X angle value '" .. words[2] .. "'. Using default.") 
                rotX = math.rad(63.381) + math.rad(90)     -- if there is anything that invalidates the param string, revert to these defaults
            end
            
            local angleY = tonumber(words[3])
            if angleY then
                rotY = math.rad(angleY)
            else
                Spring.Echo("Error: Invalid Y angle value '" .. words[3] .. "'. Using default.")
                rotY = math.rad(0)
            end
        end
        
        self:ResetTheCamera()
        return true
    elseif words[1] == "camerareset" or words[1] == "resetcamera" then  -- defaults/fallbacks / attempting intuitive coverage of likely terms if someone is trying to remember what the right commands are
        self:ResetTheCamera()
        return true
    end
    
    return false
end


-- There is a function in SpringController.cpp which prevents naive approaches of setting of angles. Its corresponding config bool can be seen in --> Spring.SetConfigInt("CamSpringLockCardinalDirections", 1)
-- This function below, InverseCardinalLock, accounts for the way GetRotationWithCardinalLock affects rotation in order to always produce the expected behavior of "I input angle Y, camera goes to angle Y" while not depending on the state of CardinalLock.
local function InverseCardinalLock(rotY)   -- user-commanded angle converted to radians - Dont pass current.ry here! It causes spinning and exploding to infinity by offsetting the already offset value.
    local s = (rotY >= 0) and 1 or -1      -- sign check to handle negative angles
    local t = math.abs(rotY) / HALFPI      -- reduce scope to a quadrant. Circle is 2pi, halfpi = 2pi/4
    local k = math.floor(t + 1e-12)        -- mitigate fp errors 
	if Spring.GetConfigInt("CamSpringLockCardinalDirections", 1) == 0 then -- in case people have turbocam installed or otherwise disabled CardinalLock via config, this ensures the logic only passes when appropriate.
		return rotY                        --conditionally pass current.ry to rotY
	elseif math.abs(t - k) < 1e-12 then
        -- Exactly a cardinal
        local x = (k == 0) and 0.15 or (k + 0.2) -- centers in the cardinal plateau. CardinalLock affects rotation once the camera exactly passes a cardinal, requiring the rotation value to increase beyond the threshold cardinalDirLockWidth = 0.2f;, which is 90 * 0.2 = 18 degrees, before continuing to rotate.
        return s * x * HALFPI                    -- (continuing above comment) setting an angle means there are multiple possible inputs for the output of a cardinal angle. This ensures cardinals are set at the center of their LockWidth when k == 0, eg, a cardinal angle.
    else
        -- Non-cardinal (linear region)
        local x = (0.8) * (t - k) + k + 0.3      -- When not setting to a cardinal, scoot exactly past the LockWidth to arrive at the intended angle. Notice 0.3 (full lock width) is 2x 0.15 (centered in the LockWidth). The cpp function uses cardinalDirLockWidth * 0.5f for things. I just use .3 and .15 to not have more static values in trenchcoats pretending to be variables. Style preference.
        return s * x * HALFPI
    end
end


function widget:ResetTheCamera()
    local current = Spring.GetCameraState()
    camState.px   = current.px               -- the position values are here in case I wanted to do anything with them/ help debug when stuff hit the fan
    camState.py   = current.py
    camState.pz   = current.pz
    camState.dist = current.dist
    camState.rx   = rotX

    if rotY_isCommanded then
        camState.ry = InverseCardinalLock(rotY)  -- If yaw came from explicit user input, reverse cardinal lock. InverseCardinalLock should only be used for user input, not current.ry
    else
        camState.ry = current.ry
        rotY = current.ry  -- prevent stale values from passing, edgecase
    end

    camState.rz = current.rz   -- was considering setting this to 0 since under normal circumstances this shouldnt really be anything other than 0

    Spring.SetCameraState(camState, 1.0)


    --Spring.Echo("Camera reset to: X=" .. rotX .. ", Y=" .. rotY)   -- Optional message to display what the values were updated to
end


function widget:Shutdown()
    widgetHandler:RemoveAction("camset")
    widgetHandler:RemoveAction("setcam")	
    widgetHandler:RemoveAction("camerareset")
	widgetHandler:RemoveAction("resetcamera")
end