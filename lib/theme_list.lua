local theme_list = {}

-- Default KOReader themes
theme_list.DEFAULT_DAY_THEME = { key = "default_day", label = "Default Day", bg = "#FFFFFF", fg = "#000000", link = nil, night = false }
theme_list.DEFAULT_NIGHT_THEME = { key = "default_night", label = "Default Night", bg = "#000000", fg = "#FFFFFF", link = nil, night = true }

-- Default themes list
theme_list.DEFAULT_DAY_THEMES = {
    theme_list.DEFAULT_DAY_THEME,
    -- Neutral
    { key = "paper",            label = "Paper",            bg = "#F2F2F2", fg = "#1A1A1A", night = false },
    { key = "light_gray",       label = "Light Gray",       bg = "#EDEDED", fg = "#4F4F4F", night = false },
    { key = "warm_stone",       label = "Warm Stone",       bg = "#D7D5D3", fg = "#000000", night = false },
    { key = "book_white",       label = "Book White",       bg = "#F9F6F0", fg = "#1C1C1C", night = false },
    -- Warm/Sepia
    { key = "cream",            label = "Cream",            bg = "#F3EFD8", fg = "#111111", night = false },
    { key = "parchment",        label = "Parchment",        bg = "#EBE0C9", fg = "#2C1A0E", night = false },
    { key = "soft_parchment",   label = "Soft Parchment",   bg = "#EBE0C9", fg = "#645031", night = false },
    { key = "sepia",            label = "Sepia",            bg = "#F5E6C8", fg = "#2C1A0E", night = false },
    { key = "warm_sepia",       label = "Warm Sepia",       bg = "#E3D1B3", fg = "#422A14", night = false },
    { key = "aged_paper",       label = "Aged Paper",       bg = "#F5EDD6", fg = "#2C1A0E", night = false },
    { key = "manila",           label = "Manila",           bg = "#F2E8C8", fg = "#1A0E00", night = false },
    { key = "sand",             label = "Sand",             bg = "#EDE0C4", fg = "#2E1F0A", night = false },
    { key = "light_sepia",      label = "Light Sepia",      bg = "#F7ECD8", fg = "#2C1A0E", night = false },
    { key = "warm_parchment",   label = "Warm Parchment",   bg = "#F0E2C8", fg = "#3D2010", night = false },
    { key = "old_book",         label = "Old Book",         bg = "#EDD9B0", fg = "#2E1800", night = false },
    { key = "butterscotch",     label = "Butterscotch",     bg = "#F5DFA0", fg = "#3D2000", night = false },
    { key = "tan",              label = "Tan",              bg = "#E8D5B0", fg = "#2A1500", night = false },
    { key = "caramel",          label = "Caramel",          bg = "#E8C888", fg = "#2A1000", night = false },
    -- Warm tinted
    { key = "rose_tint",        label = "Rose Tint",        bg = "#FAF0F0", fg = "#2A1A1A", night = false },
    { key = "dyslexia",         label = "Dyslexia",         bg = "#F8F0D8", fg = "#3D2B1F", night = false },
    { key = "solarized_light",  label = "Solarized Light",  bg = "#FDF6E3", fg = "#657B83", night = false },
    -- Green
    { key = "green_tea",        label = "Green Tea",        bg = "#D4E8D0", fg = "#1A3320", night = false },
    { key = "sage",             label = "Sage",             bg = "#EAF0E8", fg = "#1A2E1A", night = false },
    { key = "mint",             label = "Mint",             bg = "#E8F5F0", fg = "#0A2E1E", night = false },
    { key = "pale_moss",        label = "Pale Moss",        bg = "#EAF2E0", fg = "#1A2E0A", night = false },
    { key = "fern",             label = "Fern",             bg = "#DFF0E0", fg = "#0F2A14", night = false },
    { key = "soft_green",       label = "Soft Green",       bg = "#E4EEE0", fg = "#1A3020", night = false },
    -- Blue
    { key = "arctic",           label = "Arctic",           bg = "#E8F0F8", fg = "#0D1B2A", night = false },
    { key = "cool_mist",        label = "Cool Mist",        bg = "#EBEFF5", fg = "#052F75", night = false },
    { key = "sky",              label = "Sky",              bg = "#E8F4FC", fg = "#0A2040", night = false },
    { key = "ice_blue",         label = "Ice Blue",         bg = "#EAF2FA", fg = "#0D2840", night = false },
    { key = "pale_blue",        label = "Pale Blue",        bg = "#EEF4FF", fg = "#0A1E3C", night = false },
    { key = "powder_blue",      label = "Powder Blue",      bg = "#E8F0F8", fg = "#1A3050", night = false },
    { key = "blue_fields",      label = "Blue Fields",      bg = "#CBFCFF", fg = "#373598", night = false },
    -- Purple
    { key = "lavender_mist",    label = "Lavender Mist",    bg = "#F0EEF8", fg = "#2A2040", night = false },
    -- Programming themes
    { key = "github_light",     label = "GitHub Light",     bg = "#FFFFFF", fg = "#24292F", night = false },
    { key = "one_light",        label = "One Light",        bg = "#FAFAFA", fg = "#383A42", night = false },
    { key = "tomorrow",         label = "Tomorrow",         bg = "#FFFFFF", fg = "#4D4D4C", night = false },
    { key = "gruvbox_light",    label = "Gruvbox Light",    bg = "#FBF1C7", fg = "#3C3836", night = false },
    { key = "catppuccin_latte", label = "Catppuccin Latte", bg = "#EFF1F5", fg = "#4C4F69", night = false },
    { key = "rose_pine_dawn",   label = "Rosé Pine Dawn",   bg = "#FAF4ED", fg = "#575279", night = false },
}

theme_list.DEFAULT_NIGHT_THEMES = {
    theme_list.DEFAULT_NIGHT_THEME,
    -- Dark neutrals
    { key = "ink",              label = "Ink",              bg = "#050505", fg = "#E0E0E0", night = true },
    { key = "mono_dark",        label = "Mono Dark",        bg = "#1A1A1A", fg = "#F5F5F5", night = true },
    { key = "twilight",         label = "Twilight",         bg = "#282A2C", fg = "#FFFFFF", night = true },
    { key = "dim_night",        label = "Dim Night",        bg = "#121212", fg = "#B0B0B0", night = true },
    { key = "charcoal",         label = "Charcoal",         bg = "#1E1E1E", fg = "#D4D4D4", night = true },
    -- Warm/Sepia
    { key = "amber_night",      label = "Amber Night",      bg = "#14100A", fg = "#FAD08A", night = true },
    { key = "candlelight",      label = "Candlelight",      bg = "#1A1000", fg = "#E8C87A", night = true },
    { key = "deep_sepia",       label = "Deep Sepia",       bg = "#1A1008", fg = "#C8A87A", night = true },
    { key = "dark_sepia",       label = "Dark Sepia",       bg = "#1A0E00", fg = "#C8A070", night = true },
    { key = "coffee",           label = "Coffee",           bg = "#140C00", fg = "#C8A878", night = true },
    { key = "dark_parchment",   label = "Dark Parchment",   bg = "#1E1408", fg = "#D4B888", night = true },
    { key = "tobacco",          label = "Tobacco",          bg = "#180E04", fg = "#C8A060", night = true },
    { key = "burnt_wood",       label = "Burnt Wood",       bg = "#120800", fg = "#B87840", night = true },
    { key = "dark_caramel",     label = "Dark Caramel",     bg = "#1A0C00", fg = "#D4A050", night = true },
    { key = "warm_dark",        label = "Warm Dark",        bg = "#1A1410", fg = "#D4C4A8", night = true },
    { key = "dim_amber",        label = "Dim Amber",        bg = "#0F0A00", fg = "#D4A84B", night = true },
    -- Green
    { key = "forest_night",     label = "Forest Night",     bg = "#0D1A0D", fg = "#A8C8A0", night = true },
    { key = "dark_moss",        label = "Dark Moss",        bg = "#0A1A0A", fg = "#90C090", night = true },
    { key = "pine",             label = "Pine",             bg = "#0A1810", fg = "#88C0A0", night = true },
    { key = "deep_forest",      label = "Deep Forest",      bg = "#081408", fg = "#80B880", night = true },
    -- Blue/Teal
    { key = "slate",            label = "Slate",            bg = "#2C3E50", fg = "#DCDCDC", night = true },
    { key = "midnight_blue",    label = "Midnight Blue",    bg = "#0D1117", fg = "#A0B4C8", night = true },
    { key = "deep_ocean",       label = "Deep Ocean",       bg = "#0A1628", fg = "#8BAFD4", night = true },
    { key = "dark_sky",         label = "Dark Sky",         bg = "#0A1428", fg = "#7AAAD4", night = true },
    { key = "night_blue",       label = "Night Blue",       bg = "#0D1520", fg = "#90B8D8", night = true },
    { key = "moonlight",        label = "Moonlight",        bg = "#12121E", fg = "#C8C8E0", night = true },
    -- Purple
    { key = "wisteria_night",   label = "Wisteria Night",   bg = "#150D1F", fg = "#E5D1F5", night = true },
    -- Programming themes
    { key = "dracula",          label = "Dracula",          bg = "#282A36", fg = "#F8F8F2", night = true },
    { key = "nord",             label = "Nord",             bg = "#2E3440", fg = "#D8DEE9", night = true },
    { key = "gruvbox_dark",     label = "Gruvbox Dark",     bg = "#282828", fg = "#EBDBB2", night = true },
    { key = "one_dark",         label = "One Dark",         bg = "#282C34", fg = "#ABB2BF", night = true },
    { key = "tokyo_night",      label = "Tokyo Night",      bg = "#1A1B26", fg = "#C0CAF5", night = true },
    { key = "catppuccin_mocha", label = "Catppuccin Mocha", bg = "#1E1E2E", fg = "#CDD6F4", night = true },
    { key = "monokai",          label = "Monokai",          bg = "#272822", fg = "#F8F8F2", night = true },
    { key = "material_dark",    label = "Material Dark",    bg = "#263238", fg = "#EEFFFF", night = true },
    { key = "rose_pine",        label = "Rosé Pine",        bg = "#191724", fg = "#E0DEF4", night = true },
}

return theme_list
