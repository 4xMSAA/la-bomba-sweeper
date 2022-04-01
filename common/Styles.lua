-- Robert Penner's equations for easing in Lua

local Styles = {
  out = function(f) -- 'rotates' a function
    return function(s, ...) return 1 - f(1-s, ...) end
  end,
  chain = function(f1, f2) -- concatenates two functions
    return function(s, ...) return (s < 0.5 and f1(2*s, ...) or 1 + f2(2*s-1, ...)) * 0.5 end
  end,


  -- useful tweening functions
  linear = function(s) return s end,
  constant = function(s) return s >= 1 and 1 or 0 end,
  quad   = function(s) return s*s end,
  cubic  = function(s) return s*s*s end,
  quart  = function(s) return s*s*s*s end,
  quint  = function(s) return s*s*s*s*s end,
  sine   = function(s) return 1-math.cos(s*math.pi/2) end,
  expo   = function(s) return 2^(10*(s-1)) end,
  circ   = function(s) return 1 - math.sqrt(1-s*s) end,

  back = function(s,bounciness)
    bounciness = bounciness or 1.70158
    return s*s*((bounciness+1)*s - bounciness)
  end,

  bounce = function(s) -- magic numbers ahead
    local a,b = 7.5625, 1/2.75
    return math.min(a*s^2, a*(s-1.5*b)^2 + 0.75, a*(s-2.25*b)^2 + 0.9375, a*(s-2.625*b)^2 + 0.984375)
  end,

  elastic = function(s, amp, period)
    amp, period = amp and math.max(1, amp) or 1, period or .3
    return (-amp * math.sin(2*math.pi/period * (s-1) - math.asin(1/amp))) * 2^(10*(s-1))
  end
}

return Styles;
