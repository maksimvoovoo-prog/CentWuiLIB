
# CentWuiLib
A cooler LinoriaLib fork — purple base, pixel (`Code`) font, rounded corners, glow accents,
per-corner window decals, directional background gradients, and full-window background art
rendered **behind all options** (content panels are translucent).

Live repo: https://github.com/maksimvoovoo-prog/CentWuiLIB/tree/main/CentWuiLIB-main
```lua
local repo = 'https://raw.githubusercontent.com/maksimvoovoo-prog/CentWuiLIB/main/CentWuiLIB-main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
```

Based on LinoriaLib by Inori / Wally / Stefanuk. Drop-in compatible: `CreateWindow`, tabs,
groupboxes, toggles, sliders, dropdowns, color pickers, keybinds, ThemeManager & SaveManager
all work the same.

###### Example Script:
* [Example](Example.lua)

###### Interface Addons:
* [Theme Manager](addons/ThemeManager.lua)&nbsp;&nbsp;|&nbsp;&nbsp;[Save Manager](addons/SaveManager.lua)

## What's cooler vs Linoria
- Purple base palette (`#1a0c36` / `#2e1856`, accent `#a86eff`)
- Pixel-style `Code` font everywhere
- Background gradient + background decal rendered **behind all options**
- Rounded window, groupboxes, tabs, tooltips, notifications, watermark & keybind list
- Thin gradient accent bars under the title + on groupboxes
- Subtle violet glow stroke around the window
- **Corner decals**: put a different image on any window corner just with its ID

## Corner decals
Corners: `'TopLeft'` | `'TopRight'` | `'BottomLeft'` | `'BottomRight'` (or `'TL'/'TR'/'BL'/'BR'`).

```lua
local repo = 'https://raw.githubusercontent.com/YOUR_USER/CentWuiLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()

local Window = Library:CreateWindow({
    Title = 'CentWui',
    Center = true,
    AutoShow = true,
    -- Option 1: declare at creation
    CornerDecals = {
        TopRight = 12345678, -- plain asset ID
        BottomLeft = { Asset = 87654321, Transparency = 0.15, Size = 56 },
    },
})

-- Option 2: any time after creation
Window:SetCornerDecal('TopRight', 12345678, 0.1, 56) -- (corner, id, transparency 0..1, size px)
Window:SetCornerDecal('BottomRight', 'rbxassetid://12345678', 0.25, 64)

-- Tweak live:
Window:SetCornerTransparency('TopRight', 0.3)
Window:SetCornerSize('TopRight', 72)

-- Clear:
Window:ClearCorner('TopRight')
Window:ClearAllCorners()
```

Notes:
- `AssetId` accepts `12345678`, `"12345678"`, or `"rbxassetid://12345678"`. Pass `nil`/`""` to clear.
- `Transparency` is `ImageTransparency` (`0` = opaque, `1` = invisible).
- `Size` is square pixels, clamped `16..256` (default `48`).
- Decals live in a click-through layer above the window chrome (`Window.DecalLayer`).
- Saved per-window in `Window.CornerDecalConfig`.

## Background gradient (Sideways / Downways)
```lua
local Window = Library:CreateWindow({
    Title = 'CentWui',
    BackgroundGradient = 'Sideways', -- 'Sideways' (left->right) or 'Downways' (top->bottom), 0-360, true, false
    BackgroundGradientColors = { Color3.fromRGB(32, 22, 68), Color3.fromRGB(10, 10, 18) }, -- optional custom stops
})

Window:SetBackgroundGradient('Downways')
Window:SetBackgroundGradientDirection('Sideways')
Window:SetBackgroundGradientColors(Color3.fromRGB(30, 20, 60), Color3.fromRGB(10, 10, 18))
Window:SetBackgroundGradient(false) -- remove
```

## Background decals (full-window art + transparency)
```lua
local Window = Library:CreateWindow({
    Title = 'CentWui',
    BackgroundDecal = 11223344, -- or { Asset = 11223344, Transparency = 0.85 }
    BackgroundTransparency = 0.85,
})

Window:SetBackgroundDecal(11223344, 0.85) -- (assetId, transparency 0..1, optional tint Color3)
Window:SetBackgroundTransparency(0.5)
Window:ClearBackgroundDecal()
```
Notes:
- Background art fills the window (`ScaleType = Crop`) behind the content.
- Keep transparency high (like `0.8-0.9`) so text stays readable.
- Use dark / subtle images — bright art will wash out the UI.

## Features (inherited from Linoria)
- Tabs, group boxes, and tab boxes
- Almost any UI element you would ever need (toggles, sliders, dropdowns, etc)
- Interface automatically becomes scrollable whenever there are too many UI elements
- Dependency boxes, allowing you to easily hide/show UI elements depending on the state of other UI elements

## Contributors
- Inori: Main developer of LinoriaLib.
- Wally: Cleaning up verbose code, extending library functionality.
- Stefanuk: Extending library functionality.
- matas3535: Creator of Splix.
- CentWuiLib: cooler theme + corner-decal system.
