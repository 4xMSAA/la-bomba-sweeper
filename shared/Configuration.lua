return {
    LOG_LEVEL = 2,
    
    LOADING = {
        TIMEOUT = 30
    },
    
    CAMERA = {
        LIMIT_YAW = 360,
        
        SENSITIVITY = {
            X = 1/8,
            Y = 1/8
        },
        
        ZOOM = {
            PERCENTAGE = 10/100,
            MAX_SCROLLS = 6
        }
    },
    
    BADGES = {
        WELCOME = 2142864902,
        ONE_VICTORY = 2142865774
    },
    
    TIMERS = {
        CURSOR_UPDATE = 0.04
    },
    
    UI = {
        COLOR_SCHEME = {
            TRUE = Color3.fromRGB(65, 170, 0),
            FALSE = Color3.fromRGB(200, 100, 100)
        }
    },
    
    CONTROLS = {
        KEYBOARD = {
            REPEAT_RATE = 100,
            REPEAT_DELAY = 300
        }
    },
    
    BOARD = {
        RENDER = {
            Pivot = Vector3.new(0, 0, 0),

            Size = Vector3.new(2, 1, 2),


            PartColor = {
                Primary = Color3.fromRGB(77, 153, 0),
                Secondary = Color3.fromRGB(125, 183, 37),
                DiscoveredZero = Color3.fromRGB(255, 238, 153),
                DiscoveredNearby = Color3.fromRGB(200, 190, 120),
                Mine = Color3.fromRGB(0, 0, 0),
                MineClicked = Color3.fromRGB(255, 0, 0)
            },
            TextColor = {
                [1] = Color3.fromRGB(0, 0, 255),
                [2] = Color3.fromRGB(0, 170, 0),
                [3] = Color3.fromRGB(255, 0, 0),
                [4] = Color3.fromRGB(85, 0, 127),
                [5] = Color3.fromRGB(150, 0, 150),
                [6] = Color3.fromRGB(85, 255, 255),
                [7] = Color3.fromRGB(200, 200, 0),
                [8] = Color3.fromRGB(255, 170, 0),
            },

            FLAG_COLOR = Color3.fromRGB(196, 40, 28),
            SELECTION_HIGHLIGHT_COLOR = Color3.fromRGB(20, 20, 255)
        },
        GENERATION = {
            Size = Vector2.new(25, 25),
            MinePercentage = 16,
            FreeZeroStart = true,
            RandomStartRadius = 5
        }
    },
    
    FLAGGING = {
        FLAG_PLACED_OTHER_COOLDOWN = 2/3
    },
    
    MESSAGES = {
        FAIL_COLOR = Color3.fromRGB(255, 120, 120),
        FAIL = {
            "%name% didn't sweep hard enough",
            "%name% did a little mischief",
            "%name% blew up",
            "%name% picked up a mine",
            "%name% found a mine",
            "%name% bit the bullet",
            "%name% frew up",
            "%name% threw",
            "%name% is covered in shrapnel",
            "%name% touched la bomba",
            "%name% loves la bomba",
            "%name% adores la bomba",
            "%name% hugged la bomba",
            "%name% values la bomba",
            "%name% did a \"minor\" miscalculation",
            "%name% has a trigger finger",
            "%name% got a little quirky"
        },
        
        VICTORY_COLOR = Color3.fromRGB(120, 255, 120),
        VICTORY = {
            "Congratulations",
            "Field cleared, over",
            "Breach and clear",
            "No accidents today, huh?",
            "All in the numbers, baby",
            "You actually did it?",
            "Victory",
            "GG NO RE",
            "It's all safe now",
            "Several breakdowns later",
            "The job never ends"
        }
    }
}
