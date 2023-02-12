local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UIX = loadstring(game:HttpGet(string.format(
    'https://raw.githubusercontent.com/%s/uiX/%s/src/init.lua',
    'weeeeee8',
    'main'
)))()

local Fusion = UIX.Require:import('/modules/fusion/Fusion.lua')
local GenericUtility = UIX.Require:import('/lib/GenericUtility.lua')
local Signal = UIX.Require:import('/modules/Signal.lua')

local CONFIGURATION_PATH = UIX.__internal.FilePaths.saves_folder..'/inlineConfig.lua'
local PLUGINS_PATH = UIX.__internal.FilePaths.plugins_folder..'/Inline'
local TEXT_SIZE_Y = 15
local MAXIMUM_LOGGED_MESSAGES = 100

local ERROR_LOG_MARKER = GenericUtility:Symbol("ErrorLog")
local WARNING_LOG_MARKER = GenericUtility:Symbol("WarningLog")
local INFO_LOG_MARKER = GenericUtility:Symbol("InfoLog")

UIX.reconcilefolder(PLUGINS_PATH)
local fileExistnt = UIX.reconcilefile(CONFIGURATION_PATH)

local Plugins = {}

local Events = {
    logOutput = Signal.new()
}
local Configuration = {
    Key = "Backquote",
}
local States = {
    windowShown = Fusion.State(false),
    windowPosition = Fusion.State(UDim2.new(0.5, 0.2)),
    logHistoryChildren = Fusion.State({})
}
local FusionComponents = {} do
    local function getLocalTime()
        return DateTime.now():FormatLocalTime("LTS", "en-us")
    end

    function FusionComponents.UIPadding(left, right, top, bottom)
        return Fusion.New "UIPadding" {
            PaddingLeft = UDim.new(0, left or 0),
            PaddingRight = UDim.new(0, right or 0),
            PaddingTop = UDim.new(0, top or 0),
            PaddingBottom = UDim.new(0, bottom or 0),
        }
    end

    function FusionComponents.Message(props)
        local function parseText(text)
            if props.LogType == ERROR_LOG_MARKER then
                return '<font color="rgb(245,20,0)">[' .. getLocalTime() .. "]</font> " .. text
            elseif props.LogType == WARNING_LOG_MARKER then
                return '<font color="rgb(245,160,0)">[' .. getLocalTime() .. "]</font> " .. text
            elseif props.LogType == INFO_LOG_MARKER then
                return '<font color="rgb(235,235,235)">[' .. getLocalTime() .. "]</font> " .. text
            end
        end

        return Fusion.New "Frame" {
            Name = "MessageLogContainer",

            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AnchorPoint = Vector2.one * 0.5,

            [Fusion.Children] = {
                Fusion.New "TextLabel" {
                    Text = parseText(props.ContextText),
                    TextColor3 = Color3.fromRGB(235, 235, 235),

                    AutomaticSize = Enum.AutomaticSize.Y,
                    TextYAlignment = Enum.TextYAlignment.Center,
                    TextXAlignment = Enum.TextXAlignment.Left,

                    TextSize = TEXT_SIZE_Y,
                    TextWrapped = true,
                    RichText = true,

                    Size = UDim2.new(1, 0, 0, 0),
                    BackgroundTransparency = 1,
                },
                FusionComponents.UIPadding(3, 3, 3, 3),
            }
        }
    end
end

local Utility = {} do
    function Utility.Draggable()
        local draggable = {}
        draggable.dragging = false
        draggable.canDrag = false
        draggable.update = nil
        draggable.hostObject = nil
        draggable.positionState = nil
        draggable.id = HttpService:GenerateGUID(false)
        draggable.originDragPosition = nil

        draggable.smoothingSpeed = 1

        function draggable:setPositionState(positionState)
            self.positionState = positionState
            return self
        end

        function draggable:setHostObject(hostObject)
            self.hostObject = hostObject
            return self
        end

        function draggable:start()
            if not self.started then
                self.started = true

                ContextActionService:BindAction("Draggable <" .. self.id .. ">", function(_, s, _)
                    if self.canDrag then
                        self.dragging = (s == Enum.UserInputState.Begin)
                        self.originDragPosition = if self.hostObject then self.hostObject.Position else UDim2.fromScale(0.5, 0.5)
                    end
                    return Enum.ContextActionResult.Pass
                end)

                self.update = RunService.RenderStepped:Connect(function(deltaTime)
                    if self.hostObject then
                        local ap, as = self.hostObject.AbsolutePosition, self.hostObject.AbsoluteSize
                        local tl, br = ap, ap + as
                        local mouseloc = UserInputService:GetMouseLocation()

                        self.canDrag = (mouseloc.X > tl.X and mouseloc.X < br.X) and (mouseloc.Y > br.Y and mouseloc.Y < tl.Y)
                        if self.canDrag and self.dragging then
                            self.positionState:set(self.hostObject.Position:Lerp(UDim2.new(
                                self.hostObject.Position.X.Scale,
                                (self.originDragPosition.X.Offset - mouseloc.X),
                                self.hostObject.Position.Y.Scale,
                                (self.originDragPosition.Y.Offset - mouseloc.Y)
                            ), math.min(deltaTime * 60, 1) * self.smoothingSpeed))
                        end
                    end
                end)
            end

            return self
        end

        function draggable:stop()
            self.started = false

            ContextActionService:UnbindAction("Draggable <" .. self.id .. ">")
            if self.update then
                self.update:Disconnect()
                self.update = nil
            end
        end

        return draggable
    end
end

local Window = Fusion.New "ScreenGui" {
    Name = "InlineInterface",
    Parent = if gethui then gethui() else game:GetService("CoreGui"),
    DisplayOrder = 50,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,

    [Fusion.Children] = {
        Fusion.New "Frame" {
            Name = "Body",

            BorderSizePixel = 0,
            BackgroundTransparency = 0,
            BackgroundColor3 = Color3.fromRGB(27, 27, 27),

            Size = UDim2.fromOffset(400, 300),
            Position = Fusion.Computed(function()
                return States.windowPosition:get()
            end),

            Visible = Fusion.Computed(function()
                return States.windowShown:get()
            end),

            [Fusion.Children] = {
                Fusion.New "Frame" {
                    Name = "LogHistory",
                    BackgroundTransparency = 1,

                    Size = UDim2.fromScale(1, 0.875),
                    Position = UDim2.fromScale(0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0),

                    [Fusion.Children] = {
                        Fusion.New "ScrollingFrame" {
                            AutomaticCanvasSize = Enum.AutomaticSize.Y,
                            ScrollingDirection = Enum.ScrollingDirection.Y,
                            ScrollBarThickness = 2,
                            ScrollBarImageColor3 = Color3.fromRGB(235, 235, 235),
                        
                            [Fusion.Children] = {
                                Fusion.New "UIListLayout" {
                                    Padding = UDim.new(0, 2),
                                    FillDirection = Enum.FillDirection.Vertical,
                                    VerticalAlignment = Enum.VerticalAlignment.Top,
                                    HorizontalAlignment = Enum.HorizontalAlignment.Left,
                                    SortOrder = Enum.SortOrder.LayoutOrder,
                                },
                                
                                Fusion.ComputedPairs(States.logHistoryChildren, function(logData)
                                    return FusionComponents.Message {
                                        ContextText = logData.text,
                                        LogType = logData.type,
                                    }
                                end)
                            }
                        },
                        FusionComponents.UIPadding(2, 2, 2, 2)
                    }
                },
                Fusion.New "Frame" {
                    Name = "InputContainer",

                    BackgroundTransparency = 1,

                    Size = UDim2.fromScale(1, 0.125),
                    Position = UDim2.fromScale(0.5, 1),
                    AnchorPoint = Vector2.new(0.5, 1),
                    
                    [Fusion.Children] = {
                        Fusion.New "Frame" {
                            BorderSizePixel = 0,
                            Size = UDim2.fromScale(1, 1),
                            Position = UDim2.fromScale(0.5, 0.5),
                            AnchorPoint = Vector2.new(0.5, 0.5),

                            BackgroundColor3 = Color3.fromRGB(12, 12, 12),

                            [Fusion.Children] = {
                                Fusion.New "TextBox" {
                                    BackgroundTransparency = 1,

                                    Size = UDim2.fromScale(1, 1),
                                    Position = UDim2.fromScale(0.5, 0.5),
                                    AnchorPoint = Vector2.new(0.5, 0.5),

                                    TextColor3 = Color3.fromRGB(235, 235, 235),

                                    PlaceholderText = "input command here",
                                    PlaceholderColor3 = Color3.fromRGB(117, 117, 117),

                                    RichText = true,
                                    MultiLine = false,
                                    ClearTextOnFocus = false,
                                    
                                    TextSize = TEXT_SIZE_Y,
                                    Text = "",

                                    TextYAlignment = Enum.TextYAlignment.Center,
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                }
                            }
                        }
                    }
                },

                FusionComponents.UIPadding(5, 5, 5, 5)
            }
        }
    }
}

local DraggableObject = Utility.Draggable()
DraggableObject:setPositionState(States.windowPosition):setHostObject(Window.Body):start()

UIX.Maid:GiveTask(UserInputService.InputBegan:Connect(function(inputObject, gpe)
    if gpe then return end
    if inputObject.UserInputType == Enum.KeyCode[Configuration.Key] then
        States.windowShown:set(not States.windowShown:get())
    end
    
end))

UIX.Maid:GiveTask(Events.logOutput:Connect(function(logContext)
    local newLogSet = States.logHistoryChildren:get()
    if #newLogSet > MAXIMUM_LOGGED_MESSAGES then
        newLogSet[#newLogSet] = nil

        local refreshedSet = {}
        for i = 2, #newLogSet+1, 1 do
            refreshedSet[i] = newLogSet[i-1]
        end
        newLogSet = refreshedSet
    end
    newLogSet[1] = logContext
    States.logHistoryChildren:set(newLogSet)
end))

UIX.Maid:GiveTask(function() -- cleaning
    for _, signal in pairs(Events) do
        signal:Destroy()
    end
    Window:Destroy()
    DraggableObject:stop()
end)

if fileExistnt then
    writefile(CONFIGURATION_PATH, HttpService:JSONEncode(Configuration))
else
    local success, content = pcall(readfile, CONFIGURATION_PATH)
    if success then
        Configuration = HttpService:JSONDecode(content)
    end
end