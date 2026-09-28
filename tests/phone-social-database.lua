-- Run by phone-apps-database.py against isolated real MariaDB tables.
local function home(id) return act(id,'social_home',{}).phone end
local first,second=home(1).active,home(2).active
local registration={handle='extra_personal',name='Extra',bio='',nonce='extra-1'}
check(home(1).slots==1 and #home(1).profiles==1,'default is one profile per character')
check(not act(1,'social_create',registration).ok,'second profile denied without admin allocation')
check(not act(2,'social_switch',{id=first}).ok,'foreign profile switch denied')
check(not act(2,'profile',{actor=first,handle='stolen',name='Stolen',bio=''}).ok,'cannot impersonate foreign identity')
check(not act(1,'social_create',{handle='bad_handle',name='',bio='',nonce='bad-name'}).ok,'empty profile name rejected')
check(not act(1,'social_create',{handle='citizen999',name='Reserved',bio='',nonce='bad-reserved'}).ok,'legacy default handle namespace protected')
local adminErrors={}
local function fail(message) adminErrors[#adminErrors+1]=message end
tick(2000)
callbacks.rp_ifruit_slots(players[2],{id=2,slots=2},fail)
check(home(2).slots==1,'unprivileged caller cannot allocate extra profiles')
tick(2000)
callbacks.rp_ifruit_slots(players[1],{id=2,slots=6},fail)
check(home(2).slots==1,'admin upper bound enforced')
tick(2000)
callbacks.rp_ifruit_slots(players[1],{id=2,slots=2},fail)
check(home(2).slots==2 and home(1).slots==1,'admin allocation affects only target character')
local company={handle='fischer_motors',name='Fischer Motors',bio='Werkstatt',nonce='company-1'}
check(act(2,'social_create',company).ok,'allocated second profile can be created')
local business=home(2).active
check(business~=second and #home(2).profiles==2,'additional social identity has separate public ID')
check(act(2,'social_create',company).ok and #home(2).profiles==2,'replayed creation remains idempotent at limit')
check(not act(2,'social_create',{handle='changed',name=company.name,bio=company.bio,nonce='company-1'}).ok,'altered creation nonce rejected')
tick(2000)
callbacks.rp_ifruit_slots(players[1],{id=2,slots=1},fail)
check(home(2).slots==2 and #home(2).profiles==2,'lowering allowance never deletes existing profiles')
check(act(2,'home',{}).phone.profile.number==profiles[2].number,'social switching preserves phone number')
check(act(2,'home',{}).phone.profile.name==profiles[2].name,'social display name never overwrites phone identity')
check(act(2,'home',{}).phone.profile.galleryScope==profiles[2].galleryScope,'business uses the same character-local gallery')
check(act(2,'publish_local',{actor=business,image=jpeg,caption='Unternehmen',nonce='company-post'}).ok,'publish using allocated business identity')
local post=act(1,'feed',{}).phone.rows[1]
check(post.author==business and post.handle==company.handle,'feed attribution is the active business identity')
check(not act(2,'publish_local',{actor=second,image=jpeg,caption='Wrong profile',nonce='stale-post'}).ok,'stale form cannot publish under a changed identity')
check(act(1,'follow',{id=business,enabled=true}).ok,'follow independent business identity')
check(act(1,'follow',{id=business,enabled=true}).ok,'repeat follow is idempotent')
check(#act(1,'feed',{following=true}).phone.rows==1,'friends feed includes the followed company')
local viewed=act(1,'social_profile',{id=business}).phone.profile
check(viewed.followers==1 and viewed.posts==1 and viewed.following,'profile counters match real SQL state')
check(viewed.owner==nil and viewed.slot==nil,'public profile contains no owner or private allowance')
check(act(2,'social_switch',{id=second}).ok,'switch back to personal identity')
check(#act(2,'feed',{following=true}).phone.rows==0,'company follows do not leak into personal feed')
check(act(2,'like',{id=post.id,enabled=true}).ok,'personal identity can like a public business post')
check(act(2,'comment',{id=post.id,body='Persönlicher Kommentar',nonce='isolated-comment'}).ok,'personal comment')
check(act(2,'comment',{id=post.id,body='Persönlicher Kommentar',nonce='isolated-comment'}).ok,'repeated comment creates one row')
check(not act(2,'comment',{id=post.id,body='Changed',nonce='isolated-comment'}).ok,'changed comment replay rejected')
check(act(2,'post_delete',{id=post.id}).ok and #act(1,'feed',{}).phone.rows==1,'personal profile cannot delete the same character business post')
check(act(2,'social_switch',{id=business}).ok,'business profile switch')
check(not act(2,'feed',{id=post.id}).phone.rows[1].liked,'like selection is independent across own profiles')
check(act(2,'like',{id=post.id,enabled=true}).ok and act(1,'feed',{}).phone.rows[1].likes==2,'one like per social profile')
check(act(2,'comment',{id=post.id,body='Unternehmensantwort',nonce='isolated-comment'}).ok,'same nonce on independent identity has independent meaning')
local replies=act(1,'comments',{id=post.id}).phone
check(#replies.rows==2 and replies.rows[1].author==business,'comments expose author profile for navigation')
check(#act(1,'comments',{id=post.id,before=replies.rows[1].id}).phone.rows==1,'comments cursor does not repeat previous page')
local followers=act(2,'social_people',{id=business,mode='followers'}).phone.rows
check(#followers==1 and followers[1].id==first,'follower list is accurate')
check(#act(1,'social_search',{query='fischer'}).phone.rows==1,'handle prefix discovery includes business profiles')
check(#act(1,'social_search',{query='fischer_'}).phone.rows==1,'underscore search is escaped literally')
check(not act(1,'social_people',{id=business,mode='1 OR 1=1'}).ok,'untrusted relationship filter rejected')
check(act(1,'follow',{id=business,enabled=false}).ok and #act(1,'feed',{following=true}).phone.rows==0,'unfollowing removes content from friends timeline')
check(act(2,'post_delete',{id=post.id}).ok,'business author can delete its own post')
check(#act(1,'comments',{id=post.id}).phone.rows==0,'comments cascade on deleted post')
check(not act(1,'image',{id=post.photo}).ok,'last deleted post removes public photo copy')
check(act(2,'social_switch',{id=second}).ok,'restore personal actor')
-- Source ID reuse: same account, different character has its own one-profile limit.
local oldOwner=players[7].identifier
PhoneService.clear(7) players[7].identifier='char2:license:7' tick(2000)
tokens[7]=callbacks['rp_phone:open'](7).session
check(home(7).active==0 and home(7).slots==1,'character switch isolates profiles and allowance')
players[7].identifier=oldOwner PhoneService.clear(7) tick(2000)
tokens[7]=callbacks['rp_phone:open'](7).session
check(home(7).active>0,'original character identity restored without a new profile')
