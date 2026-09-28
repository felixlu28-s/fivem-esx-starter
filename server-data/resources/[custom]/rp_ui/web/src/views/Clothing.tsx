import { useEffect, useRef, useState } from 'react';
import { ClothingImage } from '../components/ClothingImage';
import { UiIcon } from '../components/UiIcon';
import { commerceErrors, type CommerceOffer, type CommercePayload } from '../lib/commerce';
import { errorLabel, fetchNui, isBrowser } from '../lib/nui';
import { CreatorCamera, type CameraView } from './CreatorCamera';
import '../clothing.css';

const money = (value: number) => `$${value.toLocaleString('de-DE')}`;
const order = ['top','undershirt','pants','shoes','hat','glasses','ears','chain','watch','bracelet','mask','bag'];
type Outfit = Partial<Record<string, string>>;
export function ClothingView({data: initial,onClose}: { data: CommercePayload; onClose: () => void }) {
  const [data,setData] = useState(initial);
  const [category,setCategory] = useState('top');
  const [search,setSearch] = useState('');
  const [selected,setSelected] = useState<Outfit>({});
  const [equip,setEquip] = useState(false);
  const [account,setAccount] = useState<'money'|'bank'>('money');
  const [busy,setBusy] = useState(false);
  const [notice,setNotice] = useState('');
  const [previewed,setPreviewed] = useState<string | null>(null);
  const [focus,setFocus] = useState<CameraView>('body');
  const [hidden,setHidden] = useState(false);
  const running = useRef(false);
  const pendingPreview = useRef<string | null>(null);
  const previewKey = JSON.stringify(order.flatMap(id => selected[id] ? [selected[id]] : []));
  const latestPreview = useRef(previewKey);
  latestPreview.current = previewKey;
  const ready = previewed === previewKey;
  const active = data.offers.find(o => o.id === selected[category]);
  const current = data.currentClothing?.find(c => c.category === category);
  const basket = data.offers.filter(o => o.garment && selected[o.garment.category] === o.id);
  const total = basket.reduce((sum,o) => sum + o.price,0);
  const categories = order.flatMap(id => {
    const first = data.offers.find(o => o.garment?.category === id);
    return first ? [{id,label:first.category,view:first.garment?.view ?? 'body' as CameraView}] : [];
  });
  const offers = data.offers.filter(o => o.garment?.category === category && o.label.toLocaleLowerCase('de').includes(search.toLocaleLowerCase('de')));
  // Whole-outfit snapshots, serialized and coalesced: a slow preview cannot make
  // an older category selection purchase-ready after another click.
  useEffect(() => { pendingPreview.current = previewKey; }, [previewKey]);
  useEffect(() => {
    let alive = true, inFlight = false;
    const timer = window.setInterval(() => {
      const key = pendingPreview.current;
      if (key === null || inFlight) return;
      pendingPreview.current = null;
      inFlight = true;
      void fetchNui('rp_clothing:preview',{products:JSON.parse(key) as string[]}).then(result => {
        if (!alive || latestPreview.current !== key) return;
        setPreviewed(result.ok ? key : null);
        if (!result.ok) setNotice('Ein Kleidungsstück ist für dein Modell nicht verfügbar. Wähle dort „Aktuell“ oder einen anderen Artikel.');
      }).catch(() => { if (alive && latestPreview.current === key) setNotice('Die Vorschau konnte nicht geladen werden.'); })
        .finally(() => { inFlight = false; });
    },60);
    return () => { alive = false; window.clearInterval(timer); };
  },[]);
  const select = (offer?: CommerceOffer) => {
    if (running.current) return;
    setSelected(before => ({...before,[category]:offer?.id}));
    setNotice(''); setFocus(offer?.garment?.view ?? categories.find(c=>c.id===category)?.view ?? 'body');
  };
  const buy = async (mode: 'one'|'all'|'recover') => {
    const recover = mode === 'recover';
    const purchased = mode === 'one' ? (active ? [active] : []) : basket;
    if (running.current || (!recover && (!purchased.length || !ready))) return;
    running.current = true; setBusy(true); setNotice('');
    try {
      if (isBrowser()) {
        const cost = purchased.reduce((sum,o)=>sum+o.price,0);
        const balance = account === 'money' ? data.cash : data.bank;
        if (balance < cost) { setNotice(commerceErrors.not_enough_money); return; }
        const replacement = new Set(purchased.map(o=>o.garment?.category));
        setData({...data,[account === 'money' ? 'cash' : 'bank']:balance-cost,
          currentClothing: equip ? [...(data.currentClothing ?? []).filter(c=>!replacement.has(c.category)),
            ...purchased.flatMap(o=>o.garment ? [{...o.garment,label:o.label,artwork:o.artwork}] : [])] : data.currentClothing,
          offers:data.offers.map(o=>purchased.includes(o) ? {...o,owned:o.owned+1} : o),pending:'none'});
      } else {
        const result = await fetchNui('rp_clothing:buy', {session:data.session,action:recover?'recover':'buyOutfit',
          products:purchased.map(o=>o.id),equip,account,request:`clothes_${crypto.randomUUID().replaceAll('-','')}`});
        if (result.commerce) setData(result.commerce);
        if (!result.ok) { setNotice(commerceErrors[result.error ?? ''] ?? errorLabel(result.error)); return; }
      }
      setSelected(before => {
        if (recover) return {};
        const next = {...before};
        for (const offer of purchased) if (offer.garment) delete next[offer.garment.category];
        return next;
      });
      const label = purchased.length === 1 ? purchased[0].label : `${purchased.length} Kleidungsstücke`;
      setNotice(recover ? 'Bestellung abgeholt.' : `${label} gekauft. ${equip?'Direkt angezogen.':'In deinem Inventar.'}`);
    } catch { setNotice('Antwort unterbrochen. Laden erneut öffnen, um den Bestellstatus zu prüfen.'); }
    finally { running.current=false; setBusy(false); }
  };
  return <main className={`clothing-screen mode-creator ${hidden?'fitting-only':''}`} aria-label="Kleidungsladen" aria-busy={busy}>
    <CreatorCamera focus={focus} onError={setNotice} action="rp_clothing:camera"/>
    <nav className="clothing-categories" aria-label="Kategorien">
      <div className="clothing-brand"><UiIcon name="shop"/><span>LOS SANTOS<strong>Dein Stil.</strong></span></div>
      {categories.map(cat => <button key={cat.id} disabled={busy} aria-pressed={category===cat.id} onClick={() => {
        setCategory(cat.id); setSearch(''); setFocus(cat.view);
      }}><ClothingImage category={cat.id} label=""/><span>{cat.label}</span>{selected[cat.id] && <UiIcon name="check"/>}</button>)}
    </nav>
    <section className="clothing-panel" aria-label="Sortiment">
      <header><div><span>{data.subtitle}</span><h1>{data.label}</h1></div><button aria-label="Laden schließen" onClick={onClose}><UiIcon name="close"/></button></header>
      <div className="clothing-section"><strong>{categories.find(c=>c.id===category)?.label}</strong><span>{offers.length} Artikel</span></div>
      <label className="clothing-search"><UiIcon name="search"/><input aria-label="Kleidung suchen" placeholder="Artikel suchen …" value={search} onChange={e=>setSearch(e.target.value)}/></label>
      <div className="clothing-products">
        <button disabled={busy} className="clothing-product clothing-current" aria-label="Aktuell" aria-pressed={!selected[category]} onClick={()=>select()}>
          <ClothingImage artwork={current?.artwork} category={current?.image ?? category} color={current?.color} label={current?.label ?? ''}/>
          <span>Aktuell</span><strong>{current?.label ?? 'Wie angezogen'}</strong>
        </button>
        {offers.map(offer => <button key={offer.id} disabled={busy} className="clothing-product" aria-pressed={selected[category]===offer.id} onClick={()=>select(offer)}>
          <ClothingImage artwork={offer.artwork} category={offer.garment?.image ?? 'top'} color={offer.garment?.color} label={offer.label}/>
          <span>{offer.label}</span><strong>{money(offer.price)}</strong>
        </button>)}
        {!offers.length && <p className="clothing-empty">Keine passenden Artikel.</p>}
      </div>
      <footer>
        <div className="clothing-selected"><span>{basket.length ? `${basket.length} ${basket.length===1?'Teil':'Teile'} ausgewählt` : 'Stelle dein Outfit zusammen'}</span><strong>{money(total)}</strong></div>
        <div className="clothing-payment" role="group" aria-label="Zahlungsmethode">
          <button disabled={busy} aria-pressed={account==='money'} onClick={()=>setAccount('money')}><UiIcon name="wallet"/>Bargeld <span>{money(data.cash)}</span></button>
          <button disabled={busy} aria-pressed={account==='bank'} onClick={()=>setAccount('bank')}><UiIcon name="bank"/>Konto <span>{money(data.bank)}</span></button>
        </div>
        {notice && <p role="status" className="clothing-notice">{notice}</p>}
        {data.pending === 'paid' ? <button className="clothing-buy" disabled={busy} onClick={()=>void buy('recover')}>Bezahlte Bestellung abholen <UiIcon name="check"/></button>
          : data.pending === 'intent' ? <p role="status">Eine frühere Zahlung muss geprüft werden. Es wird nichts erneut abgebucht.</p>
          : <div className="clothing-checkout">
            <button className="clothing-buy" aria-label="Kaufen" disabled={busy || !active || !ready} onClick={()=>void buy('one')}><span>Kaufen</span><small>{active ? money(active.price) : 'Aktuell'}</small></button>
            <button className="clothing-buy" aria-label="Alles kaufen" disabled={busy || !basket.length || !ready} onClick={()=>void buy('all')}><span>Alles kaufen</span><small>{money(total)}</small></button>
            <label className="clothing-equip"><input type="checkbox" checked={equip} disabled={busy} onChange={e=>setEquip(e.target.checked)}/><span>Direkt<br/>anziehen</span></label>
          </div>}
        <small>{busy ? 'Einkauf wird verarbeitet …' : equip ? 'Gekaufte Teile anziehen · bisherige bleiben in den Taschen.' : 'Käufe landen in deinen Taschen. Anziehen über das Inventar.'}</small>
      </footer>
    </section>
    <button className="clothing-toggle" onClick={()=>setHidden(!hidden)} aria-pressed={hidden}><UiIcon name="person"/>{hidden?'Sortiment anzeigen':'Nur Anprobe'}</button>
  </main>;
}
