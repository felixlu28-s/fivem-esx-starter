-- Bounded JPEG header inspection before a client photo can enter a public feed.
-- Only normal 8-bit canvas JPEGs are accepted; no arbitrary browser image formats.
local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local digits={}
for i=1,#alphabet do digits[alphabet:byte(i)]=i-1 end
local prefix='data:image/jpeg;base64,'
function PhoneService.validPhoto(image)
    if type(image)~='string' or #image<100 or #image>PhoneConfig.photoBytes or image:sub(1,#prefix)~=prefix then return false end
    local data=image:sub(#prefix+1)
    if #data%4~=0 or not data:match('^[A-Za-z0-9+/]+=?=?$') then return false end
    local length=#data/4*3-(data:sub(-2)=='==' and 2 or data:sub(-1)=='=' and 1 or 0)
    local function byte(at)
        if at<1 or at>length then return nil end
        local offset=math.floor((at-1)/3)*4+1
        local a,b,c,d=data:byte(offset,offset+3)
        a,b,c,d=digits[a],digits[b],digits[c] or 0,digits[d] or 0
        if not a or not b then return nil end
        local part=(at-1)%3
        if part==0 then return (a<<2)|(b>>4) end
        if part==1 then return ((b&15)<<4)|(c>>2) end
        return ((c&3)<<6)|d
    end
    local function short(at)
        local a,b=byte(at),byte(at+1)
        return a and b and a*256+b or nil
    end
    if short(1)~=0xffd8 or short(length-1)~=0xffd9 then return false end
    local at,bound=3,math.min(length,8192)
    while at+4<=bound do
        if byte(at)~=0xff then return false end
        while at<=bound and byte(at)==0xff do at=at+1 end
        local marker=byte(at) at=at+1
        local size=short(at)
        if not size or size<2 or at+size-1>bound then return false end
        if marker==0xc0 or marker==0xc1 or marker==0xc2 then
            local height,width,components=short(at+3),short(at+5),byte(at+7)
            return byte(at+2)==8 and height and width and components and components>=1 and components<=3
                and size==8+3*components and width>0 and width<=1280 and height>0 and height<=720
        end
        if marker==0xda or marker==0xd8 or marker==0xd9 or (marker>=0xc0 and marker<=0xcf and marker~=0xc4) then return false end
        at=at+size
    end
    return false
end
