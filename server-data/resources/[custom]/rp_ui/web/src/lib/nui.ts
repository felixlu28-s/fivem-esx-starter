declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

export type NuiOpenPayload = {
  view: string;
  payload: Record<string, unknown>;
};

export type Character = {
  id: number;
  firstname: string;
  lastname: string;
  dateofbirth: string;
  gender: 'm' | 'f';
  height: number;
};

export type CharacterResponse = {
  ok: boolean;
  error?: string;
  characters?: Character[];
  character?: Character;
};

export type NuiMessage =
  | { action: 'ui:open'; data: NuiOpenPayload }
  | { action: 'ui:close'; data?: never };

export const isBrowser = (): boolean => typeof window.GetParentResourceName !== 'function';

export const isNuiMessage = (value: unknown): value is NuiMessage => {
  if (!value || typeof value !== 'object') return false;

  const message = value as Record<string, unknown>;
  if (message.action === 'ui:close') return true;
  if (message.action !== 'ui:open' || !message.data || typeof message.data !== 'object') return false;

  const data = message.data as Record<string, unknown>;
  return typeof data.view === 'string' && !!data.payload && typeof data.payload === 'object';
};

export async function fetchNui<TResponse>(
  eventName: string,
  data: Record<string, unknown> = {},
): Promise<TResponse> {
  if (isBrowser()) {
    return { ok: true } as TResponse;
  }

  const resourceName = window.GetParentResourceName?.();
  if (!resourceName) throw new Error('NUI resource name is unavailable');

  const response = await fetch(`https://${resourceName}/${eventName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    throw new Error(`NUI callback ${eventName} failed with ${response.status}`);
  }

  return (await response.json()) as TResponse;
}
