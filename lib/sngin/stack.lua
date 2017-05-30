Stack = {}

Stack.new = function()
  local t = {}
  
  local last = 0
  
  t.isEmpty = function()
    return last == 0
  end
  
  t.size = function()
    return last
  end
  
  t.push = function(value)
    t[last] = value
    last = last + 1
  end
  
  t.pop = function()
    local v = t[last - 1]
    last = last - 1
    return v
  end
  
  t.peek = function()
    return t[last - 1]
  end
  
  return t
end
