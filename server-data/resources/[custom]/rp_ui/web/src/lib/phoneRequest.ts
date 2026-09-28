import { fetchNui } from "./nui";
import { phonePreview } from "./phonePreview";
let pending:Promise<unknown>=Promise.resolve(),nextAt=0;
export function phoneRequest(session:string,preview:boolean,action:string,data:Record<string,unknown>){
  const result=pending.catch(()=>undefined).then(async()=>{
    const delay=nextAt-performance.now();if(delay>0)await new Promise((r)=>window.setTimeout(r,delay));
    nextAt=performance.now()+230;
    // A browser response must have the same detached values as a JSON NUI response.
    return preview?structuredClone(await phonePreview(action,data)):fetchNui("rp_phone:action",{session,action,data});
  });
  pending=result;return result;
}
