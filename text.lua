local TEXT = {
    ["Language"] = "简体中文",
    ["list"] = {
        [1] = "English",
        [2] = "简体中文",
    },
    ["Font"] = {
        ["English"] = "assets/Font/Quicksand-Bold.ttf",
        ["简体中文"] = "assets/Font/SourceHanSansSC-Bold.otf",
    },

    ["English"] = {},
    ["简体中文"] = {},
}

TEXT["English"].IN_GAME_MENU = {
    ["TIP1"] = "[C-confirm]",
    ["TIP2"] = "[UP-rollup]",
    ["TIP3"] = "[DOWN-rolldown]",

    ["PAUSED"] = "PAUSED", ["Resume"] = "Resume",
    ["Retry"] = "Retry", ["Options"] = "Options",
    ["Restar"] = "Restar",["Back to select"] = "Back to Main Menu",

    ["OPTIONS"] = "OPTIONS",["Language"] = "Language",["Back"] = "Back"
}
TEXT["English"].FirstJoin = {
    [1] = "ATTENTION",
    [2] = "This is a fan-made project inspired by the game Celeste,",
    [3] = "developed by Maddy Makes Games.",
    [4] = "This game is non-commercial and made solely for educational and personal purposes.",
    [5] = "All rights to the original Celeste game, its characters, assets, and trademarks",
    [6] = "belong to their respective owners.",
    [7] = "If you enjoy this project, please consider supporting the official release.",
    [8] = "official link: https://www.celestegame.com/"
}
TEXT["English"].OUT_GAME_MENU = {
    ["TIP1"] = "[C-confirm]",
    ["TIP2"] = "[LEFT-rollleft]",
    ["TIP3"] = "[RIGHT-rollright]",

    ["MAIN MENU"] = "MAIN MENU",
    ["Start"] = "Start",
    ["Options"] = "Options",
    ["Quit"] = "Quit",

    ["MAP CHOOSE"] = "MAP CHOOSE"
}

TEXT["简体中文"].IN_GAME_MENU = {
    ["TIP1"] = "[C-确认]",
    ["TIP2"] = "[UP-上滚]",
    ["TIP3"] = "[DOWN-下滚]",

    ["PAUSED"] = "暂停游戏", ["Resume"] = "继续游戏",
    ["Retry"] = "重试", ["Options"] = "选项",
    ["Restar"] = "从头开始",["Back to select"] = "回到主界面",

    ["OPTIONS"] = "选项",["Language"] = "语言",["Back"] = "返回"
}
TEXT["简体中文"].FirstJoin = {
    [1] = "声明",
    [2] = "这是一个由 Celeste（蔚蓝）启发的粉丝项目，",
    [3] = "原作由 Maddy Makes Games 开发。",
    [4] = "本项目完全免费，仅用于学习交流与个人用途，",
    [5] = "不用于任何商业目的。",
    [6] = "原作 Celeste 的所有角色、素材和版权均归其原作者所有。",
    [7] = "如果你喜欢本项目，欢迎支持正版 Celeste。",
    [8] = "官方网站: https://www.celestegame.com/"
}
TEXT["简体中文"].OUT_GAME_MENU = {
    ["TIP1"] = "[C-确认]",
    ["TIP2"] = "[LEFT-左滚]",
    ["TIP3"] = "[RIGHT-右滚]",

    ["MAIN MENU"] = "主菜单",
    ["Start"] = "开始游戏",
    ["Options"] = "选项",
    ["Quit"] = "退出",

    ["MAP CHOOSE"] = "选择地图"
}

return TEXT