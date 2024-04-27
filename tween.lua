---@alias Zenitha.Tween.easeCurve
---| 'linear'
---| 'inSin'
---| 'outSin'
---| 'inQuad'
---| 'outQuad'
---| 'inCubic'
---| 'outCubic'
---| 'inQuart'
---| 'outQuart'
---| 'inQuint'
---| 'outQuint'
---| 'inExp'
---| 'outExp'
---| 'inCirc'
---| 'outCirc'
---| 'inBack'
---| 'outBack'
---| 'inElastic'
---| 'outElastic'

---@alias Zenitha.Tween.easeSugar
---| 'Linear'
---| 'InSin' | 'OutSin' | 'InOutSin' | 'OutInSin'
---| 'InQuad' | 'OutQuad' | 'InOutQuad' | 'OutInQuad'
---| 'InCubic' | 'OutCubic' | 'InOutCubic' | 'OutInCubic'
---| 'InQuart' | 'OutQuart' | 'InOutQuart' | 'OutInQuart'
---| 'InQuint' | 'OutQuint' | 'InOutQuint' | 'OutInQuint'
---| 'InExp' | 'OutExp' | 'InOutExp' | 'OutInExp'
---| 'InCirc' | 'OutCirc' | 'InOutCirc' | 'OutInCirc'
---| 'Inback' | 'Outback' | 'InOutback' | 'OutInback'
---| 'InElastic' | 'OutElastic' | 'InOutElastic' | 'OutInElastic'


local preAnimSet={} ---@type Set<Zenitha.Tween> new Animation created during _update will be added here first, then moved to updAnimSet
local updAnimSet={} ---@type Set<Zenitha.Tween>
local tagAnimSet={} ---@type Set<Zenitha.Tween>

---@alias Zenitha.Tween.Tag string

local max,min=math.max,math.min
local sin,cos=math.sin,math.cos
local floor=math.floor

local clamp=MATH.clamp


---@type table<Zenitha.Tween.easeCurve, function>
local curves={
    linear=function(t) return t end,
    inSin=function(t) return 1-cos(t*1.5707963267948966) end,
    outSin=function(t) return sin(t*1.5707963267948966) end,
    inQuad=function(t) return t^2 end,
    outQuad=function(t) return 1-(1-t)^2 end,
    inCubic=function(t) return t^3 end,
    outCubic=function(t) return 1-(1-t)^3 end,
    inQuart=function(t) return t^4 end,
    outQuart=function(t) return 1-(1-t)^4 end,
    inQuint=function(t) return t^5 end,
    outQuint=function(t) return 1-(1-t)^5 end,
    inExp=function(t) return 2^(10*(t-1)) end,
    outExp=function(t) return 1-2^(-10*t) end,
    inCirc=function(t) return 1-(1-t^2)^.5 end,
    outCirc=function(t) return (1-(t-1)^2)^.5 end,
    inBack=function(t) return t^2*(2.70158*t-1.70158) end,
    inElastic=function(t) return -2^(10*(t-1))*sin((10*t-10.75)*2.0943951023931953) end,
}
curves.outBack=function(t) return 1-curves.inBack(1-t) end
curves.outElastic=function(t) return 1-curves.inElastic(1-t) end

---@type table<Zenitha.Tween.easeSugar, Zenitha.Tween.easeCurve[]>
local easeSugarData={
    Linear={'linear'},
    InSin={'inSin'},
    OutSin={'outSin'},
    InOutSin={'inSin','outSin'},
    OutInSin={'outSin','inSin'},
    InQuad={'inQuad'},
    OutQuad={'outQuad'},
    InOutQuad={'inQuad','outQuad'},
    OutInQuad={'outQuad','inQuad'},
    InCubic={'inCubic'},
    OutCubic={'outCubic'},
    InOutCubic={'inCubic','outCubic'},
    OutInCubic={'outCubic','inCubic'},
    InQuart={'inQuart'},
    OutQuart={'outQuart'},
    InOutQuart={'inQuart','outQuart'},
    OutInQuart={'outQuart','inQuart'},
    InQuint={'inQuint'},
    OutQuint={'outQuint'},
    InOutQuint={'inQuint','outQuint'},
    OutInQuint={'outQuint','inQuint'},
    InExp={'inExp'},
    OutExp={'outExp'},
    InOutExp={'inExp','outExp'},
    OutInExp={'outExp','inExp'},
    InCirc={'inCirc'},
    OutCirc={'outCirc'},
    InOutCirc={'inCirc','outCirc'},
    OutInCirc={'outCirc','inCirc'},
    InBack={'inBack'},
    OutBack={'outBack'},
    InOutBack={'inBack','outBack'},
    OutInBack={'outBack','inBack'},
    InElastic={'inElastic'},
    OutElastic={'outElastic'},
    InOutElastic={'inElastic','outElastic'},
    OutInElastic={'outElastic','inElastic'},
}

---@class Zenitha.Tween
---@field private running boolean
---@field private duration number default to 1
---@field private time number used when no timeFunc
---@field private loop false|'repeat'|'yoyo'
---@field private loopCount number how many times to loop
---@field private flipMode boolean true when loop is `'yoyo'`, making time flow back and forth
---@field private ease Zenitha.Tween.easeCurve[]
---@field private doFunc fun(t:number)
---@field private timeFunc? fun():number custom how time goes
---@field private tags Set<Zenitha.Tween.Tag>
---@field private onRepeat function
---@field private onFinish function
local TWEEN={}

TWEEN.__index=TWEEN

local duringUpdate=false -- During update, new [tween]:run() will be added to preAnimSet first to prevent undefined behavior of table iterating

---Create a new tween animation
---@param doFunc fun(t:number)
---@return Zenitha.Tween
function TWEEN.new(doFunc)
    assert(type(doFunc)=='function',"TWEEN.new(doFunc): Need function")
    local anim=setmetatable({
        running=false,
        duration=1,
        doFunc=doFunc,
        ease=easeSugarData.InOutSin,
        tagSet={},
        onRepeat=NULL,
        onFinish=NULL,
    },TWEEN)
    return anim
end

---Set doFunc (generally unnecessary, already set when creating)
---@param doFunc fun(t:number)
---@return Zenitha.Tween
function TWEEN:setDo(doFunc)
    assert(type(doFunc)=='function',"[tween]:setDo(doFunc): Need function")
    self.doFunc=doFunc
    return self
end

---Set onRepeat callback function
---@param func function
---@return Zenitha.Tween
function TWEEN:setOnRepeat(func)
    assert(type(func)=='function',"[tween]:setOnRepeat(onRepeat): Need function")
    -- assert(not self.running,"[tween]:setOnRepeat(func): Can't set ease when running")
    self.onRepeat=func
    return self
end

---Set onFinish callback function
---@param func function
---@return Zenitha.Tween
function TWEEN:setOnFinish(func)
    assert(type(func)=='function',"[tween]:setOnFinish(onFinish): Need function")
    -- assert(not self.running,"[tween]:setOnFinish(func): Can't set ease when running")
    self.onFinish=func
    return self
end

---Set easing mode
---@param ease? Zenitha.Tween.easeSugar|Zenitha.Tween.easeCurve[] default to 'InOutSin'
---@return Zenitha.Tween
function TWEEN:setEase(ease)
    -- assert(not self.running,"[tween]:setEase(ease): Can't set ease when running")
    if type(ease)=='string' then
        assertf(easeSugarData[ease],"[tween]:setEase(ease): Invalid ease name '%s'",ease)
        self.ease=easeSugarData[ease]
    elseif type(ease)=='table' then
        for i=1,#ease do
            assertf(curves[ease[i]],"[tween]:setEase(ease): Invalid ease curve name '%s'",ease[i])
        end
        self.ease=ease
    else
        error("[tween]:setEase(ease): Need string|table")
    end
    return self
end

---Set duration
---@param duration? number
---@return Zenitha.Tween
function TWEEN:setDuration(duration)
    assert(type(duration)=='number' and duration>=0,"[tween]:setDuration(duration): Need >=0")
    -- assert(not self.running,"[tween]:setDuration(duration): Can't set duration when running")
    self.duration=duration
    return self
end

---Set Looping
---@param loopMode false|'repeat'|'yoyo'
---@param loopCount? number default to Infinity
---@return Zenitha.Tween
function TWEEN:setLoop(loopMode,loopCount)
    assert(not self.timeFunc,"[tween]:setLoop(loopMode): Looping and timeFunc can't exist together")
    assert(not loopMode or loopMode=='repeat' or loopMode=='yoyo',"[tween]:setLoop(loopMode): Need false|'repeat'|'yoyo'")
    assert(not loopCount or type(loopCount)=='number' and loopCount>=0,"[tween]:setLoop(loopMode,loopCount): loopCount need >=0")
    -- assert(not self.running,"[tween]:setLoop(loopMode): Can't set loop when running")
    self.loop=loopMode
    self.loopCount=loopCount or 1e99
    self.flipMode=false
    return self
end

---Set tag for batch actions
---@param tag Zenitha.Tween.Tag
---@return Zenitha.Tween
function TWEEN:setTag(tag)
    assert(type(tag)=='string',"[tween]:setTag(tag): Need string")
    tagAnimSet[self]=true
    self.tags[tag]=true
    return self
end

---Start the animation animate with time, or custom timeFunc
---@param timeFunc? fun():number Custom the timeFunc (return a number in duration)
function TWEEN:run(timeFunc)
    assert(timeFunc==nil or type(timeFunc)=='function',"[tween]:run(timeFunc): Need function if exist")
    assert(not (self.loop and timeFunc),"[tween]:run(timeFunc): Looping and timeFunc can't exist together")
    assert(not self.running,"[tween]:run(): Can't run a running animation")
    if timeFunc then
        self.timeFunc=timeFunc
    else
        self.time=0
    end
    self:update(0);
    (duringUpdate and preAnimSet or updAnimSet)[self]=true
end

---Finish instantly (cannot apply to animation with timeFunc)
---@param simBound? boolean simulate all bound case for animation with loop
---@return Zenitha.Tween
function TWEEN:skip(simBound)
    assert(not self.timeFunc,"[tween]:skip(): Can't skip an animation with timeFunc")
    if not self.loop then
        self.time=self.duration
        self:update(0)
    else
        if simBound then
        else
            if self.loop=='repeat' then
                self.time=self.duration
                self:update(0)
            elseif self.loop=='yoyo' then
                self.time=self.duration
                self.flipMode=self.loopCount%2==0==self.flipMode
                self:update(0)
            end
        end
    end
    self:kill()
    return self
end

---Release animation from auto updating list and tag list
function TWEEN:kill()
    self.onFinish()
    preAnimSet[self]=nil
    updAnimSet[self]=nil
    tagAnimSet[self]=nil
end

---@param t number
---@param ease function[]
---@return number
local function curveValue(t,ease)
    local step=#ease
    local n=min(floor(t*step),step-1)
    local base=n/step
    local curve=curves[ease[n+1]]
    return base+curve((t-base)*step)/step
end

---Update the animation
function TWEEN:update(dt)
    self.running=true
    if self.timeFunc then
        local t=self.timeFunc()
        if t then
            self.doFunc(curveValue(clamp(self.flipMode and 1-t or t,0,1),self.ease))
        else
            self:kill()
        end
    else
        self.time=self.time+dt
        local t=min(self.time/self.duration,1)
        self.doFunc(curveValue(self.flipMode and 1-t or t,self.ease))
        if t>=1 then
            if self.loop and self.loopCount>1 then
                self.time=0
                self.loopCount=self.loopCount-1
                if self.loop=='yoyo' then
                    self.flipMode=not self.flipMode
                    self.onRepeat()
                end
            else
                self:kill()
            end
        end
    end
end

---Update all autoAnims (called by Zenitha)
---@param dt number
function TWEEN._update(dt)
    duringUpdate=true
    for anim in next,updAnimSet do
        anim:update(dt)
    end
    for anim in next,preAnimSet do
        preAnimSet[anim]=nil
        updAnimSet[anim]=true
    end
    duringUpdate=false
end

--------------------------------------------------------------
-- Batch actions with tag

---@param tag Zenitha.Tween.Tag
---@param method 'setEase'|'setTime'|'pause'|'continue'|'skip'|'kill'|'update'
---@vararg any
local function tagAction(tag,method,...)
    assert(type(tag)=='string',"TWEEN.tag_"..method..": tag need string")
    for anim in next,tagAnimSet do
        if anim.tags[tag] then
            TWEEN[method](anim,...)
        end
    end
end

---Finish tagged animations instantly
---@param tag Zenitha.Tween.Tag
function TWEEN.tag_skip(tag)
    tagAction(tag,'skip')
end

---Kill tagged animations
---@param tag Zenitha.Tween.Tag
function TWEEN.tag_kill(tag)
    tagAction(tag,'kill')
end

---Update tagged animations
---@param tag Zenitha.Tween.Tag
---@param dt number
function TWEEN.tag_update(tag,dt)
    tagAction(tag,'update',dt)
end

return TWEEN