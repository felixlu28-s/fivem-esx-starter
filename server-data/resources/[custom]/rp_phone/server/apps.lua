local S,C=PhoneService,PhoneConfig
local function reply(kind,data) data=data or {} data.kind=kind return {ok=true,phone=data} end
local function write(ref,sql,params)
    if not S.current(ref) then error('phone_session_changed') end
    return MySQL.update.await(sql,params)
end
local function nonce(d) return S.text(d.nonce,80) and d.nonce:match('^[%w:_%-]+$') end
local function cursor(d) return S.id(d.before) or 9007199254740990 end
S.handlers.home=function(_,row)
    local unread=MySQL.scalar.await('SELECT COUNT(*) FROM rp_phone_messages WHERE recipient=? AND seen=0',{row.id})
    return reply('home',{profile=S.public(row),unread=unread or 0,sites=C.sites})
end
S.handlers.contact=function(ref,row,d)
    local entries=json.decode(row.contacts)
    if not S.text(d.id,80) then return end
    local index
    for i,v in ipairs(entries) do if v.id==d.id then index=i break end end
    if d.delete==true then if index then table.remove(entries,index) end
    else
        if not S.text(d.name,60) or not S.numberId(d.number) then return end
        if not index and #entries>=C.contacts then return {ok=false,error='limit'} end
        entries[index or #entries+1]={id=d.id,name=d.name,number=d.number}
    end
    write(ref,'UPDATE rp_phone_profiles SET contacts=? WHERE id=?',{json.encode(entries),row.id})
    row.contacts=json.encode(entries)
    return reply('home',{profile=S.public(row)})
end
S.handlers.task=function(ref,row,d)
    local entries=json.decode(row.tasks)
    if not S.text(d.id,80) then return end
    local index
    for i,v in ipairs(entries) do if v.id==d.id then index=i break end end
    if d.delete==true then if index then table.remove(entries,index) end
    else
        if not S.text(d.title,120) or type(d.done)~='boolean' then return end
        if not index and #entries>=C.tasks then return {ok=false,error='limit'} end
        entries[index or #entries+1]={id=d.id,title=d.title,done=d.done}
    end
    write(ref,'UPDATE rp_phone_profiles SET tasks=? WHERE id=?',{json.encode(entries),row.id})
    row.tasks=json.encode(entries)
    return reply('home',{profile=S.public(row)})
end
S.handlers.bookmark=function(ref,row,d)
    local allowed=false for _,site in ipairs(C.sites) do if site.id==d.id then allowed=true break end end
    if not allowed then return end
    local bookmarks=json.decode(row.bookmarks)
    local found=false for i,v in ipairs(bookmarks) do if v==d.id then table.remove(bookmarks,i) found=true break end end
    if not found then bookmarks[#bookmarks+1]=d.id end
    write(ref,'UPDATE rp_phone_profiles SET bookmarks=? WHERE id=?',{json.encode(bookmarks),row.id})
    row.bookmarks=json.encode(bookmarks)
    return reply('home',{profile=S.public(row)})
end
-- One summary per peer, not the last 30 individual messages. Apply the cursor
-- after grouping so an active conversation cannot reappear on every page.
S.handlers.conversations=function(_,row,d)
    local rows=MySQL.query.await([[SELECT m.id,m.body,m.created,m.sender,m.seen,t.peer,t.unread
        FROM (SELECT peer,MAX(last_id) AS last_id,CAST(SUM(unread) AS UNSIGNED) AS unread FROM (
            SELECT recipient AS peer,MAX(id) AS last_id,0 AS unread FROM rp_phone_messages WHERE sender=? GROUP BY recipient
            UNION ALL
            SELECT sender AS peer,MAX(id) AS last_id,SUM(seen=0) AS unread FROM rp_phone_messages WHERE recipient=? GROUP BY sender
        ) own_messages GROUP BY peer HAVING MAX(last_id)<? ORDER BY last_id DESC LIMIT 30) t
        JOIN rp_phone_messages m ON m.id=t.last_id ORDER BY m.id DESC]],{row.id,row.id,cursor(d)})
    for _,m in ipairs(rows) do
        m.id=tonumber(m.id) m.unread=tonumber(m.unread) or 0
        m.mine=m.sender==row.id m.number=S.number(m.peer)
        m.sender,m.peer=nil,nil m.seen=m.seen==1 or m.seen==true
    end
    return reply('conversations',{rows=rows,more=#rows==30})
end
S.handlers.messages=function(_,row,d)
    local peer=S.numberId(d.number)
    local rows
    if peer then
        rows=MySQL.query.await([[SELECT id,sender,recipient,body,created,seen FROM rp_phone_messages
            WHERE id<? AND ((sender=? AND recipient=?) OR (sender=? AND recipient=?)) ORDER BY id DESC LIMIT 30]],
            {cursor(d),row.id,peer,peer,row.id})
    else
        rows=MySQL.query.await([[SELECT id,sender,recipient,body,created,seen FROM rp_phone_messages
            WHERE (sender=? OR recipient=?) AND id<? ORDER BY id DESC LIMIT 30]],{row.id,row.id,cursor(d)})
    end
    for _,m in ipairs(rows) do
        m.id=tonumber(m.id) m.mine=m.sender==row.id m.number=S.number(m.mine and m.recipient or m.sender)
        m.sender,m.recipient=nil,nil m.seen=m.seen==1 or m.seen==true
    end
    return reply('messages',{rows=rows,number=d.number or '',more=#rows==30})
end
S.handlers.read=function(ref,row,d)
    local peer=S.numberId(d.number)
    if not peer or not S.id(d.last) then return end
    write(ref,'UPDATE rp_phone_messages SET seen=1 WHERE recipient=? AND sender=? AND id<=?',{row.id,peer,d.last})
    return {ok=true}
end
S.handlers.send=function(ref,row,d)
    local peer=S.numberId(d.number)
    if not peer or peer==row.id or not S.text(d.body,1000) or not nonce(d) then return end
    if not S.rate(ref.source,'send',800) then return {ok=false,error='rate_limited'} end
    local target=MySQL.scalar.await('SELECT id FROM rp_phone_profiles WHERE id=?',{peer})
    if not target then return {ok=false,error='unknown_number'} end
    local changed=write(ref,[[INSERT IGNORE INTO rp_phone_messages (sender,recipient,nonce,body,created) VALUES (?,?,?,?,?)]],{row.id,peer,d.nonce,d.body,os.time()})
    local original=MySQL.single.await('SELECT recipient,body FROM rp_phone_messages WHERE sender=? AND nonce=?',{row.id,d.nonce})
    if not original or original.recipient~=peer or original.body~=d.body then return {ok=false,error='conflict'} end
    if changed>0 then S.notify(peer,'message') end
    return {ok=true}
end
S.handlers.photos=function(_,row)
    return {ok=false,error='local_gallery'}
end
S.handlers.photo=function(ref,row,d)
    return {ok=false,error='local_gallery'}
end
S.handlers.history=function(_,row)
    return reply('history',{rows=MySQL.query.await('SELECT id,peer,direction,video,outcome,created FROM rp_phone_call_history WHERE profile=? ORDER BY id DESC LIMIT 30',{row.id})})
end
