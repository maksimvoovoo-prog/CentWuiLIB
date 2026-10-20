-- // CentWuiLib — a cooler LinoriaLib fork
-- // Based on LinoriaLib by Inori / Wally / Stefanuk
-- // What's new in CentWuiLib:
-- //  • Modern dark + violet/cyan theme, rounded corners, glow & gradients
-- //  • Per-corner window decals by asset ID: Window:SetCornerDecal()
-- //  • Decal transparency / size / tint control per corner
-- //  • Background gradient (Sideways/Downways): Window:SetBackgroundGradient()
-- //  • Full-background decals with transparency: Window:SetBackgroundDecal()
-- //  • Sigma gradients applied by default everywhere (sliders, highlights, accents)
-- ///////////////////////////////////////////////////////////

local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
    Registry = {};
    RegistryMap = {};

    HudRegistry = {};

    FontColor = Color3.fromRGB(240, 235, 255);
    MainColor = Color3.fromRGB(46, 24, 86);
    BackgroundColor = Color3.fromRGB(26, 12, 54);
    AccentColor = Color3.fromRGB(168, 110, 255);
    AccentColor2 = Color3.fromRGB(110, 200, 255);
    OutlineColor = Color3.fromRGB(88, 52, 150);
    RiskColor = Color3.fromRGB(255, 85, 110),

    CornerRadius = UDim.new(0, 10);
    GlowTransparency = 0.82;
    TitleGradientEnabled = true;

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,

    CornerDecals = {};
    BackgroundDecals = {};

    DefaultGradientDirection = 'Downways';

    OpenedFrames = {};
    DependencyBoxes = {};

    Signals = {};
    ScreenGui = ScreenGui;
    CentWuiVersion = '1.1.2';
};

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta

    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400);

        if Hue > 1 then
            Hue = 0;
        end;

        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();

    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;

    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);

    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();

    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;

    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    
    return TeamList;
end;

-- ImageLabels need an IMAGE asset id. Many ids people copy are DECAL ids, which show up blank.
-- This tries: the id as-is -> decal->image via GetObjects (executors) -> legacy asset url.
-- Set Library.DecalDebug = true to print what happened. A failure always warns in the console.
Library.DecalImageCache = {};
Library.DecalDebug = false;

function Library:ResolveDecalImage(Label)
    local Original = Label.Image;
    local Id = Original:match('rbxassetid://(%d+)') or Original:match('[?&]id=(%d+)');
    if not Id then
        return;
    end;

    local Cached = Library.DecalImageCache[Id];
    if Cached then
        Label.Image = Cached;
        return;
    end;

    Label:SetAttribute('CentWuiDecalSource', Original);

    task.spawn(function()
        local function Stale()
            return (not Label.Parent) or Label:GetAttribute('CentWuiDecalSource') ~= Original;
        end;

        local function Loaded()
            pcall(function()
                game:GetService('ContentProvider'):PreloadAsync({ Label });
            end);
            return Label.IsLoaded;
        end;

        if Stale() then
            return;
        end;
        if Loaded() then
            if Library.DecalDebug then print(('[CentWuiLib] decal %s loaded as an image'):format(Id)); end;
            return;
        end;

        local Candidates = {};

        pcall(function()
            local Objects = game:GetObjects('rbxassetid://' .. Id);
            for _, Obj in ipairs(Objects) do
                if (Obj:IsA('Decal') or Obj:IsA('Texture')) and Obj.Texture ~= '' then
                    table.insert(Candidates, Obj.Texture);
                end;
                pcall(function() Obj:Destroy(); end);
            end;
        end);

        table.insert(Candidates, 'http://www.roblox.com/asset/?id=' .. Id);

        for _, Candidate in ipairs(Candidates) do
            if Stale() then
                return;
            end;

            Label.Image = Candidate;

            if Loaded() then
                Library.DecalImageCache[Id] = Candidate;
                if Library.DecalDebug then print(('[CentWuiLib] decal %s resolved to %s'):format(Id, Candidate)); end;
                return;
            end;
        end;

        if not Stale() then
            Label.Image = Original;
            warn(('[CentWuiLib] decal %s did not load. It may be a Decal id - use the Image id (open the decal in Studio / toolbox and copy the texture id), or the asset is not public.'):format(Id));
        end;
    end);
end;

function Library:ResolveDecalAsset(Asset)
    if Asset == nil or Asset == '' or Asset == 0 or Asset == '0' then
        return nil;
    end;

    if typeof(Asset) == 'number' then
        if Asset <= 0 then return nil; end;
        return ('rbxassetid://%d'):format(Asset);
    end;

    if typeof(Asset) == 'string' then
        local trimmed = Asset:match('^%s*(.-)%s*$');
        if trimmed == '' then return nil; end;
        if trimmed:find('^rbxassetid://') or trimmed:find('^http') then
            return trimmed;
        end;
        local num = trimmed:match('^(%d+)$');
        if num then
            return ('rbxassetid://%s'):format(num);
        end;
        return trimmed;
    end;

    if typeof(Asset) == 'Instance' and Asset:IsA('ImageLabel') then
        return Asset.Image;
    end;

    return nil;
end;

function Library:SafeCallback(f, ...)
    if (not f) then
        return;
    end;

    if not Library.NotifyOnError then
        return f(...);
    end;

    local success, event = pcall(f, ...);

    if not success then
        local _, i = event:find(":%d+: ");

        if not i then
            return Library:Notify(event);
        end;

        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end;
end;

function Library:ApplyCorner(Inst, Radius)
    local existing = Inst:FindFirstChildOfClass('UICorner');
    if existing then
        existing.CornerRadius = Radius or Library.CornerRadius;
        return existing;
    end;
    return Library:Create('UICorner', {
        CornerRadius = Radius or Library.CornerRadius;
        Parent = Inst;
    });
end;

function Library:ApplyGlow(Inst, Color, Transparency, Thickness)
    return Library:Create('UIStroke', {
        Color = Color or Library.AccentColor;
        Thickness = Thickness or 1.5;
        Transparency = Transparency or Library.GlowTransparency;
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
        LineJoinMode = Enum.LineJoinMode.Round;
        Parent = Inst;
    });
end;

-- Accepted directions: 'Sideways' (left->right), 'Leftways' (right->left),
-- 'Downways' (top->bottom), 'Upways' (bottom->top) or any number of degrees (0-360).
function Library:GradientRotationForDirection(Direction)
    if type(Direction) == 'number' then
        return Direction % 360;
    end;
    if type(Direction) ~= 'string' then
        Direction = Library.DefaultGradientDirection;
    end;

    local D = Direction:lower():gsub('[%s_%-]', '');

    if D == 'sideways' or D == 'horizontal' or D == 'rightways' or D == 'leftright' or D == 'right' then return 0; end;
    if D == 'downways' or D == 'vertical' or D == 'topbottom' or D == 'down' then return 90; end;
    if D == 'leftways' or D == 'rightleft' or D == 'left' then return 180; end;
    if D == 'upways' or D == 'bottomtop' or D == 'up' then return 270; end;

    local Num = tonumber(D);
    if Num then return Num % 360; end;
    return 90;
end;

-- ///////////////////////////////////////////////////////////
-- // ACCENT GRADIENT CORE
-- // Every "accent" colour in the UI goes through here, so it becomes
-- // AccentColor -> AccentColor2 and follows theme changes automatically.
-- // NOTE: a UIGradient MULTIPLIES with the object's own colour, so the
-- // object itself is painted WHITE and the gradient supplies the colour.
-- ///////////////////////////////////////////////////////////
Library.AccentGradients = setmetatable({}, { __mode = 'k' });

-- Default direction of each kind of accent object. Change them from your script:
--   Library:SetGradientDirection('Toggle', 'Downways')
--   Library:SetGradientDirection({ Toggle = 'Upways', Slider = 'Leftways' })
-- or pass  GradientDirections = { ... }  to CreateWindow.
Library.GradientDirections = {
    Default = 'Sideways';  -- anything not listed below
    Toggle  = 'Upways';    -- checkboxes
    Slider  = 'Sideways';  -- slider fills
    Line    = 'Sideways';  -- accent lines (window header, groupboxes, tabboxes, watermark, keybind list, color picker)
    Tab     = 'Sideways';  -- tab buttons
    Picker  = 'Sideways';  -- keybind picker outlines
    Notify  = 'Downways';  -- notification side bar
    Text    = 'Sideways';  -- accent coloured text
    Glow    = 45;          -- window outline glow
};
Library.GradientCategoryOf = setmetatable({}, { __mode = 'k' });
Library.GradientOverrides  = setmetatable({}, { __mode = 'k' });

local PaintableProps = {
    BackgroundColor3 = true;
    TextColor3 = true;
    ImageColor3 = true;
};

function Library:GetAccentSequence()
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, Library.AccentColor);
        ColorSequenceKeypoint.new(1, Library.AccentColor2 or Library.AccentColor);
    });
end;

function Library:SetAccentColors(Color1, Color2)
    if Color1 then Library.AccentColor = Color1; end;
    if Color2 then Library.AccentColor2 = Color2; end;
    Library:UpdateColorsUsingRegistry();
end;

function Library:IsPaintable(Inst, Property)
    if PaintableProps[Property] and Inst:IsA('GuiObject') then
        return true;
    end;
    return Property == 'Color' and Inst:IsA('UIStroke');
end;

function Library:SetGradientCategory(Inst, Category)
    Library.GradientCategoryOf[Inst] = Category;
end;

-- which rotation should this instance's gradient use right now?
function Library:GetGradientRotation(Inst, Property)
    local Dir = Library.GradientOverrides[Inst];

    if Dir == nil then
        local Cat = Library.GradientCategoryOf[Inst];
        if not Cat then
            Cat = (Property == 'TextColor3' and 'Text') or (Property == 'Color' and 'Glow') or 'Default';
        end;
        Dir = Library.GradientDirections[Cat] or Library.GradientDirections.Default;
    end;

    return Library:GradientRotationForDirection(Dir);
end;

local ACCENT_PREFIX = 'CentWuiAccent_';

function Library:RefreshGradientDirections()
    for Grad in next, Library.AccentGradients do
        local Owner = Grad.Parent;
        if Owner then
            Grad.Rotation = Library:GetGradientRotation(Owner, Grad.Name:sub(#ACCENT_PREFIX + 1));
        else
            Library.AccentGradients[Grad] = nil;
        end;
    end;
end;

-- Library:SetGradientDirection('Toggle', 'Upways')  or  Library:SetGradientDirection({ Toggle = 'Upways', ... })
function Library:SetGradientDirection(Category, Direction)
    if type(Category) == 'table' then
        for Cat, Dir in next, Category do
            Library.GradientDirections[Cat] = Dir;
        end;
    else
        Library.GradientDirections[Category] = Direction;
    end;
    Library:RefreshGradientDirections();
    Library:UpdateColorsUsingRegistry();
end;

-- change ONE object only (Direction = nil goes back to its category default)
function Library:SetObjectGradientDirection(Inst, Direction)
    Library.GradientOverrides[Inst] = Direction;
    Library:RefreshGradientDirections();
    Library:UpdateColorsUsingRegistry();
end;

-- turn the accent gradient on/off for ONE property of ONE instance
function Library:SetAccentPaint(Inst, Property, Enabled)
    local Name = ACCENT_PREFIX .. Property;
    local Grad = Inst:FindFirstChild(Name);

    if Enabled then
        if not Grad then
            Grad = Library:Create('UIGradient', {
                Name = Name;
                Rotation = Library:GetGradientRotation(Inst, Property);
                Parent = Inst;
            });
        end;

        Grad.Color = Library:GetAccentSequence();
        Grad.Enabled = true;
        Library.AccentGradients[Grad] = true;
        Inst[Property] = Color3.new(1, 1, 1);
    elseif Grad then
        Grad.Enabled = false;
    end;

    return Grad;
end;

-- Direction can be a category name ('Line', 'Slider', ...), a direction ('Upways') or degrees
function Library:ApplyAccentGradient(Inst, Direction)
    if type(Direction) == 'string' and Library.GradientDirections[Direction] ~= nil then
        Library:SetGradientCategory(Inst, Direction);
    elseif Direction ~= nil then
        Library.GradientOverrides[Inst] = Direction;
    end;

    local Prop = Inst:IsA('UIStroke') and 'Color' or 'BackgroundColor3';
    return Library:SetAccentPaint(Inst, Prop, true);
end;

function Library:ResolveColor(ColorIdx)
    if type(ColorIdx) == 'string' and Library[ColorIdx] ~= nil then
        return Library[ColorIdx];
    elseif type(ColorIdx) == 'function' then
        return ColorIdx();
    end;
    return ColorIdx;
end;

-- use this instead of  Inst.Prop = Library.AccentColor
function Library:SetColor(Inst, Property, ColorIdx)
    if Library:IsPaintable(Inst, Property) then
        if ColorIdx == 'AccentColor' then
            Library:SetAccentPaint(Inst, Property, true);
            return;
        end;
        Library:SetAccentPaint(Inst, Property, false);
    end;

    Inst[Property] = Library:ResolveColor(ColorIdx);
end;

-- ///////////////////////////////////////////////////////////
-- // GRADIENT GLOW
-- // Soft multi-layer glow around borders. Every layer is a UIStroke with the
-- // accent gradient (category 'Glow'), so it follows theme + direction settings.
-- //   Library:SetGlow(true/false)          turn all glows on/off
-- //   Library:SetGlowIntensity(0..1)       strength
-- //   Library:SetGlowAnimated(true/false)  slowly spinning gradient
-- //   Library.GlowSpinSpeed = 40           degrees per second
-- //   Library.HoverGlow = true             glow when hovering buttons/toggles/sliders/inputs
-- ///////////////////////////////////////////////////////////
Library.GlowEnabled = true;
Library.GlowIntensity = 1;
Library.GlowAnimated = true;
Library.GlowSpinSpeed = 40;
Library.HoverGlow = true;
-- { thickness, transparency } per layer (outer glow of the window)
Library.GlowLayers = { { 1.5, 0.45 }, { 3, 0.78 }, { 5, 0.9 }, { 8, 0.96 } };
-- same, but drawn INSIDE a box (groupboxes are clipped by their scroll frame, so they glow inwards)
Library.InnerGlowLayers = { { 1, 0.5 }, { 2.5, 0.82 }, { 4.5, 0.94 } };

Library.GlowStrokes = setmetatable({}, { __mode = 'k' });   -- stroke -> base transparency
Library.GlowGradients = setmetatable({}, { __mode = 'k' }); -- stroke -> its UIGradient

function Library:GetGlowTransparency(Stroke)
    local Base = Library.GlowStrokes[Stroke];
    if not Base then
        return Stroke.Transparency;
    end;
    return math.clamp(1 - (1 - Base) * Library.GlowIntensity, 0, 1);
end;

function Library:RegisterGlowStroke(Stroke, Base)
    Library.GlowStrokes[Stroke] = Base;
    Library:AddToRegistry(Stroke, { Color = 'AccentColor' }); -- creates the accent gradient
    Library.GlowGradients[Stroke] = Stroke:FindFirstChild('CentWuiAccent_Color');
    Stroke.Transparency = Library:GetGlowTransparency(Stroke);
    Stroke.Enabled = Library.GlowEnabled;
    return Stroke;
end;

-- glow OUTSIDE of Inst (for things that are not clipped, like the window)
function Library:ApplyBorderGlow(Inst)
    local List = {};
    for _, Layer in ipairs(Library.GlowLayers) do
        local Stroke = Library:ApplyGlow(Inst, nil, Layer[2], Layer[1]);
        Stroke.Name = 'CentWuiGlow';
        Library:RegisterGlowStroke(Stroke, Layer[2]);
        table.insert(List, Stroke);
    end;
    return List;
end;

-- glow INSIDE of Inst (Radius = Inst's corner radius in pixels)
function Library:ApplyInnerGlow(Inst, Radius, ZIndex)
    Radius = Radius or 0;
    local List = {};

    for _, Layer in ipairs(Library.InnerGlowLayers) do
        local T = Layer[1];
        local Host = Library:Create('Frame', {
            Name = 'CentWuiInnerGlow';
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0, T, 0, T);
            Size = UDim2.new(1, -2 * T, 1, -2 * T);
            ZIndex = ZIndex or 5;
            Parent = Inst;
        });
        if Radius > 0 then
            Library:Create('UICorner', { CornerRadius = UDim.new(0, math.max(Radius - T, 0)); Parent = Host; });
        end;

        local Stroke = Library:ApplyGlow(Host, nil, Layer[2], T);
        Stroke.Name = 'CentWuiGlow';
        Library:RegisterGlowStroke(Stroke, Layer[2]);
        table.insert(List, Stroke);
    end;

    return List;
end;

-- hover glow (created the first time it is needed)
function Library:GetHoverGlow(Inst)
    local Glow = Inst:FindFirstChild('CentWuiHoverGlow');
    if not Glow then
        Glow = Library:ApplyGlow(Inst, nil, 1, 2.5);
        Glow.Name = 'CentWuiHoverGlow';
        Glow:SetAttribute('CentWuiHover', true);
        Library:RegisterGlowStroke(Glow, 0.3);
        Glow.Transparency = 1;
    end;
    return Glow;
end;

function Library:SetHoverGlow(Inst, On)
    if not (Library.HoverGlow and Library.GlowEnabled) then
        return;
    end;
    local Glow = Library:GetHoverGlow(Inst);
    TweenService:Create(Glow, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = On and Library:GetGlowTransparency(Glow) or 1;
    }):Play();
end;

function Library:SetGlow(Enabled)
    Library.GlowEnabled = not not Enabled;
    for Stroke in next, Library.GlowStrokes do
        Stroke.Enabled = Library.GlowEnabled;
    end;
end;

function Library:SetGlowIntensity(Value)
    Library.GlowIntensity = math.clamp(Value or 1, 0, 1);
    for Stroke in next, Library.GlowStrokes do
        if not Stroke:GetAttribute('CentWuiHover') then
            Stroke.Transparency = Library:GetGlowTransparency(Stroke);
        end;
    end;
end;

function Library:SetGlowAnimated(Enabled)
    Library.GlowAnimated = not not Enabled;
    if not Library.GlowAnimated then
        Library:RefreshGradientDirections();
    end;
end;

-- spinning glow gradients
do
    local Spin = 0;
    table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
        if not (Library.GlowAnimated and Library.GlowEnabled) then
            return;
        end;

        Spin = (Spin + Delta * Library.GlowSpinSpeed) % 360;

        for Stroke, Grad in next, Library.GlowGradients do
            if Grad.Parent and Stroke.Transparency < 1 then
                Grad.Rotation = (Library:GetGradientRotation(Stroke, 'Color') + Spin) % 360;
            end;
        end;
    end));
end;

-- ///////////////////////////////////////////////////////////
-- // TAB ANIMATION SETTINGS (see Tab:ShowTab)
-- ///////////////////////////////////////////////////////////
Library.TabAnimation = true;
Library.TabAnimationTime = 0.32;
Library.TabSlideDistance = 26;

-- ///////////////////////////////////////////////////////////
-- // WINDOW BACKGROUND TRANSPARENCY
-- // Library.PanelTransparency: 0 = normal look, 1 = panels fully see-through
-- // (lets the background gradient / image / the game show through).
-- // Window:SetBackgroundTransparency(0.5)
-- ///////////////////////////////////////////////////////////
Library.PanelTransparency = 0;
Library.PanelBase = setmetatable({}, { __mode = 'k' }); -- frame -> its original BackgroundTransparency

function Library:GetPanelTransparency(Frame)
    local Base = Library.PanelBase[Frame];
    if Base == nil then
        return Frame.BackgroundTransparency;
    end;
    return math.clamp(1 - (1 - Base) * (1 - Library.PanelTransparency), 0, 1);
end;

function Library:RegisterPanel(Frame)
    Library.PanelBase[Frame] = Frame.BackgroundTransparency;
    Frame.BackgroundTransparency = Library:GetPanelTransparency(Frame);
    return Frame;
end;

function Library:SetPanelTransparency(Value)
    Library.PanelTransparency = math.clamp(tonumber(Value) or 0, 0, 1);
    for Frame in next, Library.PanelBase do
        Frame.BackgroundTransparency = Library:GetPanelTransparency(Frame);
    end;
    return Library.PanelTransparency;
end;

function Library:Create(Class, Properties)
    local _Instance = Class;

    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end;

    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end;

    return _Instance;
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;

    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    });

    Library:ApplyTextStroke(_Instance);

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return Library:Create(_Instance, Properties);
end;

function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;

    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            );

            if ObjPos.Y > (Cutoff or 40) then
                return;
            end;

            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                Instance.Position = UDim2.new(
                    0,
                    Mouse.X - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                    0,
                    Mouse.Y - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
                );

                RenderStepped:Wait();
            end;
        end;
    end)
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderSizePixel = 0,

        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 100,
        Parent = Library.ScreenGui,

        Visible = false,
    })
    Library:ApplyCorner(Tooltip, UDim.new(0, 6));

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X, Y);
        TextSize = 14;
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,

        Parent = Tooltip;
    });

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    Library:AddToRegistry(Label, {
        TextColor3 = 'FontColor',
    });

    local IsHovering = false

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            return
        end

        IsHovering = true

        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true

        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    local GlowsOnHover = (Properties.BorderColor3 == 'AccentColor');

    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        if GlowsOnHover then
            Library:SetHoverGlow(Instance, true);
        end;

        for Property, ColorIdx in next, Properties do
            Library:SetColor(Instance, Property, ColorIdx);

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        if GlowsOnHover then
            Library:SetHoverGlow(Instance, false);
        end;

        for Property, ColorIdx in next, PropertiesDefault do
            Library:SetColor(Instance, Property, ColorIdx);

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
end;

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:RefreshAccentDark()
    Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);
end;

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };

    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;

    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;

    for Property, ColorIdx in next, Properties do
        if ColorIdx == 'AccentColor' then
            Library:SetColor(Instance, Property, ColorIdx);
        end;
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
        end;

        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry()
    Library:RefreshAccentDark();

    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' or type(ColorIdx) == 'function' then
                Library:SetColor(Object.Instance, Property, ColorIdx);
            end
        end;
    end;

    -- recolour every accent gradient (also the ones that are not in the registry)
    local Seq = Library:GetAccentSequence();
    for Grad in next, Library.AccentGradients do
        if Grad.Parent then
            Grad.Color = Seq;
        else
            Library.AccentGradients[Grad] = nil;
        end;
    end;
end;

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end

    if Library.OnUnload then
        Library.OnUnload()
    end

    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end))

local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;

        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);

            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 28, 0, 14);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });
        Library:ApplyAccentGradient(Highlight, 'Line');

        local SatVibMapOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        });

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });

        local HueCursor = Library:Create('Frame', { 
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        });

        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        });

        Library:ApplyTextStroke(HueBox);

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        
        if Info.Transparency then 
            TransparencyBoxOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });

            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });

            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            });

            TransparencyCursor = Library:Create('Frame', { 
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title;
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });

        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                BorderColor3 = Color3.new(),
                ZIndex = 14,

                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            });

            Library:Create('UIListLayout', {
                Name = 'Layout',
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });

            Library:Create('UIPadding', {
                Name = 'Padding',
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            function ContextMenu:Show()
                self.Container.Visible = true
            end

            function ContextMenu:Hide()
                self.Container.Visible = false
            end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then
                    Callback = function() end
                end

                local Button = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = 13;
                    Text = Str;
                    ZIndex = 16;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                });

                Library:OnHighlight(Button, Button, 
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor' }
                );

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify('Copied color!', 2)
            end)

            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then
                    return Library:Notify('You have not copied a color!', 2)
                end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)

            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)

            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)
        end

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

        local SequenceTable = {};

        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;

        local HueSelectorGradient = Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end

            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            });

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value)
        end;

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false;
                    Library.OpenedFrames[Frame] = nil;
                end;
            end;

            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;
        end;

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);

            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X;
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));

                        ColorPicker:Display();

                        RenderStepped:Wait();
                    end;

                    Library:AttemptSave();
                end;
            end);
        end;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ColorPicker:Hide();
                end;

                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame

        Options[Idx] = ColorPicker;

        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;

        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle';
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;

            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        });
        Library:ApplyAccentGradient(PickOuter, 'Picker');

        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        });

        Library:AddToRegistry(PickInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        });

        local ModeSelectOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.new(0, 60, 0, 45 + 2);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });
        Library:ApplyAccentGradient(ModeSelectOuter, 'Picker');

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end);

        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        });

        Library:AddToRegistry(ModeSelectInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        });

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 18);
            TextSize = 13;
            Visible = false;
            ZIndex = 110;
            Parent = Library.KeybindContainer;
        },  true);

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for Idx, Mode in next, Modes do
            local ModeButton = {};

            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            });

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect();
                end;

                KeyPicker.Mode = Mode;

                Library:SetColor(Label, 'TextColor3', 'AccentColor');
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';

                ModeSelectOuter.Visible = false;
            end;

            function ModeButton:Deselect()
                KeyPicker.Mode = nil;

                Library:SetColor(Label, 'TextColor3', 'FontColor');
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select();
                    Library:AttemptSave();
                end;
            end);

            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;

            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then
                return;
            end;

            local State = KeyPicker:GetState();

            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);

            ContainerLabel.Visible = true;
            Library:SetColor(ContainerLabel, 'TextColor3', State and 'AccentColor' or 'FontColor');

            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';

            local YSize = 0
            local XSize = 0

            for _, Label in next, Library.KeybindContainer:GetChildren() do
                if Label:IsA('TextLabel') and Label.Visible then
                    YSize = YSize + 18;
                    if (Label.TextBounds.X > XSize) then
                        XSize = Label.TextBounds.X
                    end
                end;
            end;

            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then
                    return false;
                end

                local Key = KeyPicker.Value;

                if Key == 'MB1' or Key == 'MB2' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;

        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true;

                DisplayLabel.Text = '';

                local Break;
                local Text = '';

                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then
                            Text = '';
                        end;

                        Text = Text .. '.';
                        DisplayLabel.Text = Text;

                        wait(0.4);
                    end;
                end);

                wait(0.2);

                local Event;
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key;

                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Input.KeyCode.Name;
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    end;

                    Break = true;
                    Picking = false;

                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;

                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)

                    Library:AttemptSave();

                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true;
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;

                    if Key == 'MB1' or Key == 'MB2' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick()
                        end;
                    end;
                end;

                KeyPicker:Update();
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then
                KeyPicker:Update();
            end;
        end))

        KeyPicker:Update();

        Options[Idx] = KeyPicker;

        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;

        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            ZIndex = 1;
            Parent = Container;
        });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};

        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Text;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(Text)
            TextLabel.Text = Text

            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end

            Groupbox:Resize();
        end

        if (not DoesWrap) then
            setmetatable(Label, BaseAddons);
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Label;
    end;

    function Funcs:AddButton(...)
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end

            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)

        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 20);
                ZIndex = 5;
            });

            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            });

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 14;
                Text = Button.Text;
                ZIndex = 6;
                Parent = Inner;
            });

            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Inner;
            });

            Library:AddToRegistry(Outer, {
                BorderColor3 = 'Black';
            });

            Library:AddToRegistry(Inner, {
                BackgroundColor3 = 'MainColor';
                BorderColor3 = 'OutlineColor';
            });

            Library:OnHighlight(Outer, Outer,
                { BorderColor3 = 'AccentColor' },
                { BorderColor3 = 'Black' }
            );

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)
                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then
                    return false
                end

                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                    return false
                end

                return true
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })

                    Library:SetColor(Button.Label, 'TextColor3', 'AccentColor')
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true

                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })

                    Library:SetColor(Button.Label, 'TextColor3', 'FontColor')
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)

                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func);
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self
        end

        function Button:AddButton(...)
            local SubButton = {}

            ProcessButtonParams('SubButton', SubButton, ...)

            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                end
                return SubButton
            end

            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end

            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container

        local Divider = {
            Type = 'Divider',
        }

        Groupbox:AddBlank(2);
        local DividerOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 5);
            ZIndex = 5;
            Parent = Container;
        });

        local DividerInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DividerOuter;
        });

        Library:AddToRegistry(DividerOuter, {
            BorderColor3 = 'Black';
        });

        Library:AddToRegistry(DividerInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Groupbox:AddBlank(9);
        Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        Groupbox:AddBlank(1);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        local TextBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = TextBoxOuter;
        });

        Library:AddToRegistry(TextBoxInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter)
        end

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = TextBoxInner;
        });

        local ContainerBox = Library:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;

            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);

            ZIndex = 7;
            Parent = TextBoxInner;
        })

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;

            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),

            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or '';

            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;

            ZIndex = 7;
            Parent = ContainerBox;
        });

        Library:ApplyTextStroke(Box);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end;

            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then
                    Text = Textbox.Value
                end
            end

            Textbox.Value = Text;
            Box.Text = Text;

            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end

                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        local function Update()
            local PADDING = 2
            local reveal = ContainerBox.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X
                    local currentCursorPos = Box.Position.X.Offset + width

                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)

        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)

        Library:AddToRegistry(Box, {
            TextColor3 = 'FontColor';
        });

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        Options[Idx] = Textbox;

        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';

            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 13, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(ToggleOuter, {
            BorderColor3 = 'Black';
        });

        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = ToggleOuter;
        });

        Library:AddToRegistry(ToggleInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        -- gradient direction: Library.GradientDirections.Toggle, or Info.GradientDirection for this one
        Library:SetGradientCategory(ToggleInner, 'Toggle');
        Library.GradientOverrides[ToggleInner] = Info.GradientDirection;

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, 216, 1, 0);
            Position = UDim2.new(1, 6, 0, 0);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = ToggleInner;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 170, 1, 0);
            ZIndex = 8;
            Parent = ToggleOuter;
        });

        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        function Toggle:UpdateColors()
            Toggle:Display();
        end;

        function Toggle:SetGradientDirection(Direction)
            Library:SetObjectGradientDirection(ToggleInner, Direction);
        end;

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end

        function Toggle:Display()
            Library:SetColor(ToggleInner, 'BackgroundColor3', Toggle.Value and 'AccentColor' or 'MainColor');
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor;

            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);

            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 5 + 2);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;

        Library:UpdateDependencyBoxes();

        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(SliderOuter, {
            BorderColor3 = 'Black';
        });

        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = SliderOuter;
        });

        Library:AddToRegistry(SliderInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3 = Library.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = SliderInner;
        });
        Library:ApplyAccentGradient(Fill, 'Slider');

        Library:AddToRegistry(Fill, {
            BackgroundColor3 = 'AccentColor';
            BorderColor3 = 'AccentColorDark';
        });

        -- gradient direction: Library.GradientDirections.Slider, or Info.GradientDirection for this one
        if Info.GradientDirection ~= nil then
            Library.GradientOverrides[Fill] = Info.GradientDirection;
            Library:RefreshGradientDirections();
        end;

        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor2 or Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 8;
            Parent = Fill;
        });
        -- sits on the right edge of the fill, so it must match the END of the gradient
        Library:AddToRegistry(HideBorderRight, {
            BackgroundColor3 = function()
                -- colour of the fill's right edge for the current direction
                local Rot = Library:GetGradientRotation(Fill, 'BackgroundColor3');
                local A, B = Library.AccentColor, Library.AccentColor2 or Library.AccentColor;
                if Rot == 0 then return B; end;
                if Rot == 180 then return A; end;
                return A:Lerp(B, 0.5);
            end;
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text = 'Infinite';
            ZIndex = 9;
            Parent = SliderInner;
        });

        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end

        function Slider:SetGradientDirection(Direction)
            Library:SetObjectGradientDirection(Fill, Direction);
        end;

        function Slider:UpdateColors()
            Library:SetColor(Fill, 'BackgroundColor3', 'AccentColor');
            Fill.BorderColor3 = Library.AccentColorDark;
        end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';

            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix);
            end

            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            Fill.Size = UDim2.new(0, X, 1, 0);

            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0);
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value);
            end;

            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;

        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
        end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str);

            if (not Num) then
                return;
            end;

            Num = math.clamp(Num, Slider.Min, Slider.Max);

            Slider.Value = Num;
            Slider:Display();

            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                local mPos = Mouse.X;
                local gPos = Fill.Size.X.Offset;
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos);

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Mouse.X;
                    local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize);

                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;

                    Slider:Display();

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();

        Options[Idx] = Slider;

        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end;

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

        if (not Info.Text) then
            Info.Compact = true;
        end;

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType;
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local RelativeOffset = 0;

        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA('UIListLayout') then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset;
            end;
        end;

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(DropdownOuter, {
            BorderColor3 = 'Black';
        });

        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        });

        Library:AddToRegistry(DropdownInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        });

        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ZIndex = 8;
            Parent = DropdownInner;
        });

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = true;
            ZIndex = 7;
            Parent = DropdownInner;
        });

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        local MAX_DROPDOWN_ITEMS = 8;

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1);
        end;

        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end;

        RecalculateListPosition();
        RecalculateListSize();

        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        });

        Library:AddToRegistry(ListInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        });

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = 'AccentColor'
        })

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end;
                end;

                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end;

            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value);
                end;

                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then
                    Element:Destroy();
                end;
            end;

            local Count = 0;

            for Idx, Value in next, Values do
                local Table = {};

                Count = Count + 1;

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    ZIndex = 23;
                    Active = true,
                    Parent = Scrolling;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                    BorderColor3 = 'OutlineColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 25;
                    Parent = Button;
                });

                Library:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 24 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 23 }
                );

                local Selected;

                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;

                    Library:SetColor(ButtonLabel, 'TextColor3', Selected and 'AccentColor' or 'FontColor');
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;

                ButtonLabel.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local Try = not Selected;

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value[Value] = true;
                                else
                                    Dropdown.Value[Value] = nil;
                                end;
                            else
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value = Value;
                                else
                                    Dropdown.Value = nil;
                                end;

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton();
                                end;
                            end;

                            Table:UpdateButton();
                            Dropdown:Display();

                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);

                            Library:AttemptSave();
                        end;
                    end;
                end);

                Table:UpdateButton();
                Dropdown:Display();

                Buttons[Button] = Table;
            end;

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);

            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            ListOuter.Visible = true;
            Library.OpenedFrames[ListOuter] = true;
            DropdownArrow.Rotation = 180;
        end;

        function Dropdown:CloseDropdown()
            ListOuter.Visible = false;
            Library.OpenedFrames[ListOuter] = nil;
            DropdownArrow.Rotation = 0;
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};

                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then
                        nTable[Value] = true
                    end;
                end;

                Dropdown.Value = nTable;
            else
                if (not Val) then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end;
            end;

            Dropdown:BuildDropdownList();

            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown();
                else
                    Dropdown:OpenDropdown();
                end;
            end;
        end);

        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    Dropdown:CloseDropdown();
                end;
            end;
        end);

        Dropdown:BuildDropdownList();
        Dropdown:Display();

        local Defaults = {}

        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then
                table.insert(Defaults, Idx)
            end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then
                    table.insert(Defaults, Idx)
                end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();

        Options[Idx] = Dropdown;

        return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = {
            Dependencies = {};
        };
        
        local Groupbox = self;
        local Container = Groupbox.Container;

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });

        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        });

        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);

        Holder:GetPropertyChangedSignal('Visible'):Connect(function()
            Depbox:Resize();
        end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];

                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end;
            end;

            Holder.Visible = true;
            Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end;

            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end;

        Depbox.Container = Frame;

        setmetatable(Depbox, BaseGroupbox);

        table.insert(Library.DependencyBoxes, Depbox);

        return Depbox;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 12, 0, 40);
        Size = UDim2.new(0, 320, 0, 200);
        ZIndex = 100;
        Parent = ScreenGui;
    });

    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 6);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    local WatermarkOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 100, 0, -25);
        Size = UDim2.new(0, 213, 0, 22);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });
    Library:ApplyCorner(WatermarkOuter, UDim.new(0, 8));

    local WatermarkInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201;
        Parent = WatermarkOuter;
    });
    Library:ApplyCorner(WatermarkInner, UDim.new(0, 8));

    Library:AddToRegistry(WatermarkInner, {
        BackgroundColor3 = 'MainColor';
    });

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0, 2);
        Size = UDim2.new(1, 0, 1, -2);
        ZIndex = 202;
        Parent = WatermarkInner;
    });
    Library:ApplyCorner(InnerFrame, UDim.new(0, 8));

    local TopAccent = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Size = UDim2.new(1, -16, 0, 2);
        Position = UDim2.new(0, 8, 0, 0);
        ZIndex = 204;
        Parent = WatermarkInner;
    });
    Library:ApplyCorner(TopAccent, UDim.new(1, 0));
    Library:ApplyAccentGradient(TopAccent, 'Line');

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = InnerFrame;
    });

    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);

    local KeybindOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        AnchorPoint = Vector2.new(0, 0.5);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 20);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });
    Library:ApplyCorner(KeybindOuter, UDim.new(0, 8));

    local KeybindInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = KeybindOuter;
    });
    Library:ApplyCorner(KeybindInner, UDim.new(0, 8));

    Library:AddToRegistry(KeybindInner, {
        BackgroundColor3 = 'MainColor';
    }, true);

    local ColorFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Size = UDim2.new(1, -16, 0, 2);
        Position = UDim2.new(0, 8, 0, 0);
        ZIndex = 102;
        Parent = KeybindInner;
    });
    Library:ApplyCorner(ColorFrame, UDim.new(1, 0));
    Library:ApplyAccentGradient(ColorFrame, 'Line');

    Library:AddToRegistry(ColorFrame, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(5, 2),
        TextXAlignment = Enum.TextXAlignment.Left,

        Text = 'Keybinds';
        ZIndex = 104;
        Parent = KeybindInner;
    });

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        ZIndex = 1;
        Parent = KeybindInner;
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });

    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14);
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3);
    Library:SetWatermarkVisibility(true)

    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 14);

    YSize = YSize + 7

    local NotifyOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 100, 0, 10);
        Size = UDim2.new(0, 0, 0, YSize);
        ClipsDescendants = true;
        ZIndex = 100;
        Parent = Library.NotificationArea;
    });
    Library:ApplyCorner(NotifyOuter, UDim.new(0, 8));

    local NotifyInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = NotifyOuter;
    });
    Library:ApplyCorner(NotifyInner, UDim.new(0, 8));

    Library:AddToRegistry(NotifyInner, {
        BackgroundColor3 = 'MainColor';
    }, true);

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 102;
        Parent = NotifyInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 4, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 14;
        ZIndex = 103;
        Parent = InnerFrame;
    });

    local LeftColor = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, -1, 0, -1);
        Size = UDim2.new(0, 3, 1, 2);
        ZIndex = 104;
        Parent = NotifyOuter;
    });
    Library:ApplyAccentGradient(LeftColor, 'Notify');

    Library:AddToRegistry(LeftColor, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize + 8 + 4, 0, YSize), 'Out', 'Quad', 0.4, true);

    task.spawn(function()
        wait(Time or 5);

        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.4, true);

        wait(0.4);

        NotifyOuter:Destroy();
    end);
end;

function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1]
        if Arguments[2] ~= nil then Config.AutoShow = Arguments[2] end;
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 8 end
    for _, Key in next, { 'GlowEnabled', 'GlowIntensity', 'GlowAnimated', 'GlowSpinSpeed', 'HoverGlow', 'TabAnimation', 'TabAnimationTime', 'TabSlideDistance' } do
        if Config[Key] ~= nil then
            Library[Key] = Config[Key];
        end;
    end;
    if type(Config.GradientDirections) == 'table' then
        for Cat, Dir in next, Config.GradientDirections do
            Library.GradientDirections[Cat] = Dir;
        end;
    end;
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end
    if typeof(Config.CornerRadius) ~= 'UDim' then Config.CornerRadius = Library.CornerRadius end

    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local Window = {
        Tabs = {};
        CornerDecalConfig = {};
    };

    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel = 0;
        Position = Config.Position,
        Size = Config.Size,
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });
    Library:ApplyCorner(Outer, Config.CornerRadius);
    Library:ApplyBorderGlow(Outer); -- multi-layer gradient glow around the window

    Library:MakeDraggable(Outer, 25);

    local BgCanvas = Library:Create('Frame', {
        Name = 'CentWuiBackground';
        BackgroundColor3 = Library.MainColor;
        BackgroundTransparency = 0;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1;
        Parent = Outer;
    });
    Library:ApplyCorner(BgCanvas, Config.CornerRadius);

    Library:AddToRegistry(BgCanvas, {
        BackgroundColor3 = 'MainColor';
    });

    local Inner = Library:Create('Frame', {
        Name = 'CentWuiContent';
        BackgroundColor3 = Library.MainColor;
        BackgroundTransparency = 0.35;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 2;
        Parent = Outer;
    });
    Library:ApplyCorner(Inner, Config.CornerRadius);

    Library:AddToRegistry(Inner, {
        BackgroundColor3 = 'MainColor';
    });

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 14, 0, 0);
        Size = UDim2.new(1, -28, 0, 25);
        Text = Config.Title or '';
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 15;
        ZIndex = 6;
        Parent = Inner;
    });

    local HeaderAccent = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 12, 0, 23);
        Size = UDim2.new(1, -24, 0, 2);
        ZIndex = 5;
        Parent = Inner;
    });
    Library:ApplyCorner(HeaderAccent, UDim.new(1, 0));
    Library:ApplyAccentGradient(HeaderAccent, 'Line');

    local DecalLayer = Library:Create('Frame', {
        Name = 'CentWuiDecals';
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 60;
        Parent = Outer;
    });
    Library:Create('UICorner', { CornerRadius = Config.CornerRadius; Parent = DecalLayer });

    local function GetCornerAnchor(Corner)
        if Corner == 'TopLeft' or Corner == 'TL' then return Vector2.new(0, 0), UDim2.new(0, 4, 0, 4); end;
        if Corner == 'TopRight' or Corner == 'TR' then return Vector2.new(1, 0), UDim2.new(1, -4, 0, 4); end;
        if Corner == 'BottomLeft' or Corner == 'BL' then return Vector2.new(0, 1), UDim2.new(0, 4, 1, -4); end;
        if Corner == 'BottomRight' or Corner == 'BR' then return Vector2.new(1, 1), UDim2.new(1, -4, 1, -4); end;
        return nil, nil;
    end;

    local function NormalizeCorner(Corner)
        if Corner == 'TL' then return 'TopLeft'; end;
        if Corner == 'TR' then return 'TopRight'; end;
        if Corner == 'BL' then return 'BottomLeft'; end;
        if Corner == 'BR' then return 'BottomRight'; end;
        return Corner;
    end;

    local CornerDecals = {};

    function Window:SetCornerDecal(Corner, AssetId, Transparency, Size, ImageColor)
        if typeof(Transparency) == 'string' then Transparency = tonumber(Transparency); end;
        if typeof(Size) == 'string' then Size = tonumber(Size); end;

        Corner = NormalizeCorner(Corner);
        local Anchor, Pos = GetCornerAnchor(Corner);
        if not Anchor then return nil; end;

        local existing = CornerDecals[Corner];
        local image = Library:ResolveDecalAsset(AssetId);

        if not image then
            if existing then
                existing.Label:Destroy();
                CornerDecals[Corner] = nil;
                Window.CornerDecalConfig[Corner] = nil;
            end;
            return nil;
        end;

        Transparency = (typeof(Transparency) == 'number') and math.clamp(Transparency, 0, 1) or 0;
        Size = (typeof(Size) == 'number') and math.clamp(math.floor(Size), 16, 256) or 48;

        local label;
        if existing then
            label = existing.Label;
        else
            label = Library:Create('ImageLabel', {
                Name = ('Decal_%s'):format(Corner);
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Parent = DecalLayer;
            });
            label:SetAttribute('CentWuiDecal', true);
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 8); Parent = label });
            CornerDecals[Corner] = { Label = label };
        end;

        label.AnchorPoint = Anchor;
        label.Position = Pos;
        label.Size = UDim2.fromOffset(Size, Size);
        label.Image = image;
        Library:ResolveDecalImage(label);
        label.ImageTransparency = Transparency;
        label.ZIndex = 60;
        label.Visible = true;
        if typeof(ImageColor) == 'Color3' then label.ImageColor3 = ImageColor; end;

        CornerDecals[Corner].Asset = image;
        Window.CornerDecalConfig[Corner] = { Asset = AssetId; Image = image; Transparency = Transparency; Size = Size };

        return label;
    end;

    function Window:SetCornerTransparency(Corner, Transparency)
        Corner = NormalizeCorner(Corner);
        local data = CornerDecals[Corner];
        if not data then return nil; end;
        Transparency = math.clamp(tonumber(Transparency) or 0, 0, 1);
        data.Label.ImageTransparency = Transparency;
        if Window.CornerDecalConfig[Corner] then Window.CornerDecalConfig[Corner].Transparency = Transparency; end;
        return Transparency;
    end;

    function Window:SetCornerSize(Corner, Size)
        Corner = NormalizeCorner(Corner);
        local data = CornerDecals[Corner];
        if not data then return nil; end;
        Size = math.clamp(math.floor(tonumber(Size) or 48), 16, 256);
        data.Label.Size = UDim2.fromOffset(Size, Size);
        if Window.CornerDecalConfig[Corner] then Window.CornerDecalConfig[Corner].Size = Size; end;
        return Size;
    end;

    function Window:ClearCorner(Corner)
        return Window:SetCornerDecal(Corner, nil);
    end;

    function Window:ClearAllCorners()
        for _, C in ipairs({ 'TopLeft', 'TopRight', 'BottomLeft', 'BottomRight' }) do Window:ClearCorner(C); end;
    end;

    local BackgroundGradient = nil;

    function Window:SetBackgroundGradient(Direction)
        if Direction == false or Direction == nil then
            if BackgroundGradient then
                BackgroundGradient:Destroy();
                BackgroundGradient = nil;
            end;
            Window.BackgroundGradientDirection = nil;
            return nil;
        end;

        if Direction == true then
            Direction = Library.DefaultGradientDirection;
        end;

        local Rotation = Library:GradientRotationForDirection(Direction);
        Window.BackgroundGradientDirection = Direction;

        if not BackgroundGradient then
            BackgroundGradient = Library:Create('UIGradient', {
                Rotation = Rotation;
                Parent = BgCanvas;
            });
            BackgroundGradient:SetAttribute('CentWuiBackgroundGradient', true);
        else
            BackgroundGradient.Rotation = Rotation;
        end;

        local stops = Window.BackgroundGradientColors;
        if type(stops) == 'table' and typeof(stops[1]) == 'Color3' and typeof(stops[2]) == 'Color3' then
            BackgroundGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, stops[1]);
                ColorSequenceKeypoint.new(1, stops[2]);
            });
        else
            BackgroundGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library.MainColor);
                ColorSequenceKeypoint.new(1, Library.BackgroundColor);
            });
        end;

        return BackgroundGradient;
    end;

    function Window:SetBackgroundGradientDirection(Direction)
        return Window:SetBackgroundGradient(Direction);
    end;

    function Window:SetBackgroundGradientColors(TopOrLeft, BottomOrRight)
        if TopOrLeft == nil and BottomOrRight == nil then
            Window.BackgroundGradientColors = nil;
        else
            Window.BackgroundGradientColors = { TopOrLeft, BottomOrRight };
        end;
        if BackgroundGradient then
            return Window:SetBackgroundGradient(Window.BackgroundGradientDirection or Library.DefaultGradientDirection);
        end;
        return nil;
    end;

    local BackgroundDecal = nil;

    function Window:SetBackgroundDecal(AssetId, Transparency, ImageColor)
        if typeof(Transparency) == 'string' then Transparency = tonumber(Transparency); end;
        local image = Library:ResolveDecalAsset(AssetId);

        if not image then
            if BackgroundDecal then
                BackgroundDecal:Destroy();
                BackgroundDecal = nil;
                Library.BackgroundDecals[Window] = nil;
                Window.BackgroundDecalConfig = nil;
            end;
            return nil;
        end;

        Transparency = (typeof(Transparency) == 'number') and math.clamp(Transparency, 0, 1) or 0;

        if not BackgroundDecal then
            BackgroundDecal = Library:Create('ImageLabel', {
                Name = 'CentWuiBackgroundArt';
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 1, 0);
                ScaleType = Enum.ScaleType.Crop;
                ZIndex = 1;
                Parent = BgCanvas;
            });
            BackgroundDecal:SetAttribute('CentWuiDecal', true);
            BackgroundDecal:SetAttribute('CentWuiBackground', true);
            Library:ApplyCorner(BackgroundDecal, Config.CornerRadius);
        end;

        BackgroundDecal.Image = image;
        Library:ResolveDecalImage(BackgroundDecal);
        BackgroundDecal.ImageTransparency = Transparency;
        BackgroundDecal.Visible = true;
        if typeof(ImageColor) == 'Color3' then BackgroundDecal.ImageColor3 = ImageColor; end;

        Library.BackgroundDecals[Window] = BackgroundDecal;
        Window.BackgroundDecal = BackgroundDecal;
        Window.BackgroundDecalConfig = { Asset = AssetId; Image = image; Transparency = Transparency };

        return BackgroundDecal;
    end;

    -- window background (panels + gradient): 0 = normal, 1 = fully see-through
    function Window:SetBackgroundTransparency(Transparency)
        return Library:SetPanelTransparency(Transparency);
    end;

    -- transparency of the background IMAGE only
    function Window:SetBackgroundDecalTransparency(Transparency)
        if not BackgroundDecal then return nil; end;
        Transparency = math.clamp(tonumber(Transparency) or 0, 0, 1);
        BackgroundDecal.ImageTransparency = Transparency;
        if Window.BackgroundDecalConfig then Window.BackgroundDecalConfig.Transparency = Transparency; end;
        return Transparency;
    end;

    function Window:ClearBackgroundDecal()
        return Window:SetBackgroundDecal(nil);
    end;

    if type(Config.CornerDecals) == 'table' then
        for Corner, Value in pairs(Config.CornerDecals) do
            if type(Value) == 'table' then
                Window:SetCornerDecal(Corner, Value.Asset or Value.Id or Value.Image, Value.Transparency or 0, Value.Size or 48, Value.Color);
            else
                Window:SetCornerDecal(Corner, Value, Config.CornerTransparency or 0, Config.CornerDecalSize or 48);
            end;
        end;
    end;

    Window.DecalLayer = DecalLayer;
    Library.CornerDecals[Window] = CornerDecals;

    if Config.BackgroundGradient ~= nil and Config.BackgroundGradient ~= false then
        if type(Config.BackgroundGradientColors) == 'table' then
            Window:SetBackgroundGradientColors(Config.BackgroundGradientColors[1], Config.BackgroundGradientColors[2]);
        end;
        Window:SetBackgroundGradient(Config.BackgroundGradient);
    end;

    if Config.BackgroundTransparency ~= nil then
        Library:SetPanelTransparency(Config.BackgroundTransparency);
    end;

    if Config.BackgroundDecal ~= nil then
        if type(Config.BackgroundDecal) == 'table' then
            Window:SetBackgroundDecal(
                Config.BackgroundDecal.Asset or Config.BackgroundDecal.Id or Config.BackgroundDecal.Image,
                Config.BackgroundDecal.Transparency or Config.BackgroundDecalTransparency or 0,
                Config.BackgroundDecal.Color
            );
        else
            Window:SetBackgroundDecal(Config.BackgroundDecal, Config.BackgroundDecalTransparency or 0);
        end;
    end;

    local MainSectionOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BackgroundTransparency = 0.2;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 8, 0, 29);
        Size = UDim2.new(1, -16, 1, -37);
        ZIndex = 3;
        Parent = Inner;
    });
    Library:ApplyCorner(MainSectionOuter, UDim.new(0, 8));

    Library:AddToRegistry(MainSectionOuter, {
        BackgroundColor3 = 'BackgroundColor';
    });

    local MainSectionInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BackgroundTransparency = 0.25;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 3;
        Parent = MainSectionOuter;
    });
    Library:ApplyCorner(MainSectionInner, UDim.new(0, 8));

    Library:AddToRegistry(MainSectionInner, {
        BackgroundColor3 = 'BackgroundColor';
    });

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 8, 0, 8);
        Size = UDim2.new(1, -16, 0, 21);
        ZIndex = 1;
        Parent = MainSectionInner;
    });

    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabArea;
    });

    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BackgroundTransparency = 0.15;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 8, 0, 30);
        Size = UDim2.new(1, -16, 1, -38);
        ClipsDescendants = true; -- tab content slides in from the side
        ZIndex = 1;
        Parent = MainSectionInner;
    });
    Library:ApplyCorner(TabContainer, UDim.new(0, 8));

    Library:AddToRegistry(TabContainer, {
        BackgroundColor3 = 'MainColor';
    });

    -- window panels that follow Window:SetBackgroundTransparency
    for _, Panel in next, { BgCanvas, Inner, MainSectionOuter, MainSectionInner, TabContainer } do
        Library:RegisterPanel(Panel);
    end;

    -- sliding underline that follows the active tab
    local TabIndicator = Library:Create('Frame', {
        Name = 'CentWuiTabIndicator';
        BackgroundColor3 = Library.FontColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0, 29);
        Size = UDim2.new(0, 0, 0, 2);
        Visible = false;
        ZIndex = 7;
        Parent = MainSectionInner;
    });
    Library:ApplyCorner(TabIndicator, UDim.new(1, 0));
    Library:AddToRegistry(TabIndicator, { BackgroundColor3 = 'FontColor' });

    local IndicatorGoal, IndicatorTween;

    function Window:UpdateTabIndicator(Button, Animate)
        if not Button then
            TabIndicator.Visible = false;
            return;
        end;

        local Width = Button.AbsoluteSize.X;
        if Width <= 0 then
            return; -- layout not ready yet, the AbsoluteSize signal calls this again
        end;

        local X = Button.AbsolutePosition.X - MainSectionInner.AbsolutePosition.X;
        local Goal = {
            Position = UDim2.fromOffset(X + 4, 29);
            Size = UDim2.fromOffset(math.max(Width - 8, 4), 2);
        };

        if IndicatorGoal and IndicatorGoal.Position == Goal.Position and IndicatorGoal.Size == Goal.Size then
            return;
        end;
        IndicatorGoal = Goal;

        if IndicatorTween then
            IndicatorTween:Cancel();
            IndicatorTween = nil;
        end;

        if Animate and Library.TabAnimation and TabIndicator.Visible then
            IndicatorTween = TweenService:Create(TabIndicator, TweenInfo.new(Library.TabAnimationTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), Goal);
            IndicatorTween:Play();
        else
            TabIndicator.Position = Goal.Position;
            TabIndicator.Size = Goal.Size;
            TabIndicator.Visible = true;
        end;
    end;

    function Window:SetTabAnimation(Enabled)
        Library.TabAnimation = not not Enabled;
    end;

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title;
    end;

    function Window:AddTab(Name)
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
        };

        local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16);

        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BackgroundTransparency = 0;
            BorderSizePixel = 1;
            BorderColor3 = Library.OutlineColor;
            Size = UDim2.new(0, math.max(TabButtonWidth + 8 + 4, 60), 1, 0);
            ZIndex = 2;
            Parent = TabArea;
        });
        Library:ApplyCorner(TabButton, UDim.new(0, 6));

        -- active tab: white * gradient = full gradient, inactive tab: grey * gradient = dimmed gradient
        local TabButtonGradient = Library:ApplyAccentGradient(TabButton, 'Tab');

        local TabTextBackground = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BackgroundTransparency = 0.5;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 4, 0.5, 0);
            Size = UDim2.new(1, -8, 0, 16);
            AnchorPoint = Vector2.new(0, 0.5);
            ZIndex = 2;
            Parent = TabButton;
        });
        Library:ApplyCorner(TabTextBackground, UDim.new(0, 4));

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, -1);
            Text = Name;
            TextColor3 = Color3.new(1, 1, 1);
            ZIndex = 3;
            Parent = TabButton;
        });

        Tab.Gradient = TabButtonGradient;
        Tab.TextBackground = TabTextBackground;
        Tab.Button = TabButton;

        local Blocker = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 1, 0);
            Size = UDim2.new(1, 0, 0, 1);
            BackgroundTransparency = 1;
            ZIndex = 3;
            Parent = TabButton;
        });

        Library:AddToRegistry(Blocker, {
            BackgroundColor3 = 'MainColor';
        });

        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame',
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        });

        -- covers the tab while it fades in (see Tab:ShowTab)
        local TabCover = Library:Create('Frame', {
            Name = 'CentWuiTabFade';
            BackgroundColor3 = Library.MainColor;
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 40;
            Parent = TabFrame;
        });
        TabCover:SetAttribute('CentWuiNoFade', true);
        Library:ApplyCorner(TabCover, UDim.new(0, 8));
        Library:AddToRegistry(TabCover, { BackgroundColor3 = 'MainColor' });

        local TabTweens = {};
        local function CancelTabTweens()
            for _, Tw in next, TabTweens do
                Tw:Cancel();
            end;
            table.clear(TabTweens);
        end;
        local function PlayTabTween(Obj, Time, Props)
            local Tw = TweenService:Create(Obj, TweenInfo.new(Time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), Props);
            table.insert(TabTweens, Tw);
            Tw:Play();
            return Tw;
        end;

        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 8 - 1, 0, 8 - 1);
            Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 4 + 1, 0, 8 - 1);
            Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = LeftSide;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = RightSide;
        });

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y);
            end);
        end;

        function Tab:ShowTab()
            local Prev = Window.ActiveTab;

            if Prev == Tab and TabFrame.Visible then
                return;
            end;

            local Animate = Library.TabAnimation and Prev ~= nil and Prev ~= Tab and Outer.Visible;
            local Dir = 1; -- content slides in from the side of the tab you clicked

            if Prev and Prev.Button then
                Dir = (TabButton.AbsolutePosition.X >= Prev.Button.AbsolutePosition.X) and 1 or -1;
            end;

            for _, Other in next, Window.Tabs do
                Other:HideTab(Animate);
            end;

            CancelTabTweens();
            Window.ActiveTab = Tab;
            Blocker.BackgroundTransparency = 0;
            TabFrame.Visible = true;

            if Animate then
                local Time = Library.TabAnimationTime;

                TabFrame.Position = UDim2.new(0, Dir * Library.TabSlideDistance, 0, 0);
                TabCover.BackgroundTransparency = 0.1;
                TabCover.Visible = true;

                PlayTabTween(TabFrame, Time, { Position = UDim2.new(0, 0, 0, 0) });
                PlayTabTween(TabButton, 0.2, { BackgroundColor3 = Color3.new(1, 1, 1) });

                local Fade = PlayTabTween(TabCover, Time, { BackgroundTransparency = 1 });
                Fade.Completed:Connect(function(State)
                    if State == Enum.PlaybackState.Completed then
                        TabCover.Visible = false;
                    end;
                end);
            else
                TabFrame.Position = UDim2.new(0, 0, 0, 0);
                TabCover.Visible = false;
                TabButton.BackgroundColor3 = Color3.new(1, 1, 1);
            end;

            Window:UpdateTabIndicator(TabButton, Animate);
        end;

        function Tab:HideTab(Animate)
            CancelTabTweens();
            Blocker.BackgroundTransparency = 1;
            TabFrame.Visible = false;
            TabFrame.Position = UDim2.new(0, 0, 0, 0);
            TabCover.Visible = false;

            if Animate then
                PlayTabTween(TabButton, 0.2, { BackgroundColor3 = Color3.fromRGB(150, 150, 150) });
            else
                TabButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150);
            end;
        end;

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position;
            TabListLayout:ApplyLayout();
        end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BackgroundTransparency = 0.15;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 507 + 2);
                ZIndex = 5;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });
            Library:ApplyCorner(BoxOuter, UDim.new(0, 8));

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BackgroundTransparency = 0.25;
                BorderSizePixel = 0;
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 5;
                Parent = BoxOuter;
            });
            Library:ApplyCorner(BoxInner, UDim.new(0, 8));

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(1, 1, 1);
                BorderSizePixel = 0;
                Position = UDim2.new(0, 8, 0, 0);
                Size = UDim2.new(1, -16, 0, 2);
                ZIndex = 5;
                Parent = BoxInner;
            });
            Library:ApplyCorner(Highlight, UDim.new(1, 0));
            Library:ApplyAccentGradient(Highlight, 'Line');

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18);
                Position = UDim2.new(0, 4, 0, 2);
                TextSize = 14;
                Text = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = BoxInner;
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, -4, 1, -20);
                ZIndex = 1;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            });

            Library:ApplyInnerGlow(BoxOuter, 8, 5);
            Library:RegisterPanel(BoxOuter);
            Library:RegisterPanel(BoxInner);

            function Groupbox:Resize()
                local Size = 0;

                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;

                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
            end;

            Groupbox.Container = Container;
            setmetatable(Groupbox, BaseGroupbox);

            Groupbox:AddBlank(3);
            Groupbox:Resize();

            Tab.Groupboxes[Info.Name] = Groupbox;

            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name; });
        end;

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2; Name = Name; });
        end;

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            };

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 10;
                Parent = BoxInner;
            });
            Library:ApplyAccentGradient(Highlight, 'Line');

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 1);
                Size = UDim2.new(1, 0, 0, 18);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });

            Library:ApplyInnerGlow(BoxOuter, 0, 5);
            Library:RegisterPanel(BoxOuter);
            Library:RegisterPanel(BoxInner);

            function Tabbox:AddTab(Name)
                local Tab = {};

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Color3.new(0, 0, 0);
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0);
                    TextSize = 14;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 7;
                    Parent = Button;
                });

                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor;
                    BorderSizePixel = 0;
                    Position = UDim2.new(0, 0, 1, 0);
                    Size = UDim2.new(1, 0, 0, 1);
                    Visible = false;
                    ZIndex = 9;
                    Parent = Button;
                });

                Library:AddToRegistry(Block, {
                    BackgroundColor3 = 'BackgroundColor';
                });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4, 0, 20);
                    Size = UDim2.new(1, -4, 1, -20);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxInner;
                });

                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                });

                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do
                        Tab:Hide();
                    end;

                    Container.Visible = true;
                    Block.Visible = true;

                    Button.BackgroundColor3 = Library.BackgroundColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';

                    Tab:Resize();
                end;

                function Tab:Hide()
                    Container.Visible = false;
                    Block.Visible = false;

                    Button.BackgroundColor3 = Library.MainColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
                end;

                function Tab:Resize()
                    local TabCount = 0;

                    for _, Tab in next, Tabbox.Tabs do
                        TabCount = TabCount + 1;
                    end;

                    for _, Button in next, TabboxButtons:GetChildren() do
                        if not Button:IsA('UIListLayout') then
                            Button.Size = UDim2.new(1 / TabCount, 0, 1, 0);
                        end;
                    end;

                    if (not Container.Visible) then
                        return;
                    end;

                    local Size = 0;

                    for _, Element in next, Tab.Container:GetChildren() do
                        if (not Element:IsA('UIListLayout')) and Element.Visible then
                            Size = Size + Element.Size.Y.Offset;
                        end;
                    end;

                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
                end;

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tabbox.Tabs[Name] = Tab;

                setmetatable(Tab, BaseGroupbox);

                Tab:AddBlank(3);
                Tab:Resize();

                if #TabboxButtons:GetChildren() == 2 then
                    Tab:Show();
                end;

                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;

            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; });
        end;

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2; });
        end;

        -- keep the underline in place when layout / window position changes
        local function SyncIndicator()
            if Window.ActiveTab == Tab then
                Window:UpdateTabIndicator(TabButton, false);
            end;
        end;
        TabButton:GetPropertyChangedSignal('AbsolutePosition'):Connect(SyncIndicator);
        TabButton:GetPropertyChangedSignal('AbsoluteSize'):Connect(SyncIndicator);

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Tab:ShowTab();
            end;
        end);

        if #TabContainer:GetChildren() == 1 then
            Tab:ShowTab();
        end;

        Window.Tabs[Name] = Tab;
        return Tab;
    end;

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = true;
        Text = '';
        Modal = false;
        Parent = ScreenGui;
    });

    local TransparencyCache = {};
    local Toggled = false;
    local Fading = false;

    function Library:Toggle()
        if Fading then
            return;
        end;

        local FadeTime = Config.MenuFadeTime;
        Fading = true;
        Toggled = (not Toggled);
        ModalElement.Modal = Toggled;

        if Toggled then
            Outer.Visible = true;

            task.spawn(function()
                local State = InputService.MouseIconEnabled;

                local Cursor = Drawing.new('Triangle');
                Cursor.Thickness = 1;
                Cursor.Filled = true;
                Cursor.Visible = true;

                local CursorOutline = Drawing.new('Triangle');
                CursorOutline.Thickness = 1;
                CursorOutline.Filled = false;
                CursorOutline.Color = Color3.new(0, 0, 0);
                CursorOutline.Visible = true;

                while Toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false;

                    local mPos = InputService:GetMouseLocation();

                    Cursor.Color = Library.AccentColor;

                    Cursor.PointA = Vector2.new(mPos.X, mPos.Y);
                    Cursor.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6);
                    Cursor.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16);

                    CursorOutline.PointA = Cursor.PointA;
                    CursorOutline.PointB = Cursor.PointB;
                    CursorOutline.PointC = Cursor.PointC;

                    RenderStepped:Wait();
                end;

                InputService.MouseIconEnabled = State;

                Cursor:Remove();
                CursorOutline:Remove();
            end);
        end;

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {};

            if Desc:GetAttribute('CentWuiNoFade') then
                -- animated helper objects (tab fade cover): never cache / fade them
            elseif Desc:IsA('ImageLabel') then
                local IsDecal = (Desc.Parent == DecalLayer) or Desc:GetAttribute('CentWuiDecal');
                if not IsDecal then
                    table.insert(Properties, 'ImageTransparency');
                    table.insert(Properties, 'BackgroundTransparency');
                end;
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then
                table.insert(Properties, 'TextTransparency');
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('UIStroke') and not Desc:GetAttribute('CentWuiHover') then
                table.insert(Properties, 'Transparency');
            end;

            local Cache = TransparencyCache[Desc];

            if (not Cache) then
                Cache = {};
                TransparencyCache[Desc] = Cache;
            end;

            for _, Prop in next, Properties do
                if not Cache[Prop] then
                    Cache[Prop] = Desc[Prop];
                end;

                if Prop == 'BackgroundTransparency' and Library.PanelBase[Desc] then
                    Cache[Prop] = Library:GetPanelTransparency(Desc); -- follows SetBackgroundTransparency
                end;

                if Prop == 'Transparency' and Library.GlowStrokes[Desc] then
                    Cache[Prop] = Library:GetGlowTransparency(Desc); -- follows SetGlowIntensity
                end;

                if Cache[Prop] == 1 then
                    continue;
                end;

                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), { [Prop] = Toggled and Cache[Prop] or 1 }):Play();
            end;
        end;

        task.wait(FadeTime);

        Outer.Visible = Toggled;

        Fading = false;
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer;

    return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();

    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end;
    end;
end;

Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

getgenv().Library = Library
return Library
