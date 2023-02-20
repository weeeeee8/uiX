local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local Maid = UIX.Require:get('Maid')
local Fusion = UIX.Require:get('Fusion')
local GenericUtility = UIX.Require:get('GenericUtility')
local Inline = UIX.Inline

local TEXT_SIZE = 16
local LOG_MARKERS = {
    error = GenericUtility:Symbol('LogError'),
    warning = GenericUtility:Symbol('LogWarning'),
    info = GenericUtility:Symbol('LogInfo'),
}
local LOG_CONTEXT_FONT_COLORS = {
    [LOG_MARKERS.error] = 'rgb(245, 12, 0)',
    [LOG_MARKERS.warning] = 'rgb(245, 165, 5)',
    [LOG_MARKERS.info] = 'rgb(0, 34, 255)',
}
local BAR_CONTEXT_FONT_COLORS = {
    packageContext = 'rgb(236, 55, 0)',
    commandContext = 'rgb(0, 55, 255)',
    statementContext = 'rgb(238, 220, 57)', -- a string with the "@" character, only accepts number comparisons
    -- example, we want to make a loopbring and only bring those whose health is greater than 0. so we input: somePackage loopbring all @>0
    logicContext = '57, 159, 238', -- true or false
}

local New, Children, State, ComputedPairs, Computed = Fusion.New, Fusion.Children, Fusion.State, Fusion.ComputedPairs, Fusion.Computed

local LifecycleMaid = Maid.new()
local States = {
    historySet = State({}),
    transparency = State(1),
    suggestionsShown = State(false),
    canvasHeightPosition = State(0),
    toggled = State(false),
}
local Tweens = {
    transparency = Fusion.Spring(States.transparency, 20, 0.98)
}

local function fusionInstanceWrapper(instance)
    local wrapper = {}
    wrapper.connections = {}
    wrapper[Children] = {}
    function wrapper:get()
        return instance
    end
    function wrapper:onPropChanged(prop, fn)
        table.insert(self.connections, instance:GetPropertyChangedSignal(prop):Connect(fn))
        return self
    end
    function wrapper:connectSignal(signalName, fn)
        table.insert(self.connections, instance[signalName]:Connect(fn))
        return self
    end
    function wrapper:findChild(childName)
        local child = fusionInstanceWrapper(assert(instance:FindFirstChild(childName, true), 'Could not find child "' .. childName .. '" on ' .. instance.Name))
        table.insert(self[Children], child)
        return child
    end
    function wrapper:DisconnectAll()
        for _, c in self.connections do c:Disconnect() end
        for _, c in self[Children] do c:DisconnectAll() end
    end
    function wrapper:Destroy()
        self:DisconnectAll()
        for _, c in self[Children] do c:Destroy() end
        instance:Destroy()
        table.clear(self)
        setmetatable(self, nil)
    end
    setmetatable(wrapper, {
        __index = instance,
        __newindex = function(s, k, v)
            if not((select(2, pcall(function() local _=instance[k] end)) or ""):find("is not a valid member of")) then
                instance[k] = v
            else
                rawset(s, k, v)
            end
        end
    })
    return wrapper
end

local function getLocalTimeNow()
    return DateTime.now():FormatLocalTime('LTS', 'en-us')
end

local function parseLineText(logtype, content: string)
    return string.format('<font color="' .. LOG_CONTEXT_FONT_COLORS[logtype] .. '">[%s]</font> %s', getLocalTimeNow(), content)
end

local function parseBarText(context: {string})
    local function wrapInColor(text, colorContext)
        return string.format('<font color="' .. BAR_CONTEXT_FONT_COLORS[colorContext] .. '">%s</font>', text)
    end

    local function toString(texts)
        return table.concat(texts, " ")
    end

    local text = {}
    for index, content in ipairs(context) do
        if index == 1 then
            text[index] = wrapInColor(content, 'packageContext')
        elseif index == 2 then
            text[index] = wrapInColor(content, 'commandContext')
        else
            local isLogic = type(select(1, pcall(HttpService.JSONDecode, HttpService, content))) == "boolean"
            if content:sub(-1, 1) == "@" then
                text[index] = wrapInColor(content, 'statementContext')
            elseif isLogic then
                text[index] = wrapInColor(content, 'logicContext')
            end
        end
    end

    return toString(text), context
end

local function createUIPadding(a, b, c, d)
    if b and (not d and not c) then b = d end
    if a and (not c and not d) then c = a end

    return New "UIPadding" {
        PaddingLeft = UDim.new(0, a),
        PaddingRight = UDim.new(0, b),
        PaddingTop = UDim.new(0, c),
        PaddingBottom = UDim.new(0, d),
    }
end

local function createGui()
    return New "ScreenGui" {
        DisplayOrder = 1000,
        Name = "Inline",
        ResetOnSpawn = false,
        AutoLocalize = false,
        Enabled = true,
        Parent = if gethui then gethui() else game:GetService("CoreGui"),

        [Children] = {
            New "CanvasGroup" {
                Name = "InlineConsoleWindow",

                BackgroundTransparency = 0.4,
                BackgroundColor3 = Color3.fromRGB(17, 17, 17),
                BorderSizePixel = 0,
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 500, 0, 200),
                AnchorPoint = Vector2.new(0.5, 0.5),

                Visible = Computed(function()
                    return if Tweens.transparency:get() >= 1 then false else true
                end),
                GroupTransparency = Computed(function()
                    return Tweens.transparency:get()
                end),

                [Children] = {
                    createUIPadding(3, 3),
                    New "ScrollingFrame" {
                        BackgroundTransparency = 1,

                        Size = UDim2.fromScale(1, 0.8225),
                        AnchorPoint = Vector2.new(0.5, 0),
                        Position = UDim2.fromScale(0.5, 0),

                        ScrollBarImageColor3 = Color3.fromRGB(235, 235),
                        ScrollBarThickness = 5,

                        CanvasSize = UDim2.fromScale(0, 0),
                        AutomaticCanvasSize = Enum.AutomaticSize.Y,
                        CanvasPosition = Computed(function()
                            return Vector2.new(0, States.canvasHeightPosition:get())
                        end),

                        [Children] = {
                            createUIPadding(2, 2),
                            New "UIListLayout" {
                                Padding = UDim.new(0, 1),
                                SortOrder = Enum.SortOrder.LayoutOrder,
                                FillDirection = Enum.FillDirection.Vertical,
                                VerticalAlignment = Enum.VerticalAlignment.Top,
                            },
                            ComputedPairs(States.historySet, function(info)
                                return New "Frame" {
                                    Name = "Line",

                                    BackgroundTransparency = 1,
                                    Size = UDim2.fromScale(1, 0),
                                    AnchorPoint = Vector2.new(0.5, 0.5),
                                    AutomaticSize = Enum.AutomaticSize.Y,
                                    
                                    [Children] = {
                                        New "TextLabel" {
                                            Name = "Label",

                                            BackgroundTransparency = 1,
                                            Size = UDim2.fromScale(1, 0),
                                            Position = UDim2.fromScale(0.5, 0.5),
                                            AnchorPoint = Vector2.new(0.5, 0.5),

                                            Text = parseLineText(info.type, info.text),
                                            TextSize = TEXT_SIZE,
                                            TextColor3 = Color3.fromRGB(235, 235, 235),

                                            TextXAlignment = Enum.TextXAlignment.Left,
                                            TextYAlignment = Enum.TextYAlignment.Center,
                                        }
                                    }
                                }
                            end, function(element)
                                element:Destroy()
                            end)
                        }
                    },
                    New "Frame" {
                        BackgroundTransparency = 1,

                        Size = UDim2.fromScale(1, 0.25),
                        AnchorPoint = Vector2.new(0.5, 1),
                        Position = UDim2.fromScale(0.5, 1),
                        
                        [Children] = {
                            New "TextBox" {
                                Name = "InputFocus",

                                ClearTextOnFocus = true,
                                MultiLine = false,

                                TextSize = TEXT_SIZE,
                                TextTransparency = 1,
                                Text = "",

                                Size = UDim2.new(1, 1),
                                AnchorPoint = Vector2.new(0.5, 1),
                                Position = UDim2.fromScale(0.5, 1),
                                
                                BackgroundTransparency = 1,

                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextYAlignment = Enum.TextYAlignment.Center,
                                Selectable = false,
                            },
                            New "TextLabel" {
                                Name = "InputDisplay",
                                
                                Size = UDim2.new(1, 1),
                                AnchorPoint = Vector2.new(0.5, 1),
                                Position = UDim2.fromScale(0.5, 1),

                                BackgroundTransparency = 1,
                                Text = "",

                                RichText = true,
                                TextSize = TEXT_SIZE,
                                TextColor3 = Color3.fromRGB(235, 235, 235),

                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextYAlignment = Enum.TextYAlignment.Center,
                            }
                        }
                    }
                }
            }
        }
    }
end

local function focusBar(window)
    local wrappedDisplay, wrappedFocus = window:findChild("InputDisplay"), window:findChild("InputFocus")
    local inputDisplay, inputFocus = wrappedDisplay:get(), wrappedFocus:get()

    local function focus()
        inputFocus.Text = ""
        inputDisplay.Text = '<font color="rgb(162, 161, 161)">start typing to call a command</font>'

        task.delay(0.1, inputFocus.CaptureFocus, inputFocus)
    end
    
    wrappedFocus:onPropChanged("Text", function()
        local input = inputFocus.Text
        local context = string.split(input, " ")
        local text = parseBarText(context)
        inputDisplay.Text = text
    end)

    LifecycleMaid:GiveTask(function()
        wrappedFocus:DisconnectAll()
        wrappedDisplay:DisconnectAll()
    end)
    
    focus()
end

local function unfocusBar(window)
    LifecycleMaid:DoCleaning()
end

local function toggle(window)
    local newState = not States.toggled:get()
    if newState then
        focusBar(window)
        States.transparency:set(0)
    else
        unfocusBar(window)
        States.transparency:set(1)
    end
    States.toggled:set(newState)
end

local Window = fusionInstanceWrapper(createGui())
Inline.Maid:GiveTask(function()
    Window:Destroy()
    LifecycleMaid:DoCleaning()
end)

Inline.Maid:GiveTask(UserInputService.InputBegan:Connect(function(inputObject, gameProcessedEvent)
    if gameProcessedEvent then return end
    if inputObject.UserInputType == Enum.UserInputType.Keyboard then
        if inputObject.KeyCode == Enum.KeyCode.Backquote then
            toggle(Window)
        end
    end
end))