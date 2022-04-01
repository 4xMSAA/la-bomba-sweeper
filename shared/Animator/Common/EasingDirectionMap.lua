local Styles = require(shared.Common.Styles)

return {
    In = function(...)
        return ...
    end,

    Out = function(...)
        return Styles.out(...)
    end,

    InOut = function(f0)
        return Styles.chain(f0, Styles.out(f0))
    end,

    OutIn = function(f0)
        return Styles.chain(Styles.out(f0), f0)
    end

}