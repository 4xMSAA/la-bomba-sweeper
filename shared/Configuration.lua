return {
    LOG_LEVEL = 1,
    
    LOADING = {
        TIMEOUT = 30
    },
    
    CAMERA = {
        LIMIT_YAW = 90,
        
        SENSITIVITY = {
            X = 1/8,
            Y = 1/8
        },
        
        ZOOM = {
            PERCENTAGE = 10/100,
            MAX_SCROLLS = 4
        }
    },
    
    TIMERS = {
        CURSOR_UPDATE = 1/10
    },
    
    BOARD = {
        RENDER = {
            Pivot = Vector3.new(0, 0, 0),

            Size = Vector3.new(2, 1, 2),

            PartColor = {
                Primary = Color3.fromRGB(77, 153, 0),
                Secondary = Color3.fromRGB(105, 153, 57),
                DiscoveredZero = Color3.fromRGB(255, 238, 153),
                DiscoveredNearby = Color3.fromRGB(170, 167, 100),
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
                [9] = Color3.fromRGB(255, 255, 255), --how
            }
        },
        GENERATION = {
            Size = Vector2.new(25, 25),
            MinePercentage = 16,
        }
    },
    
    FLAGGING = {
        FLAG_PLACED_OTHER_COOLDOWN = 2/3
    }
}
