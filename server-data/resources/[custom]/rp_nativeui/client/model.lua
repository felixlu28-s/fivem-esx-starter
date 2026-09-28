NativeMenu = {}
local N = NativeMenu
function N.copy(v)
    if type(v) ~= 'table' then return v end
    local result = {} for k, value in pairs(v) do result[k] = N.copy(value) end return result
end
local function text(v, max) return type(v) == 'string' and #v <= max end
function N.integer(v, low, high) return type(v) == 'number' and v == v and v % 1 == 0 and v >= low and v <= high end
function N.callable(v) return type(v) == 'function' or (type(v) == 'table' and v.__cfx_functionReference ~= nil) end
local function key(v) return text(v, 80) and v:match('^[%w_-]+$') end
function N.definition(value, owner)
    if type(value) == 'table' then
        if (value.subtitle ~= nil and type(value.subtitle) ~= 'string')
            or (value.description ~= nil and type(value.description) ~= 'string')
            or (value.visibleRows ~= nil and type(value.visibleRows) ~= 'number') then return nil, 'invalid_menu' end
    end
    if type(value) ~= 'table' or not text(value.title, 100) or not text(value.subtitle or 'INTERAKTIONSMENÜ', 120)
        or not text(value.description or '', 600) or type(value.items) ~= 'table' or #value.items > 200
        or not N.integer(value.visibleRows or 7, 3, 12) or (value.theme ~= nil and value.theme ~= 'mint') then
        return nil, 'invalid_menu'
    end
    local result = { title = value.title, subtitle = value.subtitle or 'INTERAKTIONSMENÜ', description = value.description or '',
        visibleRows = value.visibleRows or 7, theme = 'mint', items = {} }
    local seen = {}
    for i = 1, #value.items do if value.items[i] == nil then return nil, 'invalid_item' end end
    for index, item in pairs(value.items) do
        if not N.integer(index, 1, #value.items) or type(item) ~= 'table' or not key(item.id) or seen[item.id]
            or not text(item.label, 180) or not text(item.description or '', 600) or not text(item.rightLabel or '', 100)
            or (item.disabled ~= nil and type(item.disabled) ~= 'boolean') then return nil, 'invalid_item' end
        seen[item.id] = true
        if (item.description ~= nil and type(item.description) ~= 'string')
            or (item.rightLabel ~= nil and type(item.rightLabel) ~= 'string')
            or (item.type ~= nil and type(item.type) ~= 'string') then return nil, 'invalid_item' end
        local kind = item.type or 'action'
        if not ({ action = true, list = true, checkbox = true, submenu = true })[kind] then return nil, 'invalid_item' end
        local row = { id = item.id, label = item.label, description = item.description or '', rightLabel = item.rightLabel or '',
            type = kind, disabled = item.disabled == true }
        if item.hint~=nil then
            local hint=item.hint
            if type(hint)~='table' or not text(hint.label,100) or #hint.label==0
                or not text(hint.detail or '',120) or type(hint.keys)~='table' or #hint.keys<1 or #hint.keys>4 then return nil,'invalid_hint' end
            local keys={}
            for i=1,#hint.keys do
                if not text(hint.keys[i],8) or #hint.keys[i]==0 then return nil,'invalid_hint' end
                keys[i]=hint.keys[i]
            end
            row.hint={keys=keys,label=hint.label,detail=hint.detail or ''}
        end
        if kind == 'list' then
            if item.index ~= nil and type(item.index) ~= 'number' then return nil, 'invalid_options' end
            if type(item.options) ~= 'table' or #item.options < 1 or #item.options > 100
                or not N.integer(item.index or 1, 1, #item.options) then return nil, 'invalid_options' end
            row.index, row.options = item.index or 1, {}
            for i = 1, #item.options do if item.options[i] == nil then return nil, 'invalid_options' end end
            for i, option in pairs(item.options) do
                if not N.integer(i, 1, #item.options) or type(option) ~= 'table' or not text(option.label, 120)
                    or not (text(option.value, 180) or N.integer(option.value, -1000000000, 1000000000) or type(option.value) == 'boolean') then
                    return nil, 'invalid_options'
                end
                row.options[i] = { label = option.label, value = option.value }
            end
        elseif kind == 'checkbox' then
            if item.checked ~= nil and type(item.checked) ~= 'boolean' then return nil, 'invalid_checked' end
            row.checked = item.checked == true
        elseif kind == 'submenu' then
            if type(item.menu) ~= 'string' then return nil, 'invalid_submenu' end
            row.menu = item.menu:find('/', 1, true) and item.menu or owner .. '/' .. item.menu
            if row.menu:sub(1, #owner + 1) ~= owner .. '/' or not key(row.menu:sub(#owner + 2)) then return nil, 'foreign_menu' end
        end
        result.items[index] = row
    end
    return result
end
