local base='server-data/resources/[custom]/rp_inventory/'
dofile(base..'shared/items.lua') dofile(base..'shared/model.lua')
local M,passed=Inventory.model,0
local function check(v,msg) assert(v,msg) passed=passed+1 end
local data=M.empty()
check(M.add(data,'ammo_pistol',24) and M.add(data,'ammo_rifle',60),'new ammo adds as normal provider items')
for _,entry in pairs(data.items) do check(entry.count==Inventory.items[entry.name].maxStack,'new full stacks equal one magazine') end
local legacy=M.empty()
legacy.items['1']={name='ammo_pistol',count=60,metadata={batch='old'}}
legacy.items['2']={name='ammo_rifle',count=90,metadata={batch='old-rifle'}}
local weight=M.weight(legacy)
check(M.valid(legacy),'previous persisted stacks remain readable')
M.repackAmmo(legacy)
check(M.count(legacy,'ammo_pistol')==60 and M.count(legacy,'ammo_rifle')==90 and M.weight(legacy)==weight,'conversion conserves rounds and weight')
for _,entry in pairs(legacy.items) do check(entry.count<=Inventory.items[entry.name].maxStack and entry.metadata.batch~=nil,'split retains metadata') end
local canonical=M.canonical(legacy) M.repackAmmo(legacy)
check(M.canonical(legacy)==canonical,'repeat conversion idempotent')
local full=M.empty(2)
full.items['1']={name='ammo_pistol',count=60,metadata={}}
full.items['2']={name='rp_water',count=1,metadata={}}
M.repackAmmo(full)
check(M.valid(full) and M.count(full,'ammo_pistol')==60,'full legacy inventory retains all ammunition and access')
check(not M.add(M.copy(full),'ammo_pistol',1),'cannot grow oversized legacy stack')
check(M.remove(full,'rp_water',1),'free a legacy slot') M.repackAmmo(full)
check(full.items['1'].count==48 and full.items['2'].count==12,'free slot used for one full magazine without loss')
check(not M.valid({slots=1,capacity=25000,items={['1']={name='ammo_pistol',count=61,metadata={}}}}),'compatibility never accepts above previous hard limit')
print(('PASS: %d magazine stack compatibility assertions'):format(passed))
