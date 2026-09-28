export type BankBrand = 'fleeca'|'maze'|'liberty';
export type BankKind = 'deposit'|'withdraw'|'transfer';
export type BankEntry = { id:number; kind:BankKind|'received'|'credit'|'debit'|'adjustment'; amount:number; balance:number; counterparty:string; note:string; time:number };
export type BankingPayload = { session:string; brand:BankBrand; name:string; cash:number; bank:number; maxAmount:number; held:boolean; history:BankEntry[]; more:boolean };
export type BankRecipient = { token:string; id:number; name:string };
const record=(v:unknown):v is Record<string,unknown>=>!!v && typeof v==='object' && !Array.isArray(v);
const text=(v:unknown,max:number):v is string=>typeof v==='string' && v.length<=max;
const number=(v:unknown,min=0,max=Number.MAX_SAFE_INTEGER):v is number=>typeof v==='number' && Number.isSafeInteger(v) && v>=min && v<=max;
export function parseBanking(v:unknown):BankingPayload|null {
  if(!record(v)||!text(v.session,100)||!['fleeca','maze','liberty'].includes(String(v.brand))||!text(v.name,100)||
    !number(v.cash)||!number(v.bank)||!number(v.maxAmount,1)||typeof v.held!=='boolean'||typeof v.more!=='boolean'||
    !Array.isArray(v.history)||v.history.length>20||!v.history.every(e=>record(e)&&number(e.id,1)&&
      ['deposit','withdraw','transfer','received','credit','debit','adjustment'].includes(String(e.kind))&&number(e.amount,-2e9,2e9)&&number(e.balance)&&
      text(e.counterparty,100)&&text(e.note,120)&&number(e.time,1))) return null;
  return v as BankingPayload;
}
export function parseBankRecipient(v:unknown):BankRecipient|null {
  return record(v)&&text(v.token,100)&&number(v.id,1,65535)&&text(v.name,100) ? v as BankRecipient : null;
}
export const bankErrors:Record<string,string>={
  insufficient_funds:'Für diesen Betrag reicht dein Guthaben nicht.', balance_limit:'Dieser Betrag überschreitet das Kontolimit.',
  invalid_request:'Bitte prüfe Betrag und Angaben.', invalid_recipient:'Bitte gib die Spieler-ID eines anderen Spielers ein.',
  recipient_offline:'Dieser Spieler ist nicht online.', recipient_changed:'Der Empfänger ist nicht mehr verfügbar. Bitte erneut prüfen.',
  session_expired:'Deine Sitzung ist abgelaufen. Bitte öffne den Automaten erneut.', out_of_range:'Du bist zu weit vom Automaten entfernt.',
  busy:'Eine Buchung wird noch verarbeitet.', rate_limited:'Einen Moment bitte.',
  review_required:'Eine Buchung wird geprüft. Bitte wende dich an die Administration; es wird nichts erneut abgebucht.',
  balance_changed:'Dein Kontostand hat sich geändert. Bitte prüfe den Betrag erneut.', request_reused:'Diese Anfrage wurde bereits anders verwendet.',
  database_error:'Der Bankservice ist gerade nicht erreichbar. Prüfe den Verlauf vor einem neuen Versuch.',
};
export const bankPreview=(brand:BankBrand='fleeca'):BankingPayload=>({
  session:'atm-browser',brand,name:'Test Joost',cash:2450,bank:18640,maxAmount:1000000,held:false,more:false,
  history:[
    {id:4,kind:'deposit',amount:1500,balance:18640,counterparty:'',note:'',time:1789999200},
    {id:3,kind:'transfer',amount:-250,balance:17140,counterparty:'Alex Morgan',note:'Abendessen',time:1789986000},
    {id:2,kind:'credit',amount:450,balance:17390,counterparty:'',note:'Kontobewegung',time:1789911000},
    {id:1,kind:'withdraw',amount:-100,balance:16940,counterparty:'',note:'',time:1789907000},
  ],
});
