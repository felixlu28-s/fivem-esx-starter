import { useEffect, useRef, useState, type FormEvent } from 'react';
import { UiIcon } from '../components/UiIcon';
import { bankErrors, type BankKind, type BankingPayload, type BankRecipient } from '../lib/banking';
import { fetchNui, isBrowser } from '../lib/nui';
import '../banking.css';

const money=(n:number)=>`$${n.toLocaleString('de-DE')}`;
const labels={deposit:'Einzahlen',withdraw:'Auszahlen',transfer:'Überweisen',received:'Überweisung erhalten',credit:'Gutschrift',debit:'Abbuchung',adjustment:'Kontostand gesetzt'};
type Page='home'|BankKind|'history'|'confirm'|'done';
export function BankingView({data:initial,onClose}:{data:BankingPayload;onClose:()=>void}) {
  const [data,setData]=useState(initial),[page,setPage]=useState<Page>('home');
  const [kind,setKind]=useState<BankKind>('deposit'),[amount,setAmount]=useState(''),[target,setTarget]=useState(''),[note,setNote]=useState('');
  const [recipient,setRecipient]=useState<BankRecipient|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState('');
  const [cursors,setCursors]=useState<number[]>([0]);
  const running=useRef(false),request=useRef<string|null>(null),container=useRef<HTMLElement>(null);
  const value=Number(amount),validAmount=/^[1-9]\d*$/.test(amount)&&Number.isSafeInteger(value)&&value<=data.maxAmount;
  const home=()=>{setPage('home');setError('');setRecipient(null);request.current=null;};
  const back=()=>{if(busy)return;if(page==='home')onClose();else if(page==='confirm'){setPage(kind);setError('');}else home();};
  const go=(next:BankKind)=>{setKind(next);setPage(next);setAmount('');setNote('');setTarget('');setRecipient(null);setError('');request.current=null;};
  const fail=(code?:string)=>setError(bankErrors[code??'']??'Verbindung unterbrochen. Prüfe den Verlauf, bevor du erneut buchst.');
  const load=async(before=0,nextCursors=[0])=>{
    if(running.current)return;running.current=true;setBusy(true);setError('');
    try{
      if(!isBrowser()){
        const result=await fetchNui('rp_banking:action',{session:data.session,action:'history',before});
        if(!result.ok||!result.banking){fail(result.error);return;}setData(result.banking);
      }
      setCursors(nextCursors);setPage('history');
    }catch{fail();}finally{running.current=false;setBusy(false);}
  };
  const checkRecipient=async()=>{
    if(running.current)return;
    if(!/^[1-9]\d{0,4}$/.test(target)||Number(target)>65535){fail('invalid_recipient');return;}
    running.current=true;setBusy(true);setError('');
    try{
      if(isBrowser())setRecipient({id:Number(target),name:'Alex Morgan',token:'browser-recipient'});
      else{
        const result=await fetchNui('rp_banking:action',{session:data.session,action:'recipient',id:Number(target)});
        if(result.ok&&result.bankRecipient)setRecipient(result.bankRecipient);else fail(result.error);
      }
    }catch{fail();}finally{running.current=false;setBusy(false);}
  };
  const review=(event:FormEvent)=>{
    event.preventDefault();if(busy||data.held)return;
    if(!validAmount){fail('invalid_request');return;}
    if(value>(kind==='deposit'?data.cash:data.bank)){fail('insufficient_funds');return;}
    if(kind==='transfer'&&(!recipient||recipient.id!==Number(target))){fail('invalid_recipient');return;}
    request.current=`bank_${crypto.randomUUID().replaceAll('-','')}`;
    setError('');setPage('confirm');
  };
  const submit=async()=>{
    if(running.current||!validAmount||!request.current)return;
    running.current=true;setBusy(true);setError('');
    try{
      if(isBrowser()){
        const bank=data.bank+(kind==='deposit'?value:-value);
        setData({...data,bank,cash:data.cash+(kind==='deposit'?-value:kind==='withdraw'?value:0),
          history:[{id:(data.history[0]?.id??0)+1,kind,amount:kind==='deposit'?value:-value,balance:bank,
            counterparty:kind==='transfer'?recipient?.name??'':'',note,time:Math.floor(Date.now()/1000)},...data.history].slice(0,20)});
      }else{
        const result=await fetchNui('rp_banking:action',{session:data.session,action:'transact',kind,amount:value,
          note,recipient:recipient?.token,request:request.current});
        if(result.banking)setData(result.banking);
        if(!result.ok){fail(result.error);return;}
      }
      request.current=null;setPage('done');
    }catch{fail();}finally{running.current=false;setBusy(false);}
  };
  useEffect(()=>{
    // Changing pages removes the focused button. Listen at window level so the
    // next arrow key still works when the browser has returned focus to body.
    const keyboard=(event:KeyboardEvent)=>{
      if(event.defaultPrevented||!container.current)return;
      const element=event.target instanceof HTMLElement?event.target:null;
      if(element?.matches('input,textarea,[contenteditable="true"]'))return;
      if(event.key==='Backspace'){event.preventDefault();back();return;}
      if(!['ArrowDown','ArrowUp','ArrowRight','ArrowLeft'].includes(event.key))return;
      event.preventDefault();
      const controls=Array.from(container.current.querySelectorAll<HTMLButtonElement>('button:not(:disabled)'));
      const current=controls.indexOf(document.activeElement as HTMLButtonElement);
      const forward=['ArrowDown','ArrowRight'].includes(event.key);
      const next=current<0?(forward?0:controls.length-1):(current+(forward?1:-1)+controls.length)%controls.length;
      controls[next]?.focus();
    };
    window.addEventListener('keydown',keyboard);
    return()=>window.removeEventListener('keydown',keyboard);
  });
  const brand=data.brand==='fleeca'?'FLEECA':data.brand==='maze'?'MAZE BANK':'BANK OF LIBERTY';
  return <main ref={container} className={`atm-screen atm-${data.brand}`} aria-label="Geldautomat">
    <section className="atm-terminal" aria-busy={busy}>
      <div className="atm-housing-top" aria-hidden="true"><span>ATM</span><i/><small>24 HOUR BANKING</small></div>
      <div className="atm-bezel">
        <div className="atm-display">
          <header className="atm-brand">
            <div className="atm-logo" aria-label={brand}>
              {data.brand==='maze'?<svg viewBox="0 0 40 40" aria-hidden="true"><path d="M3 4h12v23h22v9H3Zm17 0h17v18h-9V13h-8Z"/></svg>:
                data.brand==='liberty'?<UiIcon name="bank"/>:<svg viewBox="0 0 40 40" aria-hidden="true"><path d="M5 5h31l-3 8H15l-2 6h17l-3 8H10l-3 9H0Z"/></svg>}
              <span>{brand}<small>{data.brand==='fleeca'?'It’s time for a change.':data.brand==='maze'?'Invest in the red.':'Banking on your future.'}</small></span>
            </div>
            <button onClick={onClose} aria-label="Geldautomat schließen"><UiIcon name="close"/></button>
          </header>
          <div className="atm-status"><span>Willkommen, {data.name}</span><span>DE · $</span></div>
          <div className="atm-content" key={page}>
            {data.held&&<p className="atm-warning" role="alert">Eine Buchung wird geprüft. Kontobewegungen sind vorübergehend gesperrt; dein Verlauf bleibt verfügbar.</p>}
            {error&&<p className="atm-error" role="alert">{error}</p>}
            {page==='home'&&<div className="atm-home">
              <div className="atm-balance"><span>Dein Kontostand</span><strong>{money(data.bank)}</strong><p><UiIcon name="wallet"/>Bargeld <b>{money(data.cash)}</b></p><small>Bitte wähle eine Transaktion.</small></div>
              <div className="atm-options">
                {(['withdraw','deposit','transfer'] as const).map(option=><button key={option} disabled={busy||data.held} onClick={()=>go(option)}>{labels[option]}<span>◀</span></button>)}
                <button disabled={busy} onClick={()=>void load()}>Kontoverlauf<span>◀</span></button>
              </div>
            </div>}
            {(['deposit','withdraw','transfer'] as Page[]).includes(page)&&<form className="atm-form" onSubmit={review}>
              <div className="atm-section-title"><h1>{labels[kind]}</h1><span>Verfügbar: {money(kind==='deposit'?data.cash:data.bank)}</span></div>
              {kind==='transfer'&&<div className="atm-recipient">
                <label>Spieler-ID<input aria-label="Empfänger-ID" inputMode="numeric" autoComplete="off" maxLength={5} value={target} disabled={busy} onChange={e=>{setTarget(e.target.value.replace(/\D/g,''));setRecipient(null);}}/></label>
                <button type="button" disabled={busy||!target} onClick={()=>void checkRecipient()}>Empfänger prüfen</button>
                <p>{recipient?<><UiIcon name="check"/>{recipient.name} · ID {recipient.id}</>:'Überweisungen an Spieler, die gerade online sind.'}</p>
              </div>}
              <label className="atm-amount">Betrag in $<input aria-label="Betrag" inputMode="numeric" autoComplete="off" maxLength={7} placeholder="0" value={amount} disabled={busy} onChange={e=>setAmount(e.target.value.replace(/\D/g,''))}/></label>
              <div className="atm-presets">{[100,500,1000].map(n=><button type="button" key={n} disabled={busy||n>data.maxAmount} onClick={()=>setAmount(String(n))}>{money(n)}</button>)}<button type="button" disabled={busy} onClick={()=>setAmount(String(Math.min(data.maxAmount,kind==='deposit'?data.cash:data.bank)))}>Alles</button></div>
              {kind==='transfer'&&<label className="atm-note">Verwendungszweck <small>optional</small><input aria-label="Verwendungszweck" maxLength={60} value={note} disabled={busy} onChange={e=>setNote(e.target.value)}/></label>}
              <div className="atm-form-actions"><button type="button" disabled={busy} onClick={home}>Zurück</button><button className="atm-primary" disabled={busy||data.held||!validAmount||(kind==='transfer'&&!recipient)}>Weiter <UiIcon name="arrow"/></button></div>
            </form>}
            {page==='confirm'&&<div className="atm-confirm">
              <UiIcon name={kind==='transfer'?'bank':'wallet'}/><h1>{labels[kind]} bestätigen</h1><strong>{money(value)}</strong>
              <p>{kind==='transfer'?`An ${recipient?.name} · ID ${recipient?.id}`:kind==='deposit'?'Von deinem Bargeld auf dein Konto.':'Von deinem Konto als Bargeld auszahlen.'}</p>
              {note&&<p>{note}</p>}<small>Gebühren: $0</small>
              <div className="atm-form-actions"><button disabled={busy} onClick={back}>Zurück</button><button className="atm-primary" disabled={busy||data.held} onClick={()=>void submit()}>{busy?'Wird verarbeitet …':'Bestätigen'}<UiIcon name="check"/></button></div>
            </div>}
            {page==='done'&&<div className="atm-confirm atm-done"><UiIcon name="check"/><h1>Transaktion erfolgreich</h1><strong>{money(value)}</strong><p>Neuer Kontostand: {money(data.bank)}</p><div className="atm-form-actions"><button onClick={onClose}>Beenden</button><button className="atm-primary" onClick={home}>Weitere Transaktion</button></div></div>}
            {page==='history'&&<div className="atm-history"><div className="atm-section-title"><h1>Kontoverlauf</h1><span>{money(data.bank)}</span></div>
              <ol>{data.history.map(entry=><li key={entry.id}><div><strong>{labels[entry.kind]}</strong><span>{entry.counterparty||entry.note||'Geldautomat'}</span>{entry.counterparty&&entry.note&&<span>{entry.note}</span>}<time>{new Date(entry.time*1000).toLocaleString('de-DE',{timeZone:'Europe/Berlin',day:'2-digit',month:'2-digit',year:'2-digit',hour:'2-digit',minute:'2-digit'})}</time></div><div><b className={entry.amount>0?'atm-credit':''}>{entry.kind==='adjustment'?`Auf ${money(entry.balance)}`:`${entry.amount>0?'+':'−'}${money(Math.abs(entry.amount))}`}</b><small>Saldo {money(entry.balance)}</small></div></li>)}</ol>
              {!data.history.length&&<p className="atm-empty">Noch keine Buchungen vorhanden.</p>}
              <div className="atm-history-pages"><button disabled={busy} onClick={home}>Zurück</button><span>Seite {cursors.length}</span><button disabled={busy||cursors.length<2} onClick={()=>void load(cursors[cursors.length-2],cursors.slice(0,-1))}>Neuere</button><button disabled={busy||!data.more} onClick={()=>{const last=data.history.at(-1)?.id;if(last)void load(last,[...cursors,last]);}}>Ältere</button></div>
            </div>}
          </div>
          <footer className="atm-footer"><span><UiIcon name="bank"/>{brand}</span><span>Persönliches Konto · Los Santos</span></footer>
        </div>
        <div className="atm-hardware" aria-hidden="true"><div className="atm-card-slot"><i/>CARD</div>{[0,1,2,3].map(n=><i className="atm-hardware-key" key={n}/>)}<span>SECURE<br/>TERMINAL</span></div>
      </div>
      <div className="atm-housing-bottom" aria-hidden="true"><div className="atm-cash-slot"><span>CASH</span><i/></div><span>Bitte vergiss dein Bargeld nicht.</span></div>
    </section>
    <p className="atm-help"><kbd>↑</kbd><kbd>↓</kbd> Auswählen <kbd>Enter</kbd> Bestätigen <kbd>Esc</kbd> Beenden</p>
  </main>;
}
