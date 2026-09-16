import { FormEvent, useEffect, useState } from 'react';
import { fetchNui, isBrowser, isNuiMessage, type Character, type CharacterResponse, type NuiOpenPayload } from './lib/nui';

const browserPreview: NuiOpenPayload = {
  view: 'welcome',
  payload: {
    title: 'FiveM ESX Starter',
    message: 'React, TypeScript und die zentrale NUI sind bereit.',
  },
};

const isCharacter = (value: unknown): value is Character => {
  if (!value || typeof value !== 'object') return false;
  const character = value as Record<string, unknown>;
  return typeof character.id === 'number' && typeof character.firstname === 'string'
    && typeof character.lastname === 'string' && typeof character.dateofbirth === 'string'
    && (character.gender === 'm' || character.gender === 'f') && typeof character.height === 'number';
};

export function App() {
  const [screen, setScreen] = useState<NuiOpenPayload | null>(isBrowser() ? browserPreview : null);
  const [characters, setCharacters] = useState<Character[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    const onMessage = (event: MessageEvent<unknown>) => {
      if (!isNuiMessage(event.data)) return;

      if (event.data.action === 'ui:close') {
        setScreen(null);
        return;
      }

      setScreen(event.data.data);
      if (event.data.data.view === 'characters') {
        const incoming = event.data.data.payload.characters;
        setCharacters(Array.isArray(incoming) ? incoming.filter(isCharacter) : []);
      }
    };

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && screen) void close();
    };

    window.addEventListener('message', onMessage);
    window.addEventListener('keydown', onKeyDown);

    return () => {
      window.removeEventListener('message', onMessage);
      window.removeEventListener('keydown', onKeyDown);
    };
  }, [screen]);

  const close = async () => {
    try {
      await fetchNui<{ ok: boolean }>('ui:close');
    } finally {
      setScreen(null);
    }
  };

  const selectCharacter = async (id: number) => {
    const result = await fetchNui<CharacterResponse>('rp_characters:select', { id });
    if (!result.ok) setError(result.error ?? 'Auswahl fehlgeschlagen');
  };

  const createCharacter = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError('');
    const values = new FormData(event.currentTarget);
    const result = await fetchNui<CharacterResponse>('rp_characters:create', {
      firstname: values.get('firstname'), lastname: values.get('lastname'),
      dateofbirth: values.get('dateofbirth'), gender: values.get('gender'), height: Number(values.get('height')),
    });
    if (result.ok && result.characters) {
      setCharacters(result.characters);
      event.currentTarget.reset();
    } else {
      setError(result.error ?? 'Charakter konnte nicht erstellt werden');
    }
  };

  if (!screen) return null;

  if (screen.view === 'characters') {
    return (
      <main className="overlay" aria-label="Charaktere">
        <section className="character-panel">
          <div className="panel-heading"><span className="eyebrow">Identität</span><button className="quiet-button" type="button" onClick={() => void close()}>Schließen</button></div>
          <h1>Wer bist du heute?</h1>
          <div className="character-layout">
            <div className="character-list">
              {characters.map((character) => (
                <button className="character-item" type="button" key={character.id} onClick={() => void selectCharacter(character.id)}>
                  <strong>{character.firstname} {character.lastname}</strong><span>{character.dateofbirth} · {character.height} cm</span>
                </button>
              ))}
              {!characters.length && <p className="empty-state">Noch keine Charaktere angelegt.</p>}
            </div>
            <form className="create-form" onSubmit={(event) => void createCharacter(event)}>
              <h2>Neuer Charakter</h2>
              <input name="firstname" placeholder="Vorname" minLength={2} maxLength={32} required />
              <input name="lastname" placeholder="Nachname" minLength={2} maxLength={32} required />
              <input name="dateofbirth" type="date" min="1900-01-01" max="2020-12-31" required />
              <div className="form-row"><select name="gender" defaultValue="m"><option value="m">Männlich</option><option value="f">Weiblich</option></select><input name="height" type="number" min="120" max="230" placeholder="Größe" required /></div>
              <button type="submit">Charakter anlegen</button>
              {error && <small className="error-message">{error}</small>}
            </form>
          </div>
        </section>
      </main>
    );
  }

  const title = typeof screen.payload.title === 'string' ? screen.payload.title : screen.view;
  const message = typeof screen.payload.message === 'string' ? screen.payload.message : '';

  return (
    <main className="overlay" aria-label={title}>
      <section className="panel">
        <span className="eyebrow">{screen.view}</span>
        <h1>{title}</h1>
        {message && <p>{message}</p>}
        <button type="button" onClick={() => void close()}>
          Schließen
        </button>
      </section>
    </main>
  );
}
