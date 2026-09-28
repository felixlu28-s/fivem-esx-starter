-- Social identities extend the phone domain; the phone/ESX character never changes.
local S,C=PhoneService,PhoneConfig
local function reply(kind,data) data.kind=kind return {ok=true,phone=data} end
local function failure(reason) return {ok=false,error=reason} end
local function write(ref,sql,params)
    if not S.current(ref) then error('phone_session_changed') end
    return MySQL.update.await(sql,params)
end
local function nonce(d) return S.text(d.nonce,80) and d.nonce:match('^[%w:_%-]+$') end
local function cursor(d) return S.id(d.before) or 9007199254740990 end
local function validProfile(d)
    return S.text(d.name,60) and d.name:find('%S') and S.text(d.bio,160,true)
        and S.text(d.handle,24) and #d.handle>=3 and d.handle:match('^[a-z][a-z0-9_.]+$')
end
local function account(ref,row)
    local existing=MySQL.single.await('SELECT slots,active FROM rp_phone_social_accounts WHERE owner=?',{row.id})
    if existing then return existing end
    write(ref,'INSERT IGNORE INTO rp_phone_social_accounts (owner) VALUES (?)',{row.id})
    return MySQL.single.await('SELECT slots,active FROM rp_phone_social_accounts WHERE owner=?',{row.id})
end
local function identity(ref,row,d)
    local a=account(ref,row)
    -- expected actor is a stale-view guard, never an authority to choose an owner.
    if not a or not a.active then return nil,'social_register' end
    if d.actor~=nil and (not S.id(d.actor) or d.actor~=tonumber(a.active)) then return nil,'social_changed' end
    local p=MySQL.single.await('SELECT id,handle,name,bio FROM rp_phone_social_profiles WHERE id=? AND owner=?',{a.active,row.id})
    if not p or not S.current(ref) then return nil,'invalid_state' end
    p.id=tonumber(p.id) return p
end
local function withIdentity(fn)
    return function(ref,row,d)
        local actor,err=identity(ref,row,d)
        if not actor then return failure(err) end
        return fn(ref,row,d,actor)
    end
end
S.handlers.social_home=function(ref,row)
    local a=account(ref,row)
    local profiles=MySQL.query.await('SELECT id,handle,name,bio,slot FROM rp_phone_social_profiles WHERE owner=? ORDER BY slot LIMIT 5',{row.id})
    for _,p in ipairs(profiles) do p.id=tonumber(p.id) end
    return reply('social_home',{profiles=profiles,active=tonumber(a.active) or 0,slots=tonumber(a.slots)})
end
S.handlers.social_create=function(ref,row,d)
    if not validProfile(d) or d.handle:match('^citizen%d+$') or not nonce(d) then return end
    local previous=MySQL.single.await('SELECT handle,name,bio FROM rp_phone_social_profiles WHERE owner=? AND nonce=?',{row.id,d.nonce})
    if previous then
        if previous.handle~=d.handle or previous.name~=d.name or previous.bio~=d.bio then return failure('conflict') end
        return S.handlers.social_home(ref,row)
    end
    local a=account(ref,row)
    local profiles=MySQL.query.await('SELECT id,slot,handle FROM rp_phone_social_profiles WHERE owner=? ORDER BY slot',{row.id})
    for _,p in ipairs(profiles) do if p.handle==d.handle then return failure('handle_taken') end end
    if #profiles>=a.slots then return failure('social_limit') end
    local used={} for _,p in ipairs(profiles) do used[p.slot]=true end
    local slot=1 while used[slot] do slot=slot+1 end
    write(ref,[[INSERT IGNORE INTO rp_phone_social_profiles (owner,slot,handle,name,bio,created,nonce) VALUES (?,?,?,?,?,?,?)]],
        {row.id,slot,d.handle,d.name,d.bio,os.time(),d.nonce})
    local created=MySQL.scalar.await('SELECT id FROM rp_phone_social_profiles WHERE owner=? AND handle=?',{row.id,d.handle})
    if not created then return failure('handle_taken') end
    write(ref,'UPDATE rp_phone_social_accounts SET active=? WHERE owner=?',{created,row.id})
    return S.handlers.social_home(ref,row)
end
S.handlers.social_switch=function(ref,row,d)
    if not S.id(d.id) then return end
    local changed=write(ref,[[UPDATE rp_phone_social_accounts a JOIN rp_phone_social_profiles p ON p.owner=a.owner
        SET a.active=p.id WHERE a.owner=? AND p.id=?]],{row.id,d.id})
    if changed==0 and not MySQL.scalar.await('SELECT id FROM rp_phone_social_profiles WHERE owner=? AND id=?',{row.id,d.id}) then return failure('not_found') end
    return S.handlers.social_home(ref,row)
end
S.handlers.profile=withIdentity(function(ref,row,d,actor)
    if not validProfile(d) or (d.handle:match('^citizen%d+$') and d.handle~=actor.handle) then return end
    write(ref,'UPDATE IGNORE rp_phone_social_profiles SET name=?,bio=?,handle=? WHERE id=? AND owner=?',{d.name,d.bio,d.handle,actor.id,row.id})
    local handle=MySQL.scalar.await('SELECT handle FROM rp_phone_social_profiles WHERE id=?',{actor.id})
    if handle~=d.handle then return failure('handle_taken') end
    return S.handlers.social_home(ref,row)
end)
local profileSelect=[[SELECT u.id,u.handle,u.name,u.bio,
    (SELECT COUNT(*) FROM rp_phone_posts p WHERE p.author=u.id) AS posts,
    (SELECT COUNT(*) FROM rp_phone_follows f WHERE f.target=u.id) AS followers,
    (SELECT COUNT(*) FROM rp_phone_follows f WHERE f.follower=u.id) AS follows,
    EXISTS(SELECT 1 FROM rp_phone_follows f WHERE f.follower=? AND f.target=u.id) AS following
    FROM rp_phone_social_profiles u ]]
local function normalizeProfiles(rows)
    for _,p in ipairs(rows) do
        p.id=tonumber(p.id) p.posts=tonumber(p.posts) p.followers=tonumber(p.followers) p.follows=tonumber(p.follows)
        p.following=p.following==1 or p.following==true
    end
    return rows
end
S.handlers.social_profile=withIdentity(function(_,_,d,actor)
    if not S.id(d.id) then return end
    local rows=normalizeProfiles(MySQL.query.await(profileSelect..'WHERE u.id=?',{actor.id,d.id}))
    return rows[1] and reply('social_profile',{profile=rows[1]}) or failure('not_found')
end)
S.handlers.social_search=withIdentity(function(_,_,d,actor)
    if not S.text(d.query,24,true) then return end
    -- Prefix search uses the unique handle index; escape SQL LIKE metacharacters.
    local query=d.query:lower():gsub('[^a-z0-9_.]',''):gsub('[!_%%]',function(c) return '!'..c end)..'%'
    local rows=normalizeProfiles(MySQL.query.await(profileSelect..[[WHERE u.id<? AND u.id<>? AND u.handle LIKE ? ESCAPE '!'
        ORDER BY u.id DESC LIMIT 20]],{actor.id,cursor(d),actor.id,query}))
    return reply('social_people',{rows=rows,more=#rows==20})
end)
S.handlers.social_people=withIdentity(function(_,_,d,actor)
    if not S.id(d.id) or (d.mode~='followers' and d.mode~='following') then return end
    local clause=d.mode=='followers' and 'f.follower=u.id AND f.target=?' or 'f.target=u.id AND f.follower=?'
    local rows=normalizeProfiles(MySQL.query.await(profileSelect..'WHERE u.id<? AND EXISTS(SELECT 1 FROM rp_phone_follows f WHERE '
        ..clause..') ORDER BY u.id DESC LIMIT 20',{actor.id,cursor(d),d.id}))
    return reply('social_people',{rows=rows,more=#rows==20})
end)
S.handlers.feed=withIdentity(function(_,_,d,actor)
    if d.author~=nil and not S.id(d.author) then return end
    if d.id~=nil and not S.id(d.id) then return end
    local author=S.id(d.author) or 0
    local posts=MySQL.query.await([[SELECT p.id,p.author,p.photo,p.caption,p.created,u.name,u.handle,
        (SELECT COUNT(*) FROM rp_phone_likes l WHERE l.post=p.id) AS likes,
        EXISTS(SELECT 1 FROM rp_phone_likes l WHERE l.post=p.id AND l.profile=?) AS liked,
        EXISTS(SELECT 1 FROM rp_phone_follows f WHERE f.follower=? AND f.target=p.author) AS following,
        (SELECT COUNT(*) FROM rp_phone_comments c WHERE c.post=p.id) AS comments
        FROM rp_phone_posts p JOIN rp_phone_social_profiles u ON u.id=p.author
        WHERE p.id<? AND (?=0 OR p.author=?) AND (?=0 OR p.id=?)
        AND (?=0 OR EXISTS(SELECT 1 FROM rp_phone_follows f WHERE f.follower=? AND f.target=p.author))
        ORDER BY p.id DESC LIMIT 15]],{actor.id,actor.id,cursor(d),author,author,d.id or 0,d.id or 0,d.following==true and 1 or 0,actor.id})
    for _,p in ipairs(posts) do
        p.id=tonumber(p.id) p.author=tonumber(p.author) p.photo=tonumber(p.photo)
        p.likes=tonumber(p.likes) p.comments=tonumber(p.comments)
        p.liked=p.liked==1 or p.liked==true p.following=p.following==1 or p.following==true
    end
    return reply('feed',{rows=posts,more=#posts==15})
end)
S.handlers.publish_local=withIdentity(function(ref,row,d,actor)
    if not nonce(d) or not S.validPhoto(d.image) or not S.text(d.caption,1000,true) then return end
    local previous=MySQL.single.await([[SELECT p.caption,f.image FROM rp_phone_posts p JOIN rp_phone_photos f ON f.id=p.photo
        WHERE p.author=? AND p.nonce=?]],{actor.id,d.nonce})
    if previous then return previous.caption==d.caption and previous.image==d.image and {ok=true} or failure('conflict') end
    if not S.rate(ref.source,'publish',3000) then return failure('rate_limited') end
    if MySQL.scalar.await('SELECT COUNT(*) FROM rp_phone_posts WHERE author=?',{actor.id})>=C.photos then return failure('limit') end
    if MySQL.scalar.await('SELECT id FROM rp_phone_photos WHERE owner=? AND nonce=?',{row.id,d.nonce}) then return failure('conflict') end
    if not S.current(ref) then return failure('invalid_state') end
    local now=os.time()
    local saved=MySQL.transaction.await({
        {query='INSERT INTO rp_phone_photos (owner,nonce,image,created) VALUES (?,?,?,?)',values={row.id,d.nonce,d.image,now}},
        {query=[[INSERT INTO rp_phone_posts (author,photo,nonce,caption,created)
            SELECT ?,id,?,?,? FROM rp_phone_photos WHERE owner=? AND nonce=?]],values={actor.id,d.nonce,d.caption,now,row.id,d.nonce}},
    })
    return saved==true and {ok=true} or failure('unavailable')
end)
S.handlers.image=function(_,row,d)
    if not S.id(d.id) then return end
    local photo=MySQL.single.await([[SELECT image FROM rp_phone_photos WHERE id=? AND (owner=?
        OR EXISTS(SELECT 1 FROM rp_phone_posts WHERE photo=rp_phone_photos.id))]],{d.id,row.id})
    return photo and reply('image',{id=d.id,image=photo.image}) or failure('not_found')
end
S.handlers.photo_delete=function(ref,row,d)
    if not S.id(d.id) then return end
    if MySQL.scalar.await('SELECT COUNT(*) FROM rp_phone_posts WHERE photo=?',{d.id})>0 then return failure('photo_published') end
    write(ref,'DELETE FROM rp_phone_photos WHERE id=? AND owner=?',{d.id,row.id}) return {ok=true}
end
S.handlers.post=withIdentity(function(ref,row,d,actor)
    if not S.id(d.photo) or not S.text(d.caption,1000,true) or not nonce(d) then return end
    local previous=MySQL.single.await('SELECT photo,caption FROM rp_phone_posts WHERE author=? AND nonce=?',{actor.id,d.nonce})
    if previous then return tonumber(previous.photo)==d.photo and previous.caption==d.caption and {ok=true} or failure('conflict') end
    if not S.rate(ref.source,'post',3000) then return failure('rate_limited') end
    if MySQL.scalar.await('SELECT COUNT(*) FROM rp_phone_posts WHERE author=?',{actor.id})>=C.photos then return failure('limit') end
    if not MySQL.scalar.await('SELECT id FROM rp_phone_photos WHERE id=? AND owner=?',{d.photo,row.id}) then return failure('not_found') end
    write(ref,'INSERT INTO rp_phone_posts (author,photo,nonce,caption,created) VALUES (?,?,?,?,?)',{actor.id,d.photo,d.nonce,d.caption,os.time()})
    return {ok=true}
end)
S.handlers.post_delete=withIdentity(function(ref,row,d,actor)
    if not S.id(d.id) then return end
    local photo=MySQL.scalar.await('SELECT photo FROM rp_phone_posts WHERE id=? AND author=?',{d.id,actor.id})
    if not photo then return {ok=true} end
    if not S.current(ref) then return failure('invalid_state') end
    local saved=MySQL.transaction.await({
        {query='DELETE FROM rp_phone_posts WHERE id=? AND author=?',values={d.id,actor.id}},
        {query=[[DELETE FROM rp_phone_photos WHERE id=? AND owner=? AND NOT EXISTS
            (SELECT 1 FROM rp_phone_posts WHERE photo=rp_phone_photos.id)]],values={photo,row.id}},
    })
    return saved==true and {ok=true} or failure('unavailable')
end)
S.handlers.like=withIdentity(function(ref,_,d,actor)
    if not S.id(d.id) or type(d.enabled)~='boolean' then return end
    if d.enabled then write(ref,'INSERT IGNORE INTO rp_phone_likes (post,profile) SELECT id,? FROM rp_phone_posts WHERE id=?',{actor.id,d.id})
    else write(ref,'DELETE FROM rp_phone_likes WHERE post=? AND profile=?',{d.id,actor.id}) end
    return {ok=true}
end)
S.handlers.follow=withIdentity(function(ref,_,d,actor)
    if not S.id(d.id) or d.id==actor.id or type(d.enabled)~='boolean' then return end
    if d.enabled then write(ref,'INSERT IGNORE INTO rp_phone_follows (follower,target) SELECT ?,id FROM rp_phone_social_profiles WHERE id=?',{actor.id,d.id})
    else write(ref,'DELETE FROM rp_phone_follows WHERE follower=? AND target=?',{actor.id,d.id}) end
    return {ok=true}
end)
S.handlers.comments=withIdentity(function(_,_,d)
    if not S.id(d.id) then return end
    local rows=MySQL.query.await([[SELECT c.id,c.author,c.body,c.created,u.name,u.handle FROM rp_phone_comments c
        JOIN rp_phone_social_profiles u ON u.id=c.author WHERE c.post=? AND c.id<? ORDER BY c.id DESC LIMIT 30]],{d.id,cursor(d)})
    for _,c in ipairs(rows) do c.id=tonumber(c.id) c.author=tonumber(c.author) end
    return reply('comments',{rows=rows,more=#rows==30})
end)
S.handlers.comment=withIdentity(function(ref,_,d,actor)
    if not S.id(d.id) or not S.text(d.body,400) or not d.body:find('%S') or not nonce(d) then return end
    local previous=MySQL.single.await('SELECT post,body FROM rp_phone_comments WHERE author=? AND nonce=?',{actor.id,d.nonce})
    if previous then return tonumber(previous.post)==d.id and previous.body==d.body and {ok=true} or failure('conflict') end
    if not S.rate(ref.source,'comment',1200) then return failure('rate_limited') end
    local changed=write(ref,[[INSERT IGNORE INTO rp_phone_comments (post,author,nonce,body,created)
        SELECT id,?,?,?,? FROM rp_phone_posts WHERE id=?]],{actor.id,d.nonce,d.body,os.time(),d.id})
    return changed>0 and {ok=true} or failure('not_found')
end)
