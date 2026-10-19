--!nocheck
-- CentWuiLib example (Linoria-compatible fork with cooler theme + corner decals)
-- Live demo: https://github.com/maksimvoovoo-prog/CentWuiLIB/tree/main/CentWuiLIB-main
local repo = 'https://raw.githubusercontent.com/maksimvoovoo-prog/CentWuiLIB/main/CentWuiLIB-main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua?t=' .. tick()))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua?t=' .. tick()))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua?t=' .. tick()))()

-- Library exposes these via getgenv(); declare as locals so type checkers see them
local Toggles = getgenv().Toggles
local Options = getgenv().Options

local Window = Library:CreateWindow({
    -- Set Center to true if you want the menu to appear in the center
    -- Set AutoShow to true if you want the menu to appear when it is created
    -- Position and Size are also valid options here
    -- but you do not need to define them unless you are changing them :)

    Title = 'CentWuiLIB demo',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,

    -- Background: purple -> lighter purple, top-down (Downways), behind ALL options
    BackgroundGradient = 'Downways',
    BackgroundGradientColors = {
        Color3.fromRGB(88, 40, 180),    -- top: rich purple
        Color3.fromRGB(190, 150, 255),  -- bottom: lighter purple
    },

    -- Background decal: asset 7710824618 behind everything, half transparent (0.5)
    BackgroundDecal = { Asset = 7710824618, Transparency = 0.5 },
    BackgroundTransparency = 0.5,

    -- Corner decals: same asset 7710824618 on all 4 corners, half transparent
    CornerDecals = {
        TopLeft = { Asset = 7710824618, Transparency = 0.5, Size = 56 },
        TopRight = { Asset = 7710824618, Transparency = 0.5, Size = 56 },
        BottomLeft = { Asset = 7710824618, Transparency = 0.5, Size = 56 },
        BottomRight = { Asset = 7710824618, Transparency = 0.5, Size = 56 },
    },
    CornerDecalSize = 56,
    CornerTransparency = 0.5,
})

-- CentWuiLib corner-decal API (run any time after CreateWindow):
-- Window:SetCornerDecal('TopRight', 12345678, 0.1, 56)
-- Window:SetCornerTransparency('TopRight', 0.25)
-- Window:SetCornerSize('TopRight', 64)
-- Window:ClearCorner('TopRight')
-- Window:ClearAllCorners()

-- CentWuiLib background API:
-- Window:SetBackgroundGradient('Sideways') -- or 'Downways', 0-360, true, false
-- Window:SetBackgroundGradientDirection('Downways')
-- Window:SetBackgroundGradientColors(Color3.fromRGB(30,20,60), Color3.fromRGB(10,10,18))
-- Window:SetBackgroundDecal(11223344, 0.85)
-- Window:SetBackgroundTransparency(0.5)
-- Window:ClearBackgroundDecal()

-- CALLBACK NOTE:
-- Passing in callback functions via the initial element parameters (i.e. Callback = function(Value)...) works
-- HOWEVER, using Toggles/Options.INDEX:OnChanged(function(Value) ... ) is the RECOMMENDED way to do this.
-- I strongly recommend decoupling UI code from logic code. i.e. Create your UI elements FIRST, and THEN setup :OnChanged functions later.

-- You do not have to set your tabs & groups up this way, just a prefrence.
local Tabs = {
    Main = Window:AddTab('Main'),
    Crosshair = Window:AddTab('Crosshair'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
};

-- Show the first tab by default so tab buttons and content are visible immediately
Tabs.Main:ShowTab();

-- // Example: custom gradient + text background on a tab button //--
-- Tabs.Main.Gradient.Enabled = true;
-- Tabs.Main.Gradient.Color = ColorSequence.new({
--     ColorSequenceKeypoint.new(0, Color3.new(1, 0.2, 0.2)),
--     ColorSequenceKeypoint.new(0.5, Color3.new(1, 0.8, 0.2)),
--     ColorSequenceKeypoint.new(1, Color3.new(0.2, 1, 0.2)),
-- });
-- Tabs.Main.Gradient.Rotation = 45;
-- Tabs.Main.TextBackground.BackgroundColor3 = Color3.new(0, 0, 0);
-- Tabs.Main.TextBackground.BackgroundTransparency = 0.3;

-- // Crosshair demo: cross + dot, every control saves to config. //
local CrosshairLeft = Tabs.Crosshair:AddLeftGroupbox('Crosshair')
local CrosshairRight = Tabs.Crosshair:AddRightGroupbox('Preview & Style')

CrosshairLeft:AddToggle('CrosshairEnabled', {
    Text = 'Enable crosshair',
    Default = true,
})

CrosshairLeft:AddToggle('CrosshairDot', {
    Text = 'Center dot',
    Default = true,
})

CrosshairLeft:AddSlider('CrosshairSize', {
    Text = 'Cross size',
    Default = 12,
    Min = 2,
    Max = 40,
    Rounding = 0,
    Suffix = 'px',
})

CrosshairLeft:AddSlider('CrosshairGap', {
    Text = 'Cross gap',
    Default = 4,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Suffix = 'px',
})

CrosshairLeft:AddSlider('CrosshairThickness', {
    Text = 'Line thickness',
    Default = 2,
    Min = 1,
    Max = 6,
    Rounding = 0,
    Suffix = 'px',
})

CrosshairLeft:AddSlider('CrosshairDotSize', {
    Text = 'Dot size',
    Default = 3,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Suffix = 'px',
})

CrosshairRight:AddLabel('Crosshair color'):AddColorPicker('CrosshairColor', {
    Default = Color3.fromRGB(178, 132, 255),
    Title = 'Crosshair color',
})

CrosshairRight:AddSlider('CrosshairTransparency', {
    Text = 'Transparency',
    Default = 0,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = '%',
})

CrosshairRight:AddDropdown('CrosshairStyle', {
    Values = { 'Cross + Dot', 'Cross only', 'Dot only' },
    Default = 1,
    Multi = false,
    Text = 'Style preset',
})

CrosshairRight:AddButton({
    Text = 'Reset crosshair',
    Func = function()
        Toggles.CrosshairEnabled:SetValue(true)
        Toggles.CrosshairDot:SetValue(true)
        Options.CrosshairSize:SetValue(12)
        Options.CrosshairGap:SetValue(4)
        Options.CrosshairThickness:SetValue(2)
        Options.CrosshairDotSize:SetValue(3)
        Options.CrosshairTransparency:SetValue(0)
        Options.CrosshairStyle:SetValue('Cross + Dot')
        Library:Notify('Crosshair reset to defaults', 3)
    end,
})

CrosshairLeft:AddButton({
    Text = 'Use: Cross only',
    Func = function() Options.CrosshairStyle:SetValue('Cross only') end,
})

CrosshairLeft:AddButton({
    Text = 'Use: Dot only',
    Func = function() Options.CrosshairStyle:SetValue('Dot only') end,
})

-- Live crosshair overlay (Drawing API). All controls above save via SaveManager.
local CrosshairDraw = { Lines = {}, Dot = nil }

local function CrosshairState()
    local style = 'Cross + Dot'
    if Options.CrosshairStyle and type(Options.CrosshairStyle.Value) == 'string' then
        style = Options.CrosshairStyle.Value
    end
    return {
        Enabled = Toggles.CrosshairEnabled and Toggles.CrosshairEnabled.Value,
        Dot = Toggles.CrosshairDot and Toggles.CrosshairDot.Value,
        Size = Options.CrosshairSize.Value,
        Gap = Options.CrosshairGap.Value,
        Thick = Options.CrosshairThickness.Value,
        DotSize = Options.CrosshairDotSize.Value,
        Color = Options.CrosshairColor.Value,
        Trans = Options.CrosshairTransparency.Value / 100,
        Style = style,
    }
end

local function UpdateCrosshair()
    local ok = pcall(function()
        if #CrosshairDraw.Lines == 0 then
            for _ = 1, 4 do
                local line = Drawing.new('Line')
                line.Visible = false
                table.insert(CrosshairDraw.Lines, line)
            end
            local dot = Drawing.new('Circle')
            dot.Filled = true
            dot.Visible = false
            CrosshairDraw.Dot = dot
        end
    end)
    if not ok then return end

    local s = CrosshairState()
    local showCross = s.Enabled and (s.Style ~= 'Dot only')
    local showDot = s.Enabled and s.Dot and (s.Style ~= 'Cross only')
    local cam = workspace.CurrentCamera
    if not cam then return end
    local c = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

    local segs = {
        { c + Vector2.new(s.Gap, 0), c + Vector2.new(s.Gap + s.Size, 0) },
        { c - Vector2.new(s.Gap, 0), c - Vector2.new(s.Gap + s.Size, 0) },
        { c + Vector2.new(0, s.Gap), c + Vector2.new(0, s.Gap + s.Size) },
        { c - Vector2.new(0, s.Gap), c - Vector2.new(0, s.Gap + s.Size) },
    }

    for i, line in ipairs(CrosshairDraw.Lines) do
        line.Visible = showCross
        if showCross then
            line.From = segs[i][1]
            line.To = segs[i][2]
            line.Color = s.Color
            line.Thickness = s.Thick
            line.Transparency = 1 - s.Trans
        end
    end

    CrosshairDraw.Dot.Visible = showDot
    if showDot then
        CrosshairDraw.Dot.Position = c
        CrosshairDraw.Dot.Radius = s.DotSize
        CrosshairDraw.Dot.Color = s.Color
        CrosshairDraw.Dot.Transparency = 1 - s.Trans
    end
end

pcall(function()
    game:GetService('RunService').RenderStepped:Connect(UpdateCrosshair)
end)

-- Groupbox and Tabbox inherit the same functions
-- except Tabboxes you have to call the functions on a tab (Tabbox:AddTab(name))
local LeftGroupBox = Tabs.Main:AddLeftGroupbox('Groupbox')

-- We can also get our Main tab via the following code:
-- local LeftGroupBox = Window.Tabs.Main:AddLeftGroupbox('Groupbox')

-- Tabboxes are a tiny bit different, but here's a basic example:
--[[

local TabBox = Tabs.Main:AddLeftTabbox() -- Add Tabbox on left side

local Tab1 = TabBox:AddTab('Tab 1')
local Tab2 = TabBox:AddTab('Tab 2')

-- You can now call AddToggle, etc on the tabs you added to the Tabbox
]]

-- Groupbox:AddToggle
-- Arguments: Index, Options
LeftGroupBox:AddToggle('MyToggle', {
    Text = 'This is a toggle',
    Default = true, -- Default value (true / false)
    Tooltip = 'This is a tooltip', -- Information shown when you hover over the toggle

    Callback = function(Value)
        print('[cb] MyToggle changed to:', Value)
    end
})


-- Fetching a toggle object for later use:
-- Toggles.MyToggle.Value

-- Toggles is a table added to getgenv() by the library
-- You index Toggles with the specified index, in this case it is 'MyToggle'
-- To get the state of the toggle you do toggle.Value

-- Calls the passed function when the toggle is updated
Toggles.MyToggle:OnChanged(function()
    -- here we get our toggle object & then get its value
    print('MyToggle changed to:', Toggles.MyToggle.Value)
end)

-- This should print to the console: "My toggle state changed! New value: false"
Toggles.MyToggle:SetValue(false)

-- 1/15/23
-- Deprecated old way of creating buttons in favor of using a table
-- Added DoubleClick button functionality

--[[
    Groupbox:AddButton
    Arguments: {
        Text = string,
        Func = function,
        DoubleClick = boolean
        Tooltip = string,
    }

    You can call :AddButton on a button to add a SubButton!
]]

local MyButton = LeftGroupBox:AddButton({
    Text = 'Button',
    Func = function()
        print('You clicked a button!')
    end,
    DoubleClick = false,
    Tooltip = 'This is the main button'
})

local MyButton2 = MyButton:AddButton({
    Text = 'Sub button',
    Func = function()
        print('You clicked a sub button!')
    end,
    DoubleClick = true, -- You will have to click this button twice to trigger the callback
    Tooltip = 'This is the sub button (double click me!)'
})

--[[
    NOTE: You can chain the button methods!
    EXAMPLE:

    LeftGroupBox:AddButton({ Text = 'Kill all', Func = Functions.KillAll, Tooltip = 'This will kill everyone in the game!' })
        :AddButton({ Text = 'Kick all', Func = Functions.KickAll, Tooltip = 'This will kick everyone in the game!' })
]]

-- Groupbox:AddLabel
-- Arguments: Text, DoesWrap
LeftGroupBox:AddLabel('This is a label')
LeftGroupBox:AddLabel('This is a label\n\nwhich wraps its text!', true)

-- Groupbox:AddDivider
-- Arguments: None
LeftGroupBox:AddDivider()

--[[
    Groupbox:AddSlider
    Arguments: Idx, SliderOptions

    SliderOptions: {
        Text = string,
        Default = number,
        Min = number,
        Max = number,
        Suffix = string,
        Rounding = number,
        Compact = boolean,
        HideMax = boolean,
    }

    Text, Default, Min, Max, Rounding must be specified.
    Suffix is optional.
    Rounding is the number of decimal places for precision.

    Compact will hide the title label of the Slider

    HideMax will only display the value instead of the value & max value of the slider
    Compact will do the same thing
]]
LeftGroupBox:AddSlider('MySlider', {
    Text = 'This is my slider!',
    Default = 0,
    Min = 0,
    Max = 5,
    Rounding = 1,
    Compact = false,

    Callback = function(Value)
        print('[cb] MySlider was changed! New value:', Value)
    end
})

-- Options is a table added to getgenv() by the library
-- You index Options with the specified index, in this case it is 'MySlider'
-- To get the value of the slider you do slider.Value

local Number = Options.MySlider.Value
Options.MySlider:OnChanged(function()
    print('MySlider was changed! New value:', Options.MySlider.Value)
end)

-- This should print to the console: "MySlider was changed! New value: 3"
Options.MySlider:SetValue(3)

-- Groupbox:AddInput
-- Arguments: Idx, Info
LeftGroupBox:AddInput('MyTextbox', {
    Default = 'My textbox!',
    Numeric = false, -- true / false, only allows numbers
    Finished = false, -- true / false, only calls callback when you press enter

    Text = 'This is a textbox',
    Tooltip = 'This is a tooltip', -- Information shown when you hover over the textbox

    Placeholder = 'Placeholder text', -- placeholder text when the box is empty
    -- MaxLength is also an option which is the max length of the text

    Callback = function(Value)
        print('[cb] Text updated. New text:', Value)
    end
})

Options.MyTextbox:OnChanged(function()
    print('Text updated. New text:', Options.MyTextbox.Value)
end)

-- Groupbox:AddDropdown
-- Arguments: Idx, Info

LeftGroupBox:AddDropdown('MyDropdown', {
    Values = { 'This', 'is', 'a', 'dropdown' },
    Default = 1, -- number index of the value / string
    Multi = false, -- true / false, allows multiple choices to be selected

    Text = 'A dropdown',
    Tooltip = 'This is a tooltip', -- Information shown when you hover over the dropdown

    Callback = function(Value)
        print('[cb] Dropdown got changed. New value:', Value)
    end
})

Options.MyDropdown:OnChanged(function()
    print('Dropdown got changed. New value:', Options.MyDropdown.Value)
end)

Options.MyDropdown:SetValue('This')

-- Multi dropdowns
LeftGroupBox:AddDropdown('MyMultiDropdown', {
    -- Default is the numeric index (e.g. "This" would be 1 since it if first in the values list)
    -- Default also accepts a string as well

    -- Currently you can not set multiple values with a dropdown

    Values = { 'This', 'is', 'a', 'dropdown' },
    Default = 1,
    Multi = true, -- true / false, allows multiple choices to be selected

    Text = 'A dropdown',
    Tooltip = 'This is a tooltip', -- Information shown when you hover over the dropdown

    Callback = function(Value)
        print('[cb] Multi dropdown got changed:', Value)
    end
})

Options.MyMultiDropdown:OnChanged(function()
    -- print('Dropdown got changed. New value:', )
    print('Multi dropdown got changed:')
    for key, value in next, Options.MyMultiDropdown.Value do
        print(key, value) -- should print something like This, true
    end
end)

Options.MyMultiDropdown:SetValue({
    This = true,
    is = true,
})

LeftGroupBox:AddDropdown('MyPlayerDropdown', {
    SpecialType = 'Player',
    Text = 'A player dropdown',
    Tooltip = 'This is a tooltip', -- Information shown when you hover over the dropdown

    Callback = function(Value)
        print('[cb] Player dropdown got changed:', Value)
    end
})

-- Label:AddColorPicker
-- Arguments: Idx, Info

-- You can also ColorPicker & KeyPicker to a Toggle as well

LeftGroupBox:AddLabel('Color'):AddColorPicker('ColorPicker', {
    Default = Color3.new(0, 1, 0), -- Bright green
    Title = 'Some color', -- Optional. Allows you to have a custom color picker title (when you open it)
    Transparency = 0, -- Optional. Enables transparency changing for this color picker (leave as nil to disable)

    Callback = function(Value)
        print('[cb] Color changed!', Value)
    end
})

Options.ColorPicker:OnChanged(function()
    print('Color changed!', Options.ColorPicker.Value)
    print('Transparency changed!', Options.ColorPicker.Transparency)
end)

Options.ColorPicker:SetValueRGB(Color3.fromRGB(0, 255, 140))

-- Label:AddKeyPicker
-- Arguments: Idx, Info

LeftGroupBox:AddLabel('Keybind'):AddKeyPicker('KeyPicker', {
    -- SyncToggleState only works with toggles.
    -- It allows you to make a keybind which has its state synced with its parent toggle

    -- Example: Keybind which you use to toggle flyhack, etc.
    -- Changing the toggle disables the keybind state and toggling the keybind switches the toggle state

    Default = 'MB2', -- String as the name of the keybind (MB1, MB2 for mouse buttons)
    SyncToggleState = false,


    -- You can define custom Modes but I have never had a use for it.
    Mode = 'Toggle', -- Modes: Always, Toggle, Hold

    Text = 'Auto lockpick safes', -- Text to display in the keybind menu
    NoUI = false, -- Set to true if you want to hide from the Keybind menu,

    -- Occurs when the keybind is clicked, Value is `true`/`false`
    Callback = function(Value)
        print('[cb] Keybind clicked!', Value)
    end,

    -- Occurs when the keybind itself is changed, `New` is a KeyCode Enum OR a UserInputType Enum
    ChangedCallback = function(New)
        print('[cb] Keybind changed!', New)
    end
})

-- OnClick is only fired when you press the keybind and the mode is Toggle
-- Otherwise, you will have to use Keybind:GetState()
Options.KeyPicker:OnClick(function()
    print('Keybind clicked!', Options.KeyPicker:GetState())
end)

Options.KeyPicker:OnChanged(function()
    print('Keybind changed!', Options.KeyPicker.Value)
end)

task.spawn(function()
    while true do
        wait(1)

        -- example for checking if a keybind is being pressed
        local state = Options.KeyPicker:GetState()
        if state then
            print('KeyPicker is being held down')
        end

        if Library.Unloaded then break end
    end
end)

Options.KeyPicker:SetValue({ 'MB2', 'Toggle' }) -- Sets keybind to MB2, mode to Hold

-- Long text label to demonstrate UI scrolling behaviour.
local LeftGroupBox2 = Tabs.Main:AddLeftGroupbox('Groupbox #2');
LeftGroupBox2:AddLabel('Oh no...\nThis label spans multiple lines!\n\nWe\'re gonna run out of UI space...\nJust kidding! Scroll down!\n\n\nHello from below!', true)

local TabBox = Tabs.Main:AddRightTabbox() -- Add Tabbox on right side

-- Anything we can do in a Groupbox, we can do in a Tabbox tab (AddToggle, AddSlider, AddLabel, etc etc...)
local Tab1 = TabBox:AddTab('Tab 1')
Tab1:AddToggle('Tab1Toggle', { Text = 'Tab1 Toggle' });

local Tab2 = TabBox:AddTab('Tab 2')
Tab2:AddToggle('Tab2Toggle', { Text = 'Tab2 Toggle' });

-- Dependency boxes let us control the visibility of UI elements depending on another UI elements state.
-- e.g. we have a 'Feature Enabled' toggle, and we only want to show that features sliders, dropdowns etc when it's enabled!
-- Dependency box example:
local RightGroupbox = Tabs.Main:AddRightGroupbox('Groupbox #3');
RightGroupbox:AddToggle('ControlToggle', { Text = 'Dependency box toggle' });

local Depbox = RightGroupbox:AddDependencyBox();
Depbox:AddToggle('DepboxToggle', { Text = 'Sub-dependency box toggle' });

-- We can also nest dependency boxes!
-- When we do this, our SupDepbox automatically relies on the visiblity of the Depbox - on top of whatever additional dependencies we set
local SubDepbox = Depbox:AddDependencyBox();
SubDepbox:AddSlider('DepboxSlider', { Text = 'Slider', Default = 50, Min = 0, Max = 100, Rounding = 0 });
SubDepbox:AddDropdown('DepboxDropdown', { Text = 'Dropdown', Default = 1, Values = {'a', 'b', 'c'} });

Depbox:SetupDependencies({
    { Toggles.ControlToggle, true } -- We can also pass `false` if we only want our features to show when the toggle is off!
});

SubDepbox:SetupDependencies({
    { Toggles.DepboxToggle, true }
});

-- Library functions
-- Sets the watermark visibility
Library:SetWatermarkVisibility(true)

-- Example of dynamically-updating watermark with common traits (fps and ping)
local FrameTimer = tick()
local FrameCounter = 0;
local FPS = 60;

local WatermarkConnection = game:GetService('RunService').RenderStepped:Connect(function()
    FrameCounter += 1;

    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter;
        FrameTimer = tick();
        FrameCounter = 0;
    end;

    local StatsService = game:GetService('Stats') :: any;
    Library:SetWatermark(('CentWuiLIB demo | %d fps | %d ms'):format(
        math.floor(FPS),
        math.floor(StatsService.Network.ServerStatsItem['Data Ping']:GetValue())
    ));
end);

Library.KeybindFrame.Visible = true; -- todo: add a function for this

Library:OnUnload(function()
    WatermarkConnection:Disconnect()

    pcall(function()
        for _, l in ipairs(CrosshairDraw.Lines) do l:Remove() end
        if CrosshairDraw.Dot then CrosshairDraw.Dot:Remove() end
    end)

    print('Unloaded!')
    Library.Unloaded = true
end)

-- UI Settings
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

-- I set NoUI so it does not show up in the keybinds menu
MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind -- Allows you to have a custom keybind for the menu

-- Addons:
-- SaveManager (Allows you to have a configuration system)
-- ThemeManager (Allows you to have a menu theme system)

-- Hand the library over to our managers
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

-- Ignore keys that are used by ThemeManager.
-- (we dont want configs to save themes, do we?)
SaveManager:IgnoreThemeSettings()

-- Adds our MenuKeybind to the ignore list
-- (do you want each config to have a different menu key? probably not.)
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

-- use case for doing it this way:
-- a script hub could have themes in a global folder
-- and game configs in a separate folder per game
ThemeManager:SetFolder('CentWuiLib')
SaveManager:SetFolder('CentWuiLib/specific-game')

-- Builds our config menu on the right side of our tab
SaveManager:BuildConfigSection(Tabs['UI Settings'])

-- Builds our theme menu (with plenty of built in themes) on the left side
-- NOTE: you can also call ThemeManager:ApplyToGroupbox to add it to a specific groupbox
ThemeManager:ApplyToTab(Tabs['UI Settings'])

-- You can use the SaveManager:LoadAutoloadConfig() to load a config
-- which has been marked to be one that auto loads!
SaveManager:LoadAutoloadConfig()

-- AutoShow = true handles window visibility; do not double-toggle
