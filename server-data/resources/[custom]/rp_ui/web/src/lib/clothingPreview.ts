import type { CommercePayload, CommerceOffer } from './commerce';
import offers from '../data/clothing-preview.json';
const worn = ['top_0_0','undershirt_0_1','pants_0_1','shoes_0_1','hat_0_2','glasses_0_3',
  'ears_0_0','chain_0_1','watch_0_0','bracelet_0_0','mask_0_1','bag_0_1'];
export const clothingPreview = (): CommercePayload => ({
  session:'clothing-preview',kind:'shop',clothing:true,label:'Binco · Strawberry',subtitle:'DEIN STIL. DEINE STADT.',cash:2850,bank:16200,maxQuantity:1,pending:'none',
  currentClothing: worn.flatMap(id => {
    const offer = offers.find(o => o.id === id);
    return offer ? [{...offer.garment,label:offer.label,artwork:offer.artwork}] : [];
  }),
  offers: structuredClone(offers) as CommerceOffer[],
});
