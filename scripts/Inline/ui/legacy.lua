local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local Maid = UIX.Require:get('Maid')
local Fusion = UIX.Require:get('Fusion')
local GenericUtility = UIX.Require:get('GenericUtility')
local Signal = UIX.Require:get('Signal')
local Inline = UIX.Inline

local TEXT_SIZE = 16
local WINDOW_HEIGHT = 200
local SUGGESTION_PRIORITY_TYPE = "Ascending"

local LOG_MARKERS = {
    error = GenericUtility:Symbol('LogError'),
    warning = GenericUtility:Symbol('LogWarning'),
    info = GenericUtility:Symbol('LogInfo'),
}
local SUGGESTION_HIGHLIGHT_COLOR_TOP = Color3.fromRGB(17, 172, 255)
local SUGGESTION_HIGHLIGHT_COLOR_BOTTOM = Color3.fromRGB(133, 133, 133)
local LOG_CONTEXT_FONT_COLORS = {
    [LOG_MARKERS.error] = 'rgb(245, 12, 0)',
    [LOG_MARKERS.warning] = 'rgb(245, 165, 5)',
    [LOG_MARKERS.info] = 'rgb(0, 34, 255)',
}
local BAR_CONTEXT_COLORS = {
    packageContext = Color3.fromRGB(229, 139, 69),
    commandContext = Color3.fromRGB(116, 149, 242),
    conditionContext = Color3.fromRGB(250, 242, 100), -- a string where it is wrapped by Open "(" and Close ")" parenthesis, only accepts number comparisons
    -- example, we want to make a loopbring and only bring those whose health is greater than 0. so we input: somePackage loopbring all (>0)
    logicContext = Color3.fromRGB(229, 69, 114), -- true or false
    argumentContext = Color3.fromRGB(235, 235, 235)
}
local EVENTS = {
    InvokeAutoComplete = Signal.new()
}
local PACKAGES = {}

local New, Children, State, ComputedPairs, Computed = Fusion.New, Fusion.Children, Fusion.State, Fusion.ComputedPairs, Fusion.Computed

local LifecycleMaid = Maid.new()
local States = {
    historySet = State({}),
    transparency = State(1),
    suggestionsShown = State(false),
    canvasHeightPosition = State(0),
    toggled = State(false),
    showHint = State({
        Suggestions = State({}),
        Visible = State(false),
        Position = State(UDim2.fromScale(0, 0))
    }),
    displaySet = State({})
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

local function getComparisonContext(text)
    -- gt = greater than, lt = less than, n = not, e = equals to, ge = greater than or equals to, le = less than or equals to, ne = not equals to,
    local textWithoutParenthesis = text:sub(2, #text-1)
    local content = string.split(textWithoutParenthesis, '')
    local chars = GenericUtility:Set('>','<','!','=')
    local comparisonContext
    for i = 1, #content do -- only expect 1-2 characters
        local char = content[i]
        if chars[char] then
            local realChar = content[i+1]
            if realChar ~= nil then
                if chars[realChar] then
                    comparisonContext = if char == ">" and realChar == "=" then "ge"
                        elseif char == "<" and realChar == "=" then "le"
                        elseif char == "!" and realChar == "=" then "ne"
                        elseif char == "<" and realChar == "!" then "nl"
                        elseif char == ">" and realChar == "!" then "ng"
                    else nil
                    break
                end
            end
            --check it based on the character
            comparisonContext = if char == ">" then "gt"
                elseif char == "<" then "lt"
                elseif char == "!" then "n"
                elseif char == "=" then "e"
            else nil
            break
        end
    end

    return comparisonContext
end

local function getLocalTimeNow()
    return DateTime.now():FormatLocalTime('LTS', 'en-us')
end

local function parseLineText(logtype, content: string)
    return string.format('<font color="' .. LOG_CONTEXT_FONT_COLORS[logtype] .. '">[%s]</font> %s', getLocalTimeNow(), content)
end

local function parseBarText(context: {string})
    local newSet = States.displaySet:get()
    for index, text in ipairs(context) do
        local color = if index == 1 then BAR_CONTEXT_COLORS.packageContext
            elseif index == 2 then BAR_CONTEXT_COLORS.commandContext
            elseif text:sub(1, 1) == "(" and text:sub(#text, #text) == ")" and getComparisonContext(text) ~= nil then BAR_CONTEXT_COLORS.conditionContext
            elseif type(select(2, pcall(HttpService.JSONDecode, HttpService, text))) == "boolean" then BAR_CONTEXT_COLORS.logicContext
            else BAR_CONTEXT_COLORS.argumentContext
        
        newSet[index] = {
            Message = text,
            Color = color,
        }
    end
    States.displaySet:set(newSet, true)

    local function _pack(set)
        local tbl = {}
        for _, info in ipairs(set) do
            table.insert(tbl, info.Message)
        end
        return tbl
    end
    return _pack(newSet)
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
                Size = UDim2.new(0, 500, 0, WINDOW_HEIGHT),
                AnchorPoint = Vector2.new(0.5, 0),

                Position = Computed(function()
                    return if Tweens.transparency:get() == 1 then UDim2.new(0.5, 0, 0, -WINDOW_HEIGHT) else UDim2.new(0.5, 0, 0, 50)
                end),
                GroupTransparency = Computed(function()
                    return Tweens.transparency:get()
                end),

                [Children] = {
                    createUIPadding(5, 5, 5, 5),
                    New "ScrollingFrame" {
                        BackgroundTransparency = 1,

                        Size = UDim2.new(1, 0, 0, WINDOW_HEIGHT - TEXT_SIZE),
                        AnchorPoint = Vector2.new(0.5, 0),
                        Position = UDim2.fromScale(0.5, 0),

                        ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
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
                        BackgroundTransparency = 0.8,
                        BackgroundColor3 = Color3.fromRGB(10, 10, 10),

                        Size = UDim2.new(1, 0, 0, TEXT_SIZE),
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

                                Size = UDim2.fromScale(0, 0),
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                Position = UDim2.fromScale(0.5, 0.5),
                                
                                BackgroundTransparency = 1,

                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextYAlignment = Enum.TextYAlignment.Center,
                                Selectable = false,
                            },
                            New "TextLabel" {
                                Name = "HintDisplay",
                                Position = UDim2.fromScale(0.5, 0.5),
                                AutomaticSize = Enum.AutomaticSize.X,
                                Size = UDim2.fromScale(0, 1),
                                AnchorPoint = Vector2.new(000, 0.5),
                                
                                Text = "",
                                TextColor3 = Color3.fromRGB(168, 168, 168),
                                TextSize = TEXT_SIZE,

                                BackgroundTransparency = 1,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextYAlignment = Enum.TextYAlignment.Center,
                            },
                            New "Frame" {
                                Name = "InputDisplayContent",
                                Size = UDim2.fromScale(1, 1),
                                AnchorPoint = Vector2.new(0, 0.5),
                                Position = UDim2.fromScale(0, 0.5),
                                BackgroundTransparency = 1,
                                
                                [Children] = {
                                    New "UIListLayout" {
                                        Padding = UDim.new(0, 2),
                                        SortOrder = Enum.SortOrder.LayoutOrder,
                                        FillDirection = Enum.FillDirection.Horizontal,
                                        VerticalAlignment = Enum.VerticalAlignment.Center,
                                        HorizontalAlignment = Enum.HorizontalAlignment.Left,
                                    },
                                    ComputedPairs(States.displaySet, function(i, displayData)
                                        return New "TextLabel" {
                                            Name = i,

                                            AutomaticSize = Enum.AutomaticSize.X,
                                            Size = UDim2.fromScale(0, 1),
                                            AnchorPoint = Vector2.new(0.5, 0.5),

                                            Text = displayData.Message,
                                            TextColor3 = displayData.Color,
                                            TextSize = TEXT_SIZE,

                                            BackgroundTransparency = 1,
                                            TextXAlignment = Enum.TextXAlignment.Left,
                                            TextYAlignment = Enum.TextYAlignment.Center,
                                        }
                                    end, function(element)
                                        element:Destroy()
                                    end),
                                }
                            },
                        }
                    }
                }
            },
            New "Frame" {
                Name = "InlineSuggestionsWindow",

                BackgroundTransparency = 0.4,
                BackgroundColor3 = Color3.fromRGB(17, 17, 17),
                BorderSizePixel = 0,

                AutomaticSize = Enum.AutomaticSize.X,

                Visible = Computed(function()
                    return States.showHint:get().Visible:get()
                end),
                Size = UDim2.fromOffset(0, WINDOW_HEIGHT - 50),
                Position = Computed(function()
                    return States.showHint:get().Position:get()
                end),

                [Children] = {
                    createUIPadding(3, 3, 3, 3),
                    New "ScrollingFrame" {
                        BackgroundTransparency = 1,

                        Size = UDim2.fromScale(1, 1),
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
                            ComputedPairs(States.showHint:get().Suggestions:get(), function(i, info)
                                return New "Frame" {
                                    Name = "SuggestionLine",

                                    BackgroundTransparency = 1,
                                    Size = UDim2.fromScale(1, 0),
                                    AnchorPoint = Vector2.new(0.5, 0.5),
                                    AutomaticSize = Enum.AutomaticSize.Y,
                                    LayoutOrder = i,
                                    
                                    [Children] = {
                                        New "TextLabel" {
                                            Name = "SuggestionLabel",

                                            BackgroundTransparency = 1,
                                            Size = UDim2.fromScale(1, 0),
                                            Position = UDim2.fromScale(0.5, 0.5),
                                            AnchorPoint = Vector2.new(0.5, 0.5),

                                            Text = info.suggestedResult,
                                            TextSize = TEXT_SIZE,
                                            TextColor3 = SUGGESTION_HIGHLIGHT_COLOR_BOTTOM:Lerp(SUGGESTION_HIGHLIGHT_COLOR_TOP, i / #States.showHint:get().Suggestions:get()),

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
                }
            }
        }
    }
end

local function focusBar(window)
    local wrappedDisplay, wrappedFocus, wrappedContentDisplay = window:findChild("HintDisplay"), window:findChild("InputFocus"), window:findChild("InputDisplayContent")
    local hintDisplay, inputFocus, contentDisplay = wrappedDisplay:get(), wrappedFocus:get(), wrappedContentDisplay:get()
    local arguments = {}
    local activePackage, activeCommand

    local function focus()
        inputFocus.Text = ""
        hintDisplay.Text = 'Start typing to invoke a command'

        task.delay(0.1, inputFocus.CaptureFocus, inputFocus)
    end

    local function findSuggestedResult(tbl, match)
        assert(#tbl > 0, "Table must be an array.")
        local possibleSuggestions = {}
        for i = #tbl, 1, -1 do
            if tbl[i].Name:sub(1, #match) == match then
                table.insert(possibleSuggestions, {
                    suggestedResult = tbl[i].Name,
                    len = #tbl[i].Name,
                })
            end
        end
        table.sort(possibleSuggestions, function(a, b)
            if SUGGESTION_PRIORITY_TYPE == "Ascending" then
                return a.len < b.len
            elseif SUGGESTION_PRIORITY_TYPE == "Descending" then
                return a.len > b.len
            else
                error("Invalid priority sorting type.")
            end
        end)
        return if possibleSuggestions[1] then possibleSuggestions[1].suggestedResult else nil, possibleSuggestions
    end

    local function tryDisplayHint(suggestions)
        local newSet = States.showHint:get()
        if #suggestions > 0 then
            newSet.Visible:set(false)
            newSet.Suggestions:set(suggestions, true)
            newSet.Position:set(UDim2.fromOffset(contentDisplay[tostring(#arguments)].AbsolutePosition.X, 50 + (WINDOW_HEIGHT - 50)))
        else
            newSet.Visible:set(false)
        end
        States.showHint:set(newSet)
    end
    
    wrappedFocus:onPropChanged("Text", function()
        local input = inputFocus.Text
        local context = string.split(input, " ")
        arguments = parseBarText(context)

        if #arguments == 1 then
            -- try getting the package
            local foundSuggestedPackage, suggestions = findSuggestedResult(PACKAGES, arguments[1])
            if foundSuggestedPackage then
                activePackage = foundSuggestedPackage
            end

            tryDisplayHint(suggestions)
        else
            if #arguments > 2 then
                if activeCommand then
                    local foundArgument = activeCommand.Arguments[(#arguments + 1) - #arguments]
                    if foundArgument then
                        local expects = foundArgument:expects()
                        if expects and #expects > 0 then
                            tryDisplayHint(expects)
                        end
                    end
                end
            elseif #arguments == 2 then
                -- try getting the command from the package
                if activePackage then
                    local foundSuggestedCommand, suggestions = findSuggestedResult(activePackage.Commands, arguments[2])
                    if foundSuggestedCommand then
                        activeCommand = foundSuggestedCommand
                    end
                    
                    tryDisplayHint(suggestions)
                end
            end
        end

        tryDisplayHint()

        if #hintDisplay.Text > 0 then
            hintDisplay.Text = ""
        end
    end)

    LifecycleMaid:GiveTask(EVENTS.InvokeAutoComplete:Connect(function()
        
    end))

    LifecycleMaid:GiveTask(function()
        wrappedFocus:DisconnectAll()
        wrappedDisplay:DisconnectAll()
        States.displaySet:set({}, true)
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
        if inputObject.KeyCode == Enum.KeyCode.F1 then
            toggle(Window)
        elseif inputObject.KeyCode == Enum.KeyCode.Tab and States.toggled:get() then
            EVENTS.InvokeAutoComplete:Fire()
        end
    end
end))